<?php
// ─────────────────────────────────────────────────────────────
// ProgressController
// ─────────────────────────────────────────────────────────────
namespace App\Http\Controllers;

use App\Models\Classes;
use App\Models\Assignment;
use App\Models\AssignmentSubmission;
use App\Models\Quiz;
use App\Models\QuizAttempt;
use App\Models\StudentProgress;
use App\Models\Notification;
use App\Models\VideoMeeting;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class ProgressController extends Controller
{
    public function dashboard(Request $request): JsonResponse
    {
        $user = $request->user();
        $role = $user->role->name;

        if ($role === 'student') {
            return $this->studentDashboard($user);
        } elseif ($role === 'teacher') {
            return $this->teacherDashboard($user);
        } else {
            return $this->adminDashboard($user);
        }
    }

    private function studentDashboard($user): JsonResponse
    {
        $classes = Classes::whereHas('enrollments', fn($q) => $q->where('student_id', $user->id))->withCount('enrollments')->get();

        $allClassIds = $classes->pluck('id');

        $totalLessons      = \DB::table('lessons')->whereIn('class_id', $allClassIds)->where('is_published',1)->count();
        $viewedLessons     = StudentProgress::where('student_id', $user->id)->sum('lessons_viewed');
        $totalAssignments  = Assignment::whereIn('class_id', $allClassIds)->where('is_published',1)->count();
        $doneAssignments   = AssignmentSubmission::where('student_id', $user->id)->whereIn('assignment_id',
            Assignment::whereIn('class_id', $allClassIds)->pluck('id'))->count();

        $quizIds   = Quiz::whereIn('class_id', $allClassIds)->pluck('id');
        $avgQuiz   = QuizAttempt::whereIn('quiz_id', $quizIds)->where('student_id', $user->id)->avg('percentage');

        $upcomingAssignments = Assignment::whereIn('class_id', $allClassIds)
            ->where('is_published', 1)->where('due_date', '>', now())
            ->whereNotIn('id', AssignmentSubmission::where('student_id',$user->id)->pluck('assignment_id'))
            ->orderBy('due_date')->take(5)
            ->get()->map(fn($a) => [
                'id'        => $a->id, 'class_id'  => $a->class_id,
                'title'     => $a->title, 'due_date'  => $a->due_date?->toISOString(),
                'class_name'=> $a->class?->name ?? '',
            ]);

        $recentLessons = StudentProgress::where('student_id', $user->id)
            ->whereIn('class_id', $allClassIds)->with('class')->orderBy('last_activity','desc')
            ->take(6)->get()->map(fn($p) => [
                'id'         => $p->class_id,
                'class_id'   => $p->class_id,
                'title'      => $p->class?->name ?? '',
                'class_name' => $p->class?->name ?? '',
                'class_color'=> $p->class?->color ?? '#7C3AED',
                'progress'   => $p->progress_percent,
            ]);

        $activity = collect(range(6,0))->map(fn($d) => [
            'day'     => now()->subDays($d)->format('D'),
            'lessons' => rand(0,4), // In production: query actual view logs
        ]);

        return response()->json([
            'success' => true,
            'stats'   => [
                'classes'     => $classes->count(),
                'lessons'     => $viewedLessons,
                'assignments' => $doneAssignments,
                'avg_quiz'    => round($avgQuiz ?? 0, 1),
            ],
            'upcoming_assignments' => $upcomingAssignments,
            'recent_lessons'       => $recentLessons,
            'activity'             => $activity,
            'notifications'        => Notification::where('user_id',$user->id)->where('is_read',0)->take(5)->get(),
        ]);
    }

    private function teacherDashboard($user): JsonResponse
    {
        $classes       = Classes::where('teacher_id', $user->id)->with('grade')->withCount('enrollments')->get();
        $classIds      = $classes->pluck('id');
        $totalStudents = $classes->sum('enrollments_count');

        $pendingSubmissions = AssignmentSubmission::whereIn('assignment_id',
                Assignment::whereIn('class_id', $classIds)->pluck('id'))
            ->where('status', 'submitted')
            ->with(['student','assignment'])
            ->take(8)->get()
            ->map(fn($s) => [
                'id'              => $s->id,
                'student_name'    => $s->student?->first_name . ' ' . $s->student?->last_name,
                'assignment_title'=> $s->assignment?->title,
                'assignment_id'   => $s->assignment_id,
                'class_id'        => $s->assignment?->class_id,
            ]);

        $avgQuiz = QuizAttempt::whereIn('quiz_id', Quiz::whereIn('class_id', $classIds)->pluck('id'))->avg('percentage');

        $activity = collect(range(6,0))->map(fn($d) => [
            'day'         => now()->subDays($d)->format('D'),
            'submissions' => rand(2,15),
            'logins'      => rand(5,30),
        ]);

        return response()->json([
            'success' => true,
            'stats'   => [
                'total_classes'  => $classes->count(),
                'total_students' => $totalStudents,
                'pending_grades' => $pendingSubmissions->count(),
                'avg_quiz'       => round($avgQuiz ?? 0, 1),
            ],
            'classes'              => $classes->map(fn($c) => [
                'id'               => $c->id, 'name'           => $c->name,
                'subject'          => $c->subject, 'color'          => $c->color,
                'join_code'        => $c->join_code,
                'enrollments_count'=> $c->enrollments_count,
                'grade'            => $c->grade ? ['id'=>$c->grade->id,'name'=>$c->grade->name] : null,
                'lessons_count'    => $c->lessons()->count(),
            ]),
            'pending_submissions'  => $pendingSubmissions,
            'student_activity'     => $activity,
        ]);
    }

    private function adminDashboard($user): JsonResponse
    {
        return response()->json([
            'success' => true,
            'stats'   => [
                'total_users'    => \App\Models\User::where('school_id',$user->school_id)->count(),
                'total_classes'  => Classes::where('school_id',$user->school_id)->count(),
                'messages_today' => \App\Models\Message::whereDate('created_at',today())->count(),
                'ai_requests'    => \App\Models\AiUsage::whereDate('date',today())->sum('request_count'),
                'online_now'     => \App\Models\User::where('is_online',1)->count(),
                'students'       => \App\Models\User::where('school_id',$user->school_id)->where('role_id',2)->count(),
                'teachers'       => \App\Models\User::where('school_id',$user->school_id)->where('role_id',3)->count(),
                'admins'         => \App\Models\User::where('school_id',$user->school_id)->where('role_id',4)->count(),
                'school_name'    => $user->school?->name,
                'daily_activity' => collect(range(6,0))->map(fn($d) => ['date'=>now()->subDays($d)->format('D'),'users'=>rand(20,80),'messages'=>rand(50,200)]),
            ],
        ]);
    }

    public function myProgress(Request $request): JsonResponse
    {
        $user    = $request->user();
        $classes = Classes::whereHas('enrollments', fn($q) => $q->where('student_id',$user->id))->pluck('id');
        $quizIds = Quiz::whereIn('class_id', $classes)->pluck('id');

        return response()->json([
            'success'  => true,
            'overall'  => [
                'total_classes'    => $classes->count(),
                'lessons_viewed'   => StudentProgress::where('student_id',$user->id)->sum('lessons_viewed'),
                'assignments_done' => AssignmentSubmission::where('student_id',$user->id)->count(),
                'avg_quiz'         => round(QuizAttempt::whereIn('quiz_id',$quizIds)->where('student_id',$user->id)->avg('percentage') ?? 0, 1),
            ],
            'by_class' => StudentProgress::where('student_id',$user->id)->with('class')->get()->map(fn($p) => [
                'class_id'             => $p->class_id,
                'class_name'           => $p->class?->name,
                'lessons_viewed'       => $p->lessons_viewed,
                'lessons_total'        => $p->lessons_total,
                'assignments_submitted'=> $p->assignments_submitted,
                'assignments_total'    => $p->assignments_total,
                'avg_quiz_score'       => $p->avg_quiz_score,
                'progress_percent'     => $p->progress_percent,
                'last_activity'        => $p->last_activity?->toISOString(),
            ]),
        ]);
    }

    public function classProgress(Request $request, int $classId): JsonResponse
    {
        $progress = StudentProgress::where('class_id', $classId)->with('student')->get()
            ->map(fn($p) => [
                'student_id'    => $p->student_id,
                'student_name'  => $p->student?->first_name . ' ' . $p->student?->last_name,
                'progress'      => $p->progress_percent,
                'lessons_done'  => $p->lessons_viewed,
                'assignments_done' => $p->assignments_submitted,
                'avg_quiz'      => $p->avg_quiz_score,
                'last_activity' => $p->last_activity?->toISOString(),
            ]);
        return response()->json(['success' => true, 'progress' => $progress]);
    }

    public function studentProgress(Request $request, int $classId, int $studentId): JsonResponse
    {
        $p = StudentProgress::where('class_id',$classId)->where('student_id',$studentId)->with('student')->firstOrFail();
        return response()->json(['success' => true, 'progress' => $p]);
    }
}
