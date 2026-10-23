<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Assignments\CreateAssignmentRequest;
use App\Http\Requests\Assignments\SubmitAssignmentRequest;
use App\Http\Requests\Assignments\GradeSubmissionRequest;
use App\Models\SchoolClass;
use App\Models\Assignment;
use App\Models\AssignmentSubmission;
use App\Services\FileUploadService;
use App\Services\NotificationDispatchService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class AssignmentController extends Controller
{
    public function __construct(
        private FileUploadService $fileUploadService,
        private NotificationDispatchService $notifier,
    ) {}

    /**
     * GET /api/classes/{class}/assignments
     */
    public function index(Request $request, SchoolClass $class)
    {
        Gate::forUser($request->user())->authorize('view', $class);

        $query = $class->assignments()->with('files')->latest();

        if (!Gate::forUser($request->user())->allows('manage', $class)) {
            $query->where('is_published', true);
        }

        $assignments = $query->get();

        // For students, attach their own submission status inline for convenience
        if (!Gate::forUser($request->user())->allows('manage', $class)) {
            $studentId = $request->user()->id;
            $assignments->each(function ($a) use ($studentId) {
                $a->my_submission = $a->submissions()->where('student_id', $studentId)->first();
            });
        }

        return response()->json(['success' => true, 'data' => ['assignments' => $assignments]]);
    }

    /**
     * POST /api/classes/{class}/assignments  (Teacher only)
     */
    public function store(CreateAssignmentRequest $request, SchoolClass $class)
    {
        Gate::forUser($request->user())->authorize('manage', $class);

        $data = $request->safe()->except('attachments');
        $data['class_id'] = $class->id;
        $data['teacher_id'] = $request->user()->id;

        $assignment = Assignment::create($data);

        $this->notifyNewAssignment($assignment);

        if ($request->hasFile('attachments')) {
            foreach ($request->file('attachments') as $file) {
                try {
                    $this->fileUploadService->store($file, $request->user()->id, 'assignment', $assignment->id, false);
                } catch (\InvalidArgumentException $e) {
                    continue;
                }
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'Assignment created.',
            'data' => ['assignment' => $assignment->fresh('files')],
        ], 201);
    }

    private function notifyNewAssignment(Assignment $assignment): void
    {
        if (!$assignment->is_published) {
            return;
        }

        $this->notifier->notifyMany($assignment->schoolClass->students, [
            'type' => 'new_assignment',
            'title' => "New assignment: {$assignment->title}",
            'body' => $assignment->schoolClass->name,
            'icon' => 'clipboard',
            'related_type' => 'assignment',
            'related_id' => $assignment->id,
            'action_url' => "/assignments/{$assignment->id}",
            'email_body' => "A new assignment \"{$assignment->title}\" was posted in {$assignment->schoolClass->name}."
                . ($assignment->due_date ? " Due: {$assignment->due_date->format('M j, Y g:i A')}." : ''),
        ]);
    }

    /**
     * GET /api/assignments/{assignment}
     */
    public function show(Request $request, Assignment $assignment)
    {
        Gate::forUser($request->user())->authorize('view', $assignment->schoolClass);

        $data = ['assignment' => $assignment->load('files', 'teacher')];

        if (!Gate::forUser($request->user())->allows('manage', $assignment->schoolClass)) {
            $data['my_submission'] = $assignment->submissions()
                ->where('student_id', $request->user()->id)->with('files')->first();
        } else {
            $data['submissions'] = $assignment->submissions()->with('student', 'files')->get();
        }

        return response()->json(['success' => true, 'data' => $data]);
    }

    /**
     * PUT /api/assignments/{assignment}  (Teacher only)
     */
    public function update(CreateAssignmentRequest $request, Assignment $assignment)
    {
        Gate::forUser($request->user())->authorize('manage', $assignment->schoolClass);

        $assignment->update($request->safe()->except('attachments'));

        return response()->json([
            'success' => true,
            'message' => 'Assignment updated.',
            'data' => ['assignment' => $assignment->fresh('files')],
        ]);
    }

    /**
     * DELETE /api/assignments/{assignment}  (Teacher only)
     */
    public function destroy(Request $request, Assignment $assignment)
    {
        Gate::forUser($request->user())->authorize('manage', $assignment->schoolClass);
        $assignment->delete();

        return response()->json(['success' => true, 'message' => 'Assignment deleted.']);
    }

    /**
     * POST /api/assignments/{assignment}/submit  (Student only)
     */
    public function submit(SubmitAssignmentRequest $request, Assignment $assignment)
    {
        Gate::forUser($request->user())->authorize('view', $assignment->schoolClass);

        if (Gate::forUser($request->user())->allows('manage', $assignment->schoolClass)) {
            return response()->json(['success' => false, 'message' => 'Teachers cannot submit assignments.'], 403);
        }

        $isLate = $assignment->isPastDue();

        if ($isLate && !$assignment->allow_late) {
            return response()->json(['success' => false, 'message' => 'The due date has passed and late submissions are not allowed.'], 422);
        }

        $submission = AssignmentSubmission::updateOrCreate(
            ['assignment_id' => $assignment->id, 'student_id' => $request->user()->id],
            [
                'text_answer' => $request->text_answer,
                'status' => $isLate ? 'late' : 'submitted',
                'submitted_at' => now(),
                // Resubmitting clears any previous grade - it needs to be re-graded
                'score' => null,
                'feedback' => null,
                'graded_at' => null,
            ]
        );

        if ($request->hasFile('attachments')) {
            $files = is_array($request->file('attachments')) ? $request->file('attachments') : [$request->file('attachments')];
            foreach ($files as $file) {
                if ($file) {
                    try {
                        $this->fileUploadService->store($file, $request->user()->id, 'submission', $submission->id, false);
                    } catch (\Throwable $e) {
                        \Log::warning("Submission attachment upload failed: " . $e->getMessage());
                    }
                }
            }
        }

        app(\App\Services\ProgressService::class)->recalculate($request->user(), $assignment->schoolClass);

        return response()->json([
            'success' => true,
            'message' => $isLate ? 'Submitted late.' : 'Submitted successfully.',
            'data' => ['submission' => $submission->fresh('files')],
        ]);
    }

    /**
     * POST /api/submissions/{submission}/grade  (Teacher only)
     */
    public function grade(GradeSubmissionRequest $request, AssignmentSubmission $submission)
    {
        Gate::forUser($request->user())->authorize('manage', $submission->assignment->schoolClass);

        if ($request->score > $submission->assignment->max_score) {
            return response()->json([
                'success' => false,
                'message' => "Score cannot exceed the max score of {$submission->assignment->max_score}.",
            ], 422);
        }

        $submission->update([
            'score' => $request->score,
            'feedback' => $request->feedback,
            'status' => 'graded',
            'graded_at' => now(),
        ]);

        $this->notifier->notifyUser($submission->student, [
            'type' => 'assignment_graded',
            'title' => "Your assignment was graded: {$submission->assignment->title}",
            'body' => "Score: {$request->score}/{$submission->assignment->max_score}",
            'icon' => 'check-circle',
            'related_type' => 'assignment_submission',
            'related_id' => $submission->id,
            'action_url' => "/assignments/{$submission->assignment_id}",
            'email_body' => "Your submission for \"{$submission->assignment->title}\" was graded: "
                . "{$request->score}/{$submission->assignment->max_score}."
                . ($request->feedback ? " Feedback: {$request->feedback}" : ''),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Submission graded.',
            'data' => ['submission' => $submission->fresh()],
        ]);
    }

    public function groups($id)
    {
        $assignment = Assignment::findOrFail($id);
        $groups = \App\Models\AssignmentGroup::where('assignment_id', $id)
            ->with('members.user')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $groups
        ]);
    }

    public function createGroup(Request $request, $id)
    {
        $request->validate(['name' => 'required|string|max:150']);
        $assignment = Assignment::findOrFail($id);

        $group = \App\Models\AssignmentGroup::create([
            'assignment_id' => $assignment->id,
            'name' => $request->name,
            'created_by' => $request->user()->id,
        ]);

        \App\Models\AssignmentGroupMember::create([
            'assignment_group_id' => $group->id,
            'user_id' => $request->user()->id,
        ]);

        return response()->json([
            'success' => true,
            'data' => $group->load('members')
        ]);
    }

    public function joinGroup(Request $request, $id, $groupId)
    {
        $assignment = Assignment::findOrFail($id);
        $group = \App\Models\AssignmentGroup::where('assignment_id', $id)->findOrFail($groupId);

        if ($group->is_full) {
            return response()->json(['success' => false, 'message' => 'Group is full'], 400);
        }

        $memberCount = \App\Models\AssignmentGroupMember::where('assignment_group_id', $group->id)->count();
        if ($memberCount >= $assignment->max_group_size) {
            $group->update(['is_full' => true]);
            return response()->json(['success' => false, 'message' => 'Group is full'], 400);
        }

        \App\Models\AssignmentGroupMember::firstOrCreate([
            'assignment_group_id' => $group->id,
            'user_id' => $request->user()->id,
        ]);

        $newCount = $memberCount + 1;
        if ($newCount >= $assignment->max_group_size) {
            $group->update(['is_full' => true]);
        }

        return response()->json([
            'success' => true,
            'data' => $group->load('members')
        ]);
    }

    public function scoreGroup(Request $request, $groupId)
    {
        $request->validate(['score' => 'required|numeric']);
        $group = \App\Models\AssignmentGroup::with('members')->findOrFail($groupId);
        $assignment = Assignment::findOrFail($group->assignment_id);

        foreach ($group->members as $member) {
            \App\Models\AssignmentSubmission::updateOrCreate(
                [
                    'assignment_id' => $assignment->id,
                    'student_id' => $member->user_id,
                ],
                [
                    'score' => $request->score,
                    'status' => 'graded',
                    'graded_at' => now(),
                    'feedback' => $request->feedback ?? null,
                ]
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Group scored successfully'
        ]);
    }
}
