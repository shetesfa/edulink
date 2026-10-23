<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\Assignment;
use App\Models\AssignmentSubmission;
use App\Models\User;
use App\Models\SchoolClass;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class DashboardController extends Controller
{
    /**
     * GET /api/dashboard
     * Returns a different shape depending on the user's role - a student
     * dashboard, a teacher dashboard, or an admin overview.
     */
    public function index(Request $request)
    {
        $user = $request->user();

        return response()->json([
            'success' => true,
            'data' => match ($user->role->name) {
                'teacher' => $this->teacherDashboard($user),
                'school_admin', 'super_admin' => $this->adminDashboard($user),
                default => $this->studentDashboard($user),
            },
        ]);
    }

    private function studentDashboard(User $user): array
    {
        $enrolledClasses = $user->enrolledClasses()
            ->with('teacher')
            ->withCount('lessons')
            ->get();
        $classIds = $enrolledClasses->pluck('classes.id');

        $upcomingAssignments = Assignment::whereIn('class_id', $classIds)
            ->where('is_published', true)
            ->where('due_date', '>=', now())
            ->whereDoesntHave('submissions', fn ($q) => $q->where('student_id', $user->id))
            ->with('schoolClass')
            ->orderBy('due_date')
            ->limit(10)
            ->get()
            ->map(function ($a) {
                return [
                    'id' => $a->id,
                    'title' => $a->title,
                    'due_date' => $a->due_date,
                    'class_name' => $a->schoolClass->name ?? 'Class',
                ];
            });

        $recentLessons = \App\Models\Lesson::whereIn('class_id', $classIds)
            ->where('is_published', true)
            ->with('schoolClass')
            ->latest()
            ->limit(5)
            ->get()
            ->map(function ($l) {
                return [
                    'id' => $l->id,
                    'title' => $l->title,
                    'class_name' => $l->schoolClass->name ?? 'Class',
                    'progress' => 0,
                ];
            });

        $recentGrades = AssignmentSubmission::where('student_id', $user->id)
            ->where('status', 'graded')
            ->with('assignment')
            ->latest('graded_at')
            ->limit(5)
            ->get();

        $notifications = AppNotification::where('user_id', $user->id)
            ->latest()
            ->limit(5)
            ->get();

        return [
            'role' => 'student',
            'stats' => [
                'classes' => $enrolledClasses->count(),
                'lessons' => \App\Models\Lesson::whereIn('class_id', $classIds)->count(),
                'assignments' => AssignmentSubmission::where('student_id', $user->id)->count(),
                'avg_quiz' => (int) round($user->quizAttempts()->avg('score_percent') ?? 0),
            ],
            'enrolled_classes_count' => $enrolledClasses->count(),
            'classes' => $enrolledClasses,
            'unread_notifications' => AppNotification::where('user_id', $user->id)->where('is_read', false)->count(),
            'upcoming_assignments' => $upcomingAssignments,
            'recent_lessons' => $recentLessons,
            'recent_grades' => $recentGrades,
            'notifications' => $notifications,
        ];
    }

    private function teacherDashboard(User $user): array
    {
        $classes = $user->classesTaught()->withCount(['students', 'lessons'])->get();
        $classIds = $classes->pluck('id');

        $ungradedCount = AssignmentSubmission::whereIn(
            'assignment_id',
            Assignment::whereIn('class_id', $classIds)->pluck('id')
        )->where('status', 'submitted')->count();

        $recentSubmissions = AssignmentSubmission::whereIn(
            'assignment_id',
            Assignment::whereIn('class_id', $classIds)->pluck('id')
        )->with('student', 'assignment')->latest('submitted_at')->limit(10)->get();

        return [
            'role' => 'teacher',
            'stats' => [
                'total_classes' => $classes->count(),
                'total_students' => $classes->sum('students_count'),
                'pending_grades' => $ungradedCount,
                'avg_quiz' => 0,
            ],
            'classes' => $classes,
            'total_students' => $classes->sum('students_count'),
            'pending_submissions' => $recentSubmissions,
            'unread_notifications' => AppNotification::where('user_id', $user->id)->where('is_read', false)->count(),
        ];
    }

    private function adminDashboard(User $user): array
    {
        $baseQuery = fn () => $user->hasRole('school_admin')
            ? User::where('school_id', $user->school_id)
            : User::query();

        $usersByRole = $baseQuery()
            ->join('roles', 'roles.id', '=', 'users.role_id')
            ->selectRaw('roles.name as role, count(*) as total')
            ->groupBy('roles.name')
            ->pluck('total', 'role');

        $classesQuery = fn () => $user->hasRole('school_admin')
            ? SchoolClass::where('school_id', $user->school_id)
            : SchoolClass::query();

        return [
            'role' => 'admin',
            'total_users' => $baseQuery()->count(),
            'users_by_role' => $usersByRole,
            'total_classes' => $classesQuery()->count(),
            'active_classes' => $classesQuery()->where('is_active', true)->count(),
            'new_users_last_7_days' => $baseQuery()->where('created_at', '>=', Carbon::now()->subDays(7))->count(),
        ];
    }
}
