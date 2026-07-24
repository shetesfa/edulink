<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Classes;
use App\Models\AiUsage;
use App\Services\AIRouterService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class AdminController extends Controller
{
    public function __construct(private AIRouterService $ai) {}

    // ─── School stats ─────────────────────────────────────────
    public function stats(Request $request): JsonResponse
    {
        $user     = $request->user();
        $schoolId = $user->school_id;

        return response()->json([
            'success' => true,
            'stats'   => [
                'total_users'    => User::where('school_id', $schoolId)->count(),
                'students'       => User::where('school_id', $schoolId)->where('role_id', 2)->count(),
                'teachers'       => User::where('school_id', $schoolId)->where('role_id', 3)->count(),
                'admins'         => User::where('school_id', $schoolId)->where('role_id', 4)->count(),
                'total_classes'  => Classes::where('school_id', $schoolId)->count(),
                'active_classes' => Classes::where('school_id', $schoolId)->where('is_active', 1)->count(),
                'messages_today' => \App\Models\Message::whereDate('created_at', today())->count(),
                'ai_requests'    => AiUsage::whereDate('date', today())->sum('request_count'),
                'online_now'     => User::where('school_id', $schoolId)->where('is_online', 1)->count(),
                'school_name'    => $user->school?->name,
                'daily_activity' => $this->getDailyActivity($schoolId),
            ],
        ]);
    }

    // ─── List users ───────────────────────────────────────────
    public function users(Request $request): JsonResponse
    {
        $schoolId = $request->user()->school_id;
        $query    = User::where('school_id', $schoolId)->with('role');

        if ($request->role) {
            $roleMap = ['student'=>2,'teacher'=>3,'school_admin'=>4];
            $query->where('role_id', $roleMap[$request->role] ?? 2);
        }
        if ($request->search) {
            $s = '%'.$request->search.'%';
            $query->where(fn($q) => $q->where('first_name','LIKE',$s)->orWhere('last_name','LIKE',$s)->orWhere('email','LIKE',$s));
        }

        $users = $query->orderBy('created_at','desc')
            ->paginate($request->limit ?? 20)
            ->through(fn($u) => [
                'id'         => $u->id,
                'first_name' => $u->first_name,
                'last_name'  => $u->last_name,
                'email'      => $u->email,
                'username'   => $u->username,
                'role'       => $u->role?->name,
                'is_active'  => (bool)$u->is_active,
                'is_online'  => (bool)$u->is_online,
                'created_at' => $u->created_at->toISOString(),
            ]);

        return response()->json(['success' => true, 'users' => $users->items(), 'total' => $users->total()]);
    }

    // ─── Toggle user active/banned ────────────────────────────
    public function toggleUser(Request $request, int $id): JsonResponse
    {
        $admin = $request->user();
        $user  = User::where('school_id', $admin->school_id)->findOrFail($id);

        // Cannot ban yourself or other admins
        if ($user->id === $admin->id || $user->role_id === 4) {
            return response()->json(['success' => false, 'message' => 'Cannot change status of this user'], 403);
        }

        $user->update(['is_active' => !$user->is_active]);

        // If banned, revoke all tokens
        if (!$user->is_active) {
            $user->tokens()->delete();
        }

        return response()->json([
            'success'   => true,
            'is_active' => (bool)$user->is_active,
            'message'   => $user->is_active ? 'User activated.' : 'User banned.',
        ]);
    }

    // ─── Delete user ──────────────────────────────────────────
    public function deleteUser(Request $request, int $id): JsonResponse
    {
        $admin = $request->user();
        $user  = User::where('school_id', $admin->school_id)->findOrFail($id);

        if ($user->id === $admin->id) {
            return response()->json(['success' => false, 'message' => 'Cannot delete yourself'], 403);
        }

        $user->tokens()->delete();
        $user->delete();

        return response()->json(['success' => true, 'message' => 'User deleted.']);
    }

    // ─── List classes ─────────────────────────────────────────
    public function classes(Request $request): JsonResponse
    {
        $classes = Classes::where('school_id', $request->user()->school_id)
            ->with(['teacher','grade'])
            ->withCount('enrollments')
            ->orderBy('created_at','desc')
            ->get()
            ->map(fn($c) => [
                'id'               => $c->id,
                'name'             => $c->name,
                'subject'          => $c->subject,
                'color'            => $c->color,
                'is_active'        => (bool)$c->is_active,
                'enrollments_count'=> $c->enrollments_count,
                'join_code'        => $c->join_code,
                'teacher'          => $c->teacher ? ['full_name' => $c->teacher->first_name.' '.$c->teacher->last_name] : null,
                'grade'            => $c->grade ? ['name' => $c->grade->name] : null,
                'created_at'       => $c->created_at->toISOString(),
            ]);

        return response()->json(['success' => true, 'classes' => $classes]);
    }

    // ─── Reports ──────────────────────────────────────────────
    public function reports(Request $request): JsonResponse
    {
        $schoolId = $request->user()->school_id;
        $classIds = Classes::where('school_id', $schoolId)->pluck('id');

        return response()->json([
            'success' => true,
            'reports' => [
                'total_lessons'        => \App\Models\Lesson::whereIn('class_id',$classIds)->count(),
                'total_assignments'    => \App\Models\Assignment::whereIn('class_id',$classIds)->count(),
                'total_submissions'    => \App\Models\AssignmentSubmission::whereIn('assignment_id',
                    \App\Models\Assignment::whereIn('class_id',$classIds)->pluck('id'))->count(),
                'total_quizzes'        => \App\Models\Quiz::whereIn('class_id',$classIds)->count(),
                'total_quiz_attempts'  => \App\Models\QuizAttempt::whereIn('quiz_id',
                    \App\Models\Quiz::whereIn('class_id',$classIds)->pluck('id'))->count(),
                'avg_quiz_score'       => round(\App\Models\QuizAttempt::whereIn('quiz_id',
                    \App\Models\Quiz::whereIn('class_id',$classIds)->pluck('id'))->avg('percentage') ?? 0, 1),
                'total_meetings'       => \App\Models\VideoMeeting::whereIn('class_id',$classIds)->count(),
                'total_messages'       => \App\Models\Message::count(),
                'new_users_this_month' => User::where('school_id',$schoolId)->whereMonth('created_at',now()->month)->count(),
            ],
        ]);
    }

    // ─── AI usage ─────────────────────────────────────────────
    public function aiUsage(Request $request): JsonResponse
    {
        return response()->json([
            'success'   => true,
            'providers' => $this->ai->getProviderStatus(),
            'history'   => AiUsage::where('date', '>=', now()->subDays(7)->toDateString())
                ->orderBy('date','desc')
                ->get()
                ->groupBy('provider')
                ->map(fn($rows, $provider) => [
                    'provider' => $provider,
                    'total_week' => $rows->sum('request_count'),
                    'daily' => $rows->map(fn($r) => ['date'=>$r->date,'count'=>$r->request_count]),
                ]),
        ]);
    }

    // ─── Helper: daily activity ───────────────────────────────
    private function getDailyActivity(int $schoolId): array
    {
        return collect(range(6,0))->map(fn($d) => [
            'date'     => now()->subDays($d)->format('D'),
            'users'    => User::where('school_id',$schoolId)->whereDate('last_seen', now()->subDays($d))->count(),
            'messages' => \App\Models\Message::whereDate('created_at', now()->subDays($d))->count(),
        ])->toArray();
    }
}
