<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\Enrollment;
use App\Models\Quiz;
use App\Models\Assignment;
use App\Models\Lesson;
use App\Models\StudentProgress;
use App\Models\QuizAttempt;
use App\Models\AssignmentSubmission;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class ProgressController extends Controller
{
    // ─────────────────────────────────────────────────────────────
    // DASHBOARD  — dispatches to role-specific dashboard
    // ─────────────────────────────────────────────────────────────
    public function dashboard(Request $request): JsonResponse
    {
        $user = $request->user();

        return match (true) {
            $user->role_id >= 4 => $this->adminDashboard($user),
            $user->role_id === 3 => $this->teacherDashboard($user),
            default              => $this->studentDashboard($user),
        };
    }

    // ─────────────────────────────────────────────────────────────
    // STUDENT DASHBOARD
    // ─────────────────────────────────────────────────────────────
    private function studentDashboard($user): JsonResponse
    {
        // Classes student is enrolled in
        $classIds = Enrollment::where('student_id', $user->id)
            ->pluck('class_id');

        // Stats
        $totalClasses     = $classIds->count();
        $totalLessons     = StudentProgress::where('student_id', $user->id)->sum('lessons_viewed');
        $submittedCount   = AssignmentSubmission::where('student_id', $user->id)->count();
        $avgQuiz          = QuizAttempt::where('student_id', $user->id)->avg('percentage') ?? 0;

        // Upcoming assignments (not yet submitted, not overdue if possible)
        $upcomingAssignments = Assignment::whereIn('class_id', $classIds)
            ->where(function ($q) {
                $q->whereNull('due_date')->orWhere('due_date', '>', now()->subDay());
            })
            ->whereDoesntHave('submissions', fn($q) => $q->where('student_id', $user->id))
            ->with('class:id,name')
            ->orderBy('due_date')
            ->take(8)
            ->get()
            ->map(fn($a) => [
                'id'         => $a->id,
                'title'      => $a->title,
                'class_id'   => $a->class_id,
                'class_name' => $a->class?->name,
                'due_date'   => $a->due_date?->toISOString(),
            ]);

        // Recent lessons with progress
        $recentLessons = Lesson::whereIn('class_id', $classIds)
            ->with(['class:id,name,color'])
            ->orderByDesc('created_at')
            ->take(6)
            ->get()
            ->map(fn($l) => [
                'id'         => $l->id,
                'title'      => $l->title,
                'class_id'   => $l->class_id,
                'class_name' => $l->class?->name,
                'class_color'=> $l->class?->color,
                'progress'   => 0,
            ]);

        // ── PINNED ITEMS ──────────────────────────────────────────
        // Teacher-pinned assignments
        $pinnedAssignments = Assignment::whereIn('class_id', $classIds)
            ->where('is_pinned', 1)
            ->with(['class:id,name', 'pinnedByUser:id,first_name,last_name'])
            ->orderByDesc('pinned_at')
            ->take(10)
            ->get()
            ->map(fn($a) => [
                'type'         => 'assignment',
                'id'           => $a->id,
                'title'        => $a->title,
                'class_id'     => $a->class_id,
                'class_name'   => $a->class?->name,
                'teacher_name' => $a->pinnedByUser ? "{$a->pinnedByUser->first_name} {$a->pinnedByUser->last_name}" : 'Teacher',
                'due_date'     => $a->due_date?->toISOString(),
            ]);

        // Teacher-pinned quizzes
        $pinnedQuizzes = Quiz::whereIn('class_id', $classIds)
            ->where('is_pinned', 1)
            ->with(['class:id,name', 'pinnedByUser:id,first_name,last_name'])
            ->orderByDesc('pinned_at')
            ->take(10)
            ->get()
            ->map(fn($q) => [
                'type'         => 'quiz',
                'id'           => $q->id,
                'title'        => $q->title,
                'class_id'     => $q->class_id,
                'class_name'   => $q->class?->name,
                'teacher_name' => $q->pinnedByUser ? "{$q->pinnedByUser->first_name} {$q->pinnedByUser->last_name}" : 'Teacher',
                'due_date'     => null,
            ]);

        // Teacher-pinned announcements
        $pinnedAnnouncements = \App\Models\Announcement::whereIn('class_id', $classIds)
            ->where('is_pinned', 1)
            ->with(['class:id,name', 'author:id,first_name,last_name'])
            ->orderByDesc('id')
            ->take(10)
            ->get()
            ->map(fn($a) => [
                'type'         => 'announcement',
                'id'           => $a->id,
                'title'        => $a->title,
                'body'         => $a->body,
                'class_id'     => $a->class_id,
                'class_name'   => $a->class?->name,
                'teacher_name' => $a->author ? "{$a->author->first_name} {$a->author->last_name}" : 'Teacher',
                'due_date'     => null,
                'created_at'   => $a->created_at?->toISOString(),
            ]);

        $pinnedItems = $pinnedAssignments
            ->merge($pinnedQuizzes)
            ->merge($pinnedAnnouncements)
            ->sortByDesc('id')
            ->values()
            ->take(6);

        // Activity (last 7 days)
        $activity = $this->last7DaysStudentActivity($user->id);

        return response()->json([
            'stats' => [
                'classes'     => $totalClasses,
                'lessons'     => $totalLessons,
                'assignments' => $submittedCount,
                'avg_quiz'    => round($avgQuiz, 1),
            ],
            'pinned_items'         => $pinnedItems,
            'upcoming_assignments' => $upcomingAssignments,
            'recent_lessons'       => $recentLessons,
            'activity'             => $activity,
        ]);
    }

    // ─────────────────────────────────────────────────────────────
    // TEACHER DASHBOARD
    // ─────────────────────────────────────────────────────────────
    private function teacherDashboard($user): JsonResponse
    {
        // Get classes this teacher owns OR is assigned to
        $classIds = DB::table('classes')
            ->where('teacher_id', $user->id)
            ->pluck('id');

        $totalClasses  = $classIds->count();
        $totalStudents = Enrollment::whereIn('class_id', $classIds)->count();
        $pendingGrades = AssignmentSubmission::whereIn(
            'assignment_id',
            Assignment::whereIn('class_id', $classIds)->pluck('id')
        )->where('status', 'submitted')->count();
        $avgQuiz = QuizAttempt::whereIn(
            'quiz_id',
            Quiz::whereIn('class_id', $classIds)->pluck('id')
        )->avg('percentage') ?? 0;

        // Classes with student + lesson count
        $classes = \App\Models\Classes::whereIn('id', $classIds)
            ->withCount(['enrollments', 'lessons'])
            ->with('grade:id,name')
            ->orderByDesc('created_at')
            ->get()
            ->map(fn($c) => [
                'id'                 => $c->id,
                'name'               => $c->name,
                'color'              => $c->color,
                'join_code'          => $c->join_code,
                'subject'            => $c->subject,
                'grade'              => $c->grade,
                'enrollments_count'  => $c->enrollments_count,
                'lessons_count'      => $c->lessons_count,
            ]);

        // Pending submissions (need grading)
        $pendingSubmissions = AssignmentSubmission::whereIn(
            'assignment_id',
            Assignment::whereIn('class_id', $classIds)->pluck('id')
        )
        ->where('status', 'submitted')
        ->with(['student:id,first_name,last_name,email', 'assignment:id,title,class_id'])
        ->orderBy('submitted_at')
        ->take(10)
        ->get()
        ->map(fn($s) => [
            'id'               => $s->id,
            'student_name'     => $s->student ? "{$s->student->first_name} {$s->student->last_name}" : 'Unknown',
            'assignment_id'    => $s->assignment_id,
            'assignment_title' => $s->assignment?->title,
            'class_id'         => $s->assignment?->class_id,
            'submitted_at'     => $s->submitted_at?->toISOString(),
        ]);

        // Recent assignments (for pin UI)
        $recentAssignments = Assignment::whereIn('class_id', $classIds)
            ->with('class:id,name')
            ->orderByDesc('created_at')
            ->take(10)
            ->get()
            ->map(fn($a) => [
                'id'        => $a->id,
                'title'     => $a->title,
                'class_id'  => $a->class_id,
                'class_name'=> $a->class?->name,
                'due_date'  => $a->due_date?->toISOString(),
                'is_pinned' => (bool) $a->is_pinned,
            ]);

        // Recent quizzes (for pin UI)
        $recentQuizzes = Quiz::whereIn('class_id', $classIds)
            ->with('class:id,name')
            ->orderByDesc('created_at')
            ->take(10)
            ->get()
            ->map(fn($q) => [
                'id'              => $q->id,
                'title'           => $q->title,
                'class_id'        => $q->class_id,
                'class_name'      => $q->class?->name,
                'questions_count' => $q->questions_count,
                'is_pinned'       => (bool) $q->is_pinned,
            ]);

        $activity = $this->last7DaysTeacherActivity($classIds->toArray());

        return response()->json([
            'stats' => [
                'total_classes'  => $totalClasses,
                'total_students' => $totalStudents,
                'pending_grades' => $pendingGrades,
                'avg_quiz'       => round($avgQuiz, 1),
            ],
            'classes'              => $classes,
            'pending_submissions'  => $pendingSubmissions,
            'recent_assignments'   => $recentAssignments,
            'recent_quizzes'       => $recentQuizzes,
            'student_activity'     => $activity,
        ]);
    }

    // ─────────────────────────────────────────────────────────────
    // ADMIN DASHBOARD
    // ─────────────────────────────────────────────────────────────
    private function adminDashboard($user): JsonResponse
    {
        $schoolId = $user->school_id;

        $stats = [
            'total_students'  => DB::table('users')->where('role_id', 2)->where('school_id', $schoolId)->count(),
            'total_teachers'  => DB::table('users')->where('role_id', 3)->where('school_id', $schoolId)->count(),
            'total_classes'   => DB::table('classes')->where('school_id', $schoolId)->count(),
            'total_quizzes'   => DB::table('quizzes')
                ->join('classes', 'quizzes.class_id', '=', 'classes.id')
                ->where('classes.school_id', $schoolId)
                ->count(),
            'avg_quiz'        => round(
                DB::table('quiz_attempts')
                    ->join('quizzes', 'quiz_attempts.quiz_id', '=', 'quizzes.id')
                    ->join('classes', 'quizzes.class_id', '=', 'classes.id')
                    ->where('classes.school_id', $schoolId)
                    ->avg('quiz_attempts.percentage') ?? 0,
                1
            ),
        ];

        // Recent users
        $recentUsers = DB::table('users')
            ->where('school_id', $schoolId)
            ->orderByDesc('created_at')
            ->take(8)
            ->select('id', 'first_name', 'last_name', 'email', 'role_id', 'is_active', 'created_at')
            ->get();

        // All classes for admin management
        $classes = DB::table('classes')
            ->leftJoin('users as t', 'classes.teacher_id', '=', 't.id')
            ->where('classes.school_id', $schoolId)
            ->select(
                'classes.id', 'classes.name', 'classes.join_code', 'classes.color',
                DB::raw("CONCAT(t.first_name, ' ', t.last_name) as teacher_name"),
                't.id as teacher_id'
            )
            ->get();

        return response()->json([
            'stats'        => $stats,
            'recent_users' => $recentUsers,
            'classes'      => $classes,
        ]);
    }

    // ─────────────────────────────────────────────────────────────
    // CLASS PROGRESS  (teacher view)
    // ─────────────────────────────────────────────────────────────
    public function classProgress(Request $request, $classId): JsonResponse
    {
        $students = Enrollment::where('class_id', $classId)
            ->with('student:id,first_name,last_name,email,profile_photo')
            ->get()
            ->map(function ($e) use ($classId) {
                $uid = $e->student_id;
                $quizAvg = QuizAttempt::whereIn('quiz_id', Quiz::where('class_id', $classId)->pluck('id'))
                    ->where('student_id', $uid)->avg('percentage') ?? 0;
                $submitted = AssignmentSubmission::whereIn('assignment_id', Assignment::where('class_id', $classId)->pluck('id'))
                    ->where('student_id', $uid)->count();
                $lessons = StudentProgress::where('class_id', $classId)
                    ->where('student_id', $uid)
                    ->value('lessons_viewed') ?? 0;

                return [
                    'student'          => $e->student,
                    'quiz_average'     => round($quizAvg, 1),
                    'assignments_done' => $submitted,
                    'lessons_viewed'   => $lessons,
                ];
            });

        return response()->json(['students' => $students]);
    }

    // ─────────────────────────────────────────────────────────────
    // MY PROGRESS  (student)
    // ─────────────────────────────────────────────────────────────
    public function myProgress(Request $request): JsonResponse
    {
        $user     = $request->user();
        $classIds = Enrollment::where('student_id', $user->id)->pluck('class_id');

        $quizAttempts = QuizAttempt::where('student_id', $user->id)
            ->with('quiz:id,title,class_id')
            ->orderByDesc('submitted_at')
            ->take(20)
            ->get();

        $submissions = AssignmentSubmission::where('student_id', $user->id)
            ->with('assignment:id,title,class_id,max_score')
            ->orderByDesc('submitted_at')
            ->take(20)
            ->get();

        return response()->json([
            'quiz_attempts'  => $quizAttempts,
            'submissions'    => $submissions,
            'class_count'    => $classIds->count(),
        ]);
    }

    // ─────────────────────────────────────────────────────────────
    // PRIVATE: Activity charts
    // ─────────────────────────────────────────────────────────────
    private function last7DaysStudentActivity(int $userId): array
    {
        $days = [];
        for ($i = 6; $i >= 0; $i--) {
            $date = Carbon::today()->subDays($i);
            $dayLabel = $date->format('D');
            
            $actions = AssignmentSubmission::where('student_id', $userId)
                ->whereDate('submitted_at', $date)
                ->count();
            
            $actions += QuizAttempt::where('student_id', $userId)
                ->whereDate('submitted_at', $date)
                ->count();
                
            $actions += StudentProgress::where('student_id', $userId)
                ->whereDate('last_activity', $date)
                ->count();
                
            $days[] = [
                'day'     => $dayLabel,
                'lessons' => $actions,
            ];
        }
        return $days;
    }

    private function last7DaysTeacherActivity(array $classIds): array
    {
        $assignmentIds = Assignment::whereIn('class_id', $classIds)->pluck('id');
        $days = [];
        for ($i = 6; $i >= 0; $i--) {
            $date = Carbon::today()->subDays($i);
            $days[] = [
                'day'         => $date->format('D'),
                'submissions' => AssignmentSubmission::whereIn('assignment_id', $assignmentIds)
                    ->whereDate('submitted_at', $date)->count(),
                'logins'      => DB::table('users')
                    ->join('enrollments', 'users.id', '=', 'enrollments.student_id')
                    ->whereIn('enrollments.class_id', $classIds)
                    ->whereDate('users.last_seen', $date)->count(),
            ];
        }
        return $days;
    }
}
