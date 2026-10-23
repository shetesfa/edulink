<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\SchoolClass;
use App\Models\Role;
use App\Models\AuditLog;
use App\Services\AuditLogService;
use App\Services\NotificationDispatchService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AdminController extends Controller
{
    public function __construct(
        private AuditLogService $auditLog,
        private NotificationDispatchService $notifier,
    ) {}

    /**
     * GET /api/admin/users?search=&role=&status=
     * School admins only ever see their own school's users.
     */
    public function users(Request $request)
    {
        $actor = $request->user();

        $query = User::with('role', 'school')
            ->when($actor->hasRole('school_admin'), fn ($q) => $q->where('school_id', $actor->school_id))
            ->when($request->filled('search'), function ($q) use ($request) {
                $term = $request->search;
                $q->where(fn ($sub) => $sub->where('first_name', 'like', "%{$term}%")
                    ->orWhere('last_name', 'like', "%{$term}%")
                    ->orWhere('email', 'like', "%{$term}%"));
            })
            ->when($request->filled('role'), fn ($q) => $q->whereHas('role', fn ($r) => $r->where('name', $request->role)))
            ->when($request->filled('status'), fn ($q) => $q->where('is_active', $request->status === 'active'));

        return response()->json(['success' => true, 'data' => ['users' => $query->latest()->paginate(25)]]);
    }

    /**
     * POST /api/admin/users/{user}/toggle-active
     */
    public function toggleActive(Request $request, User $user)
    {
        $this->assertSameSchoolOrSuperAdmin($request, $user);

        if ($user->id === $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'You cannot deactivate your own account.'], 422);
        }

        $user->update(['is_active' => !$user->is_active]);

        // Deactivated accounts lose access immediately, not just at next login
        if (!$user->is_active) {
            $user->tokens()->delete();
        }

        $this->auditLog->log(
            $request->user(),
            $user->is_active ? 'user.activated' : 'user.deactivated',
            'user',
            $user->id,
            [],
            $request
        );

        return response()->json([
            'success' => true,
            'message' => $user->is_active ? 'Account activated.' : 'Account deactivated.',
            'data' => ['user' => $user->fresh()],
        ]);
    }

    /**
     * PUT /api/admin/users/{user}/role  (super_admin only)
     */
    public function changeRole(Request $request, User $user)
    {
        if (!$request->user()->hasRole('super_admin')) {
            return response()->json(['success' => false, 'message' => 'Only a super admin can change roles.'], 403);
        }

        $request->validate(['role' => ['required', 'in:student,teacher,school_admin,super_admin']]);

        $role = Role::where('name', $request->role)->firstOrFail();
        $oldRole = $user->role->name;
        $user->update(['role_id' => $role->id]);

        $this->auditLog->log(
            $request->user(),
            'user.role_changed',
            'user',
            $user->id,
            ['from' => $oldRole, 'to' => $request->role],
            $request
        );

        return response()->json(['success' => true, 'message' => 'Role updated.', 'data' => ['user' => $user->fresh('role')]]);
    }

    /**
     * DELETE /api/admin/users/{user}
     */
    public function deleteUser(Request $request, User $user)
    {
        $this->assertSameSchoolOrSuperAdmin($request, $user);

        if ($user->id === $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'You cannot delete your own account.'], 422);
        }

        $this->auditLog->log($request->user(), 'user.deleted', 'user', $user->id, [
            'email' => $user->email,
            'name' => $user->fullName(),
        ], $request);

        $user->delete();

        return response()->json(['success' => true, 'message' => 'User deleted.']);
    }

    /**
     * GET /api/admin/classes
     */
    public function classes(Request $request)
    {
        $actor = $request->user();

        $classes = SchoolClass::with('teacher', 'school')
            ->withCount('students')
            ->when($actor->hasRole('school_admin'), fn ($q) => $q->where('school_id', $actor->school_id))
            ->latest()
            ->paginate(25);

        return response()->json(['success' => true, 'data' => ['classes' => $classes]]);
    }

    /**
     * POST /api/admin/classes/{class}/toggle-active  (moderation)
     */
    public function toggleClassActive(Request $request, SchoolClass $class)
    {
        $class->update(['is_active' => !$class->is_active]);

        $this->auditLog->log(
            $request->user(),
            $class->is_active ? 'class.activated' : 'class.deactivated',
            'class',
            $class->id,
            ['name' => $class->name],
            $request
        );

        return response()->json([
            'success' => true,
            'message' => $class->is_active ? 'Class re-activated.' : 'Class deactivated.',
            'data' => ['class' => $class->fresh()],
        ]);
    }

    /**
     * GET /api/admin/audit-logs
     */
    public function auditLogs(Request $request)
    {
        $logs = AuditLog::with('user')->latest()->paginate(50);

        return response()->json(['success' => true, 'data' => ['logs' => $logs]]);
    }

    /**
     * A school_admin may only act on users within their own school.
     * A super_admin may act on anyone.
     */
    private function assertSameSchoolOrSuperAdmin(Request $request, User $target): void
    {
        $actor = $request->user();

        if ($actor->hasRole('super_admin')) {
            return;
        }

        abort_if($target->school_id !== $actor->school_id, 403, 'This user belongs to a different school.');
    }
}
