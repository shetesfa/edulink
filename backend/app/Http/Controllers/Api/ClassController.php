<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Classes\CreateClassRequest;
use App\Http\Requests\Classes\JoinClassRequest;
use App\Http\Requests\Classes\UpdateClassRequest;
use App\Models\SchoolClass;
use App\Models\Enrollment;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class ClassController extends Controller
{
    /**
     * GET /api/classes
     * Lists classes the user teaches (teacher) or is enrolled in (student).
     */
    public function index(Request $request)
    {
        $user = $request->user();

        if (in_array($user->role->name, ['teacher', 'school_admin', 'super_admin'])) {
            $taught = $user->classesTaught()->withCount('students')->get();
        } else {
            $taught = collect();
        }

        $enrolled = $user->enrolledClasses()->withCount('students')->get();

        return response()->json([
            'success' => true,
            'data' => [
                'teaching' => $taught,
                'enrolled' => $enrolled,
            ],
        ]);
    }

    /**
     * POST /api/classes  (Teacher / admin only - see CreateClassRequest::authorize)
     */
    public function store(CreateClassRequest $request)
    {
        $data = $request->validated();
        $data['teacher_id'] = $request->user()->id;
        $data['school_id'] = $request->user()->school_id;
        $data['join_code'] = SchoolClass::generateUniqueJoinCode();

        $class = SchoolClass::create($data);

        return response()->json([
            'success' => true,
            'message' => 'Class created successfully.',
            'data' => ['class' => $class],
        ], 201);
    }

    /**
     * GET /api/classes/{classId}
     */
    public function show(Request $request, SchoolClass $class)
    {
        Gate::forUser($request->user())->authorize('view', $class);

        return response()->json([
            'success' => true,
            'data' => ['class' => $class->load('teacher', 'grade')->loadCount('students')],
        ]);
    }

    /**
     * PUT /api/classes/{classId}
     */
    public function update(UpdateClassRequest $request, SchoolClass $class)
    {
        Gate::forUser($request->user())->authorize('manage', $class);

        $class->update($request->validated());

        return response()->json([
            'success' => true,
            'message' => 'Class updated.',
            'data' => ['class' => $class->fresh()],
        ]);
    }

    /**
     * DELETE /api/classes/{classId}
     */
    public function destroy(Request $request, SchoolClass $class)
    {
        Gate::forUser($request->user())->authorize('manage', $class);

        $class->delete();

        return response()->json([
            'success' => true,
            'message' => 'Class deleted.',
        ]);
    }

    /**
     * POST /api/classes/join
     */
    public function join(JoinClassRequest $request)
    {
        $class = SchoolClass::where('join_code', $request->join_code)->firstOrFail();

        if (!$class->is_active) {
            return response()->json(['success' => false, 'message' => 'This class is no longer active.'], 422);
        }

        $already = Enrollment::where('class_id', $class->id)
            ->where('student_id', $request->user()->id)
            ->first();

        if ($already) {
            if ($already->is_banned) {
                return response()->json(['success' => false, 'message' => 'You have been removed from this class.'], 403);
            }
            return response()->json(['success' => false, 'message' => 'You already joined this class.'], 422);
        }

        if ($class->students()->count() >= $class->max_students) {
            return response()->json(['success' => false, 'message' => 'This class is full.'], 422);
        }

        Enrollment::create([
            'class_id' => $class->id,
            'student_id' => $request->user()->id,
        ]);

        return response()->json([
            'success' => true,
            'message' => "Joined \"{$class->name}\" successfully.",
            'data' => ['class' => $class],
        ]);
    }

    /**
     * POST /api/classes/{classId}/leave
     */
    public function leave(Request $request, SchoolClass $class)
    {
        $enrollment = Enrollment::where('class_id', $class->id)
            ->where('student_id', $request->user()->id)
            ->first();

        if (!$enrollment) {
            return response()->json(['success' => false, 'message' => 'You are not a member of this class.'], 422);
        }

        $enrollment->delete();

        return response()->json(['success' => true, 'message' => 'Left the class.']);
    }

    /**
     * GET /api/classes/{classId}/students
     */
    public function students(Request $request, SchoolClass $class)
    {
        Gate::forUser($request->user())->authorize('view', $class);

        $students = $class->students()->get();

        return response()->json([
            'success' => true,
            'data' => ['students' => $students],
        ]);
    }

    /**
     * DELETE /api/classes/{classId}/students/{studentId}  (Teacher only)
     */
    public function removeStudent(Request $request, SchoolClass $class, int $studentId)
    {
        Gate::forUser($request->user())->authorize('manage', $class);

        Enrollment::where('class_id', $class->id)->where('student_id', $studentId)->delete();

        return response()->json(['success' => true, 'message' => 'Student removed from class.']);
    }

    /**
     * POST /api/classes/{classId}/students/{studentId}/promote  (Teacher only)
     */
    public function promoteStudent(Request $request, SchoolClass $class, int $studentId)
    {
        Gate::forUser($request->user())->authorize('manage', $class);

        $enrollment = Enrollment::where('class_id', $class->id)->where('student_id', $studentId)->firstOrFail();
        $enrollment->update(['is_class_leader' => !$enrollment->is_class_leader]);

        return response()->json([
            'success' => true,
            'message' => $enrollment->is_class_leader ? 'Student promoted to class leader.' : 'Class leader role removed.',
        ]);
    }

    /**
     * POST /api/classes/{classId}/regenerate-code  (Teacher only)
     */
    public function regenerateCode(Request $request, SchoolClass $class)
    {
        Gate::forUser($request->user())->authorize('manage', $class);

        $class->update(['join_code' => SchoolClass::generateUniqueJoinCode()]);

        return response()->json([
            'success' => true,
            'message' => 'Join code regenerated.',
            'data' => ['join_code' => $class->join_code],
        ]);
    }
}
