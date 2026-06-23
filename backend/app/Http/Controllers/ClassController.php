<?php

namespace App\Http\Controllers;

use App\Models\Classes;
use App\Models\Enrollment;
use App\Models\GroupChat;
use App\Models\GroupChatMember;
use App\Models\Notification;
use App\Models\StudentProgress;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ClassController extends Controller
{
    // ─── List classes for current user ───────────────────────────
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        if (in_array($user->role->name, ['teacher', 'school_admin'])) {
            $classes = Classes::where('teacher_id', $user->id)
                ->orWhere('school_id', $user->school_id)
                ->with(['teacher', 'grade', 'enrollments'])
                ->withCount('enrollments')
                ->orderBy('created_at', 'desc')
                ->get();
        } else {
            $classes = Classes::whereHas('enrollments', fn($q) => $q->where('student_id', $user->id))
                ->with(['teacher', 'grade'])
                ->withCount('enrollments')
                ->get();
        }

        return response()->json(['success' => true, 'classes' => $classes->map(fn($c) => $this->formatClass($c, $user->id))]);
    }

    // ─── Create a new class ───────────────────────────────────────
    public function store(Request $request): JsonResponse
    {
        $user = $request->user();
        $this->authorize('teacher', $user);

        $validated = $request->validate([
            'name'        => 'required|string|max:200',
            'subject'     => 'nullable|string|max:100',
            'description' => 'nullable|string|max:1000',
            'grade_id'    => 'nullable|exists:grades,id',
            'color'       => 'nullable|string|max:20',
            'cover_photo' => 'nullable|image|max:10240',
            'max_students'=> 'nullable|integer|min:1|max:500',
            'allow_student_chat' => 'boolean',
        ]);

        $joinCode = $this->generateJoinCode();

        $class = Classes::create([
            ...$validated,
            'school_id'   => $user->school_id,
            'teacher_id'  => $user->id,
            'join_code'   => $joinCode,
            'invite_link' => Str::random(32),
            'color'       => $validated['color'] ?? '#7C3AED',
        ]);

        if ($request->hasFile('cover_photo')) {
            $path = $request->file('cover_photo')->store("class-covers/{$class->id}", 'public');
            $class->update(['cover_photo' => $path]);
        }

        // Auto-create a group chat for this class
        $group = GroupChat::create([
            'name'       => $class->name,
            'type'       => 'class',
            'class_id'   => $class->id,
            'created_by' => $user->id,
            'join_code'  => $joinCode,
        ]);

        // Add teacher as group admin
        GroupChatMember::create([
            'group_id' => $group->id,
            'user_id'  => $user->id,
            'role'     => 'admin',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Class created successfully!',
            'class'   => $this->formatClass($class->load(['teacher', 'grade']), $user->id),
        ], 201);
    }

    // ─── Get single class ─────────────────────────────────────────
    public function show(Request $request, int $id): JsonResponse
    {
        $user  = $request->user();
        $class = Classes::with(['teacher', 'grade', 'school'])->findOrFail($id);

        $this->checkAccess($class, $user);

        $data = $this->formatClass($class, $user->id);

        // Add extra details
        $data['enrollments_count'] = $class->enrollments()->count();
        $data['lessons_count']     = $class->lessons()->where('is_published', 1)->count();
        $data['assignments_count'] = $class->assignments()->where('is_published', 1)->count();
        $data['quizzes_count']     = $class->quizzes()->where('is_published', 1)->count();

        return response()->json(['success' => true, 'class' => $data]);
    }

    // ─── Update class ─────────────────────────────────────────────
    public function update(Request $request, int $id): JsonResponse
    {
        $user  = $request->user();
        $class = Classes::findOrFail($id);

        if ($class->teacher_id !== $user->id && $user->role->name !== 'school_admin') {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

        $validated = $request->validate([
            'name'        => 'sometimes|string|max:200',
            'subject'     => 'nullable|string|max:100',
            'description' => 'nullable|string|max:1000',
            'color'       => 'nullable|string|max:20',
            'is_active'   => 'boolean',
            'allow_student_chat' => 'boolean',
        ]);

        if ($request->hasFile('cover_photo')) {
            if ($class->cover_photo) Storage::disk('public')->delete($class->cover_photo);
            $validated['cover_photo'] = $request->file('cover_photo')->store("class-covers/{$class->id}", 'public');
        }

        $class->update($validated);

        // Sync group chat name
        if (isset($validated['name'])) {
            GroupChat::where('class_id', $class->id)->update(['name' => $validated['name']]);
        }

        return response()->json(['success' => true, 'class' => $this->formatClass($class->fresh(['teacher', 'grade']), $user->id)]);
    }

    // ─── Join class by code ───────────────────────────────────────
    public function join(Request $request): JsonResponse
    {
        $user = $request->user();

        $request->validate(['join_code' => 'required|string|max:12']);

        $class = Classes::where('join_code', strtoupper($request->join_code))
            ->orWhere('invite_link', $request->join_code)
            ->with('teacher')
            ->first();

        if (!$class) {
            return response()->json(['success' => false, 'message' => 'Invalid class code. Please check and try again.'], 404);
        }

        if (!$class->is_active) {
            return response()->json(['success' => false, 'message' => 'This class is no longer active.'], 403);
        }

        $alreadyEnrolled = Enrollment::where('class_id', $class->id)->where('student_id', $user->id)->exists();
        if ($alreadyEnrolled) {
            return response()->json(['success' => false, 'message' => 'You are already enrolled in this class.'], 409);
        }

        $count = Enrollment::where('class_id', $class->id)->count();
        if ($count >= $class->max_students) {
            return response()->json(['success' => false, 'message' => 'This class is full.'], 409);
        }

        // Enroll student
        Enrollment::create(['class_id' => $class->id, 'student_id' => $user->id]);

        // Add to class group chat
        $group = GroupChat::where('class_id', $class->id)->first();
        if ($group) {
            GroupChatMember::firstOrCreate(['group_id' => $group->id, 'user_id' => $user->id]);
        }

        // Initialize progress record
        StudentProgress::firstOrCreate(
            ['student_id' => $user->id, 'class_id' => $class->id],
            ['lessons_total' => $class->lessons()->count(), 'assignments_total' => $class->assignments()->count()]
        );

        // Notify teacher
        Notification::create([
            'user_id'      => $class->teacher_id,
            'type'         => 'student_joined',
            'title'        => "{$user->first_name} {$user->last_name} joined your class",
            'body'         => "{$user->first_name} joined {$class->name}",
            'related_type' => 'class',
            'related_id'   => $class->id,
            'action_url'   => "/classes/{$class->id}/students",
        ]);

        return response()->json([
            'success' => true,
            'message' => "You joined {$class->name}!",
            'class'   => $this->formatClass($class, $user->id),
        ]);
    }

    // ─── Leave class ──────────────────────────────────────────────
    public function leave(Request $request, int $id): JsonResponse
    {
        $user = $request->user();
        $enrollment = Enrollment::where('class_id', $id)->where('student_id', $user->id)->firstOrFail();
        $enrollment->delete();

        // Remove from group chat
        $group = GroupChat::where('class_id', $id)->first();
        if ($group) GroupChatMember::where('group_id', $group->id)->where('user_id', $user->id)->delete();

        return response()->json(['success' => true, 'message' => 'You have left the class.']);
    }

    // ─── Get class students ───────────────────────────────────────
    public function students(Request $request, int $id): JsonResponse
    {
        $class = Classes::findOrFail($id);
        $this->checkAccess($class, $request->user());

        $students = $class->enrollments()
            ->with(['student', 'student.settings'])
            ->get()
            ->map(fn($e) => [
                'id'             => $e->student->id,
                'full_name'      => $e->student->first_name . ' ' . $e->student->last_name,
                'email'          => $e->student->email,
                'profile_photo'  => $e->student->profile_photo
                    ? Storage::disk('public')->url($e->student->profile_photo)
                    : null,
                'is_online'      => (bool) $e->student->is_online,
                'is_class_leader'=> (bool) $e->is_class_leader,
                'joined_at'      => $e->joined_at,
                'progress'       => StudentProgress::where('student_id', $e->student->id)
                    ->where('class_id', $id)->first()?->progress_percent ?? 0,
            ]);

        return response()->json(['success' => true, 'students' => $students]);
    }

    // ─── Remove student from class ────────────────────────────────
    public function removeStudent(Request $request, int $classId, int $studentId): JsonResponse
    {
        $user  = $request->user();
        $class = Classes::findOrFail($classId);

        if ($class->teacher_id !== $user->id && $user->role->name !== 'school_admin') {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

        Enrollment::where('class_id', $classId)->where('student_id', $studentId)->delete();

        $group = GroupChat::where('class_id', $classId)->first();
        if ($group) GroupChatMember::where('group_id', $group->id)->where('user_id', $studentId)->delete();

        return response()->json(['success' => true, 'message' => 'Student removed from class.']);
    }

    // ─── Promote to class leader ──────────────────────────────────
    public function promoteLeader(Request $request, int $classId, int $studentId): JsonResponse
    {
        $class = Classes::findOrFail($classId);
        if ($class->teacher_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

        // Demote current leader
        Enrollment::where('class_id', $classId)->update(['is_class_leader' => 0]);
        // Promote new leader
        Enrollment::where('class_id', $classId)->where('student_id', $studentId)
            ->update(['is_class_leader' => 1]);

        return response()->json(['success' => true, 'message' => 'Class leader promoted.']);
    }

    // ─── Regenerate join code ─────────────────────────────────────
    public function regenerateCode(Request $request, int $id): JsonResponse
    {
        $class = Classes::findOrFail($id);
        if ($class->teacher_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

        $code = $this->generateJoinCode();
        $class->update(['join_code' => $code, 'invite_link' => Str::random(32)]);

        return response()->json(['success' => true, 'join_code' => $code, 'invite_link' => $class->invite_link]);
    }

    // ─── Helpers ──────────────────────────────────────────────────
    private function formatClass(Classes $class, int $userId): array
    {
        return [
            'id'           => $class->id,
            'name'         => $class->name,
            'subject'      => $class->subject,
            'description'  => $class->description,
            'color'        => $class->color,
            'cover_photo'  => $class->cover_photo ? Storage::disk('public')->url($class->cover_photo) : null,
            'join_code'    => $class->join_code,
            'invite_link'  => $class->invite_link,
            'is_active'    => (bool) $class->is_active,
            'max_students' => $class->max_students,
            'allow_student_chat' => (bool) $class->allow_student_chat,
            'teacher'      => $class->teacher ? [
                'id'           => $class->teacher->id,
                'full_name'    => $class->teacher->first_name . ' ' . $class->teacher->last_name,
                'profile_photo'=> $class->teacher->profile_photo,
            ] : null,
            'grade'        => $class->grade ? ['id' => $class->grade->id, 'name' => $class->grade->name] : null,
            'created_at'   => $class->created_at->toISOString(),
        ];
    }

    private function checkAccess(Classes $class, $user): void
    {
        if ($user->role->name === 'school_admin') return;
        if ($class->teacher_id === $user->id) return;
        if (Enrollment::where('class_id', $class->id)->where('student_id', $user->id)->exists()) return;
        abort(403, 'You do not have access to this class.');
    }

    private function generateJoinCode(): string
    {
        do {
            $code = strtoupper(Str::random(8));
        } while (Classes::where('join_code', $code)->exists());
        return $code;
    }

    private function authorize(string $role, $user): void
    {
        if (!in_array($user->role->name, ['teacher', 'school_admin'])) {
            abort(403, 'Only teachers can perform this action.');
        }
    }
}
