<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SchoolClass;
use App\Models\StudentProgress;
use App\Services\ProgressService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class ProgressController extends Controller
{
    public function __construct(private ProgressService $progressService) {}

    /**
     * GET /api/classes/{class}/progress/me  (Student's own progress card)
     */
    public function mine(Request $request, SchoolClass $class)
    {
        Gate::forUser($request->user())->authorize('view', $class);

        $progress = $this->progressService->recalculate($request->user(), $class);

        return response()->json([
            'success' => true,
            'data' => [
                'progress' => $progress,
                'completion_percent' => $progress->completionPercent(),
            ],
        ]);
    }

    /**
     * GET /api/classes/{class}/progress  (Teacher: everyone's progress, for a chart)
     */
    public function classProgress(Request $request, SchoolClass $class)
    {
        Gate::forUser($request->user())->authorize('manage', $class);

        $students = $class->students;
        $rows = $students->map(function ($student) use ($class) {
            $progress = $this->progressService->recalculate($student, $class);
            return [
                'student' => $student->only(['id', 'first_name', 'last_name', 'email', 'profile_photo']),
                'progress' => $progress,
                'completion_percent' => $progress->completionPercent(),
            ];
        });

        return response()->json([
            'success' => true,
            'data' => [
                'students' => $rows,
                'class_average_completion' => $rows->count() > 0
                    ? round($rows->avg('completion_percent'), 1)
                    : 0,
            ],
        ]);
    }
}
