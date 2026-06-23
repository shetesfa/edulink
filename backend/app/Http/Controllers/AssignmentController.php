<?php

namespace App\Http\Controllers;

use App\Models\Assignment;
use App\Models\AssignmentSubmission;
use App\Models\Classes;
use App\Models\File;
use App\Models\Notification;
use App\Models\StudentProgress;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Storage;

class AssignmentController extends Controller
{
    // ─── List assignments ─────────────────────────────────────────
    public function index(Request $request, int $classId): JsonResponse
    {
        $user  = $request->user();
        $query = Assignment::where('class_id', $classId)->with(['teacher', 'files']);

        if ($user->role->name === 'student') {
            $query->where('is_published', 1);
        }

        $assignments = $query->orderBy('due_date')->get()->map(function ($a) use ($user) {
            $submission = AssignmentSubmission::where('assignment_id', $a->id)
                ->where('student_id', $user->id)->first();

            return array_merge($this->formatAssignment($a), [
                'my_submission' => $submission ? [
                    'id'           => $submission->id,
                    'status'       => $submission->status,
                    'score'        => $submission->score,
                    'feedback'     => $submission->feedback,
                    'submitted_at' => $submission->submitted_at?->toISOString(),
                    'graded_at'    => $submission->graded_at?->toISOString(),
                ] : null,
            ]);
        });

        return response()->json(['success' => true, 'assignments' => $assignments]);
    }

    // ─── Create assignment ────────────────────────────────────────
    public function store(Request $request, int $classId): JsonResponse
    {
        $user  = $request->user();
        $class = Classes::findOrFail($classId);

        if ($class->teacher_id !== $user->id && $user->role->name !== 'school_admin') {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

        $validated = $request->validate([
            'title'        => 'required|string|max:300',
            'description'  => 'required|string',
            'max_score'    => 'nullable|numeric|min:1|max:1000',
            'due_date'     => 'nullable|date|after:now',
            'allow_late'   => 'boolean',
            'is_published' => 'boolean',
            'files'        => 'nullable|array',
            'files.*'      => 'file|max:102400',
        ]);

        $assignment = Assignment::create([
            'class_id'     => $classId,
            'teacher_id'   => $user->id,
            'title'        => $validated['title'],
            'description'  => $validated['description'],
            'max_score'    => $validated['max_score'] ?? 100,
            'due_date'     => $validated['due_date'] ?? null,
            'allow_late'   => $validated['allow_late'] ?? false,
            'is_published' => $validated['is_published'] ?? true,
        ]);

        if ($request->hasFile('files')) {
            foreach ($request->file('files') as $file) {
                $this->attachFile($file, 'assignment', $assignment->id, $user->id);
            }
        }

        StudentProgress::where('class_id', $classId)->increment('assignments_total');

        if ($assignment->is_published) {
            $this->notifyStudents($class, $assignment, 'new_assignment',
                "📝 New assignment: {$assignment->title}",
                $assignment->due_date ? "Due " . $assignment->due_date->format('M d') : 'No deadline');
        }

        return response()->json([
            'success'    => true,
            'message'    => 'Assignment created!',
            'assignment' => $this->formatAssignment($assignment->load(['teacher', 'files'])),
        ], 201);
    }

    // ─── Get single assignment ────────────────────────────────────
    public function show(Request $request, int $classId, int $id): JsonResponse
    {
        $user       = $request->user();
        $assignment = Assignment::with(['teacher', 'files'])->findOrFail($id);

        $data = $this->formatAssignment($assignment);

        if ($user->role->name === 'student') {
            $submission = AssignmentSubmission::where('assignment_id', $id)
                ->where('student_id', $user->id)
                ->with('files')
                ->first();

            $data['my_submission'] = $submission ? [
                'id'           => $submission->id,
                'text_answer'  => $submission->text_answer,
                'status'       => $submission->status,
                'score'        => $submission->score,
                'feedback'     => $submission->feedback,
                'submitted_at' => $submission->submitted_at?->toISOString(),
                'graded_at'    => $submission->graded_at?->toISOString(),
                'files'        => $submission->files ? $submission->files->map(fn($f) => [
                    'id'   => $f->id,
                    'name' => $f->original_name,
                    'url'  => Storage::disk('public')->url($f->file_path),
                    'type' => $f->file_type,
                ]) : [],
            ] : null;
        }

        return response()->json(['success' => true, 'assignment' => $data]);
    }

    // ─── Update assignment ────────────────────────────────────────
    public function update(Request $request, int $classId, int $id): JsonResponse
    {
        $user       = $request->user();
        $assignment = Assignment::findOrFail($id);
        $class      = Classes::findOrFail($classId);

        if ($assignment->teacher_id !== $user->id && $user->role->name !== 'school_admin') {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

        $validated = $request->validate([
            'title'        => 'sometimes|string|max:300',
            'description'  => 'sometimes|string',
            'max_score'    => 'nullable|numeric|min:1',
            'due_date'     => 'nullable|date',
            'allow_late'   => 'boolean',
            'is_published' => 'boolean',
        ]);

        $wasUnpublished = !$assignment->is_published;
        $assignment->update($validated);

        if ($wasUnpublished && ($validated['is_published'] ?? false)) {
            $this->notifyStudents($class, $assignment, 'new_assignment',
                "📝 New assignment: {$assignment->title}", '');
        }

        return response()->json(['success' => true, 'assignment' => $this->formatAssignment($assignment->fresh(['teacher', 'files']))]);
    }

    // ─── Delete assignment ────────────────────────────────────────
    public function destroy(Request $request, int $classId, int $id): JsonResponse
    {
        $user       = $request->user();
        $assignment = Assignment::findOrFail($id);

        if ($assignment->teacher_id !== $user->id && $user->role->name !== 'school_admin') {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

        $assignment->delete();
        StudentProgress::where('class_id', $classId)
            ->where('assignments_total', '>', 0)
            ->decrement('assignments_total');

        return response()->json(['success' => true, 'message' => 'Assignment deleted.']);
    }

    // ─── Student submits assignment ───────────────────────────────
    public function submit(Request $request, int $classId, int $id): JsonResponse
    {
        $user       = $request->user();
        $assignment = Assignment::findOrFail($id);

        $existing = AssignmentSubmission::where('assignment_id', $id)
            ->where('student_id', $user->id)->first();

        if ($existing && $existing->status === 'graded') {
            return response()->json(['success' => false, 'message' => 'Your submission has already been graded.'], 409);
        }

        $request->validate([
            'text_answer' => 'nullable|string|max:20000',
            'files'       => 'nullable|array',
            'files.*'     => 'file|max:102400',
        ]);

        $isLate   = $assignment->due_date && now()->gt($assignment->due_date);
        $status   = $isLate ? 'late' : 'submitted';

        if ($isLate && !$assignment->allow_late) {
            return response()->json(['success' => false, 'message' => 'The deadline for this assignment has passed.'], 403);
        }

        $submission = AssignmentSubmission::updateOrCreate(
            ['assignment_id' => $id, 'student_id' => $user->id],
            ['text_answer' => $request->text_answer, 'status' => $status, 'submitted_at' => now()]
        );

        if ($request->hasFile('files')) {
            // Remove old submission files
            File::where('related_type', 'submission')->where('related_id', $submission->id)
                ->each(function ($f) { Storage::disk('public')->delete($f->file_path); $f->delete(); });

            foreach ($request->file('files') as $file) {
                $this->attachFile($file, 'submission', $submission->id, $user->id);
            }
        }

        // Update progress
        $progress = StudentProgress::where('student_id', $user->id)->where('class_id', $classId)->first();
        if ($progress && !$existing) {
            $progress->increment('assignments_submitted');
        }

        // Notify teacher
        Notification::create([
            'user_id'      => $assignment->teacher_id,
            'type'         => 'assignment_submitted',
            'title'        => "{$user->first_name} submitted: {$assignment->title}",
            'body'         => $isLate ? 'Submitted late' : 'On time',
            'related_type' => 'assignment',
            'related_id'   => $assignment->id,
            'action_url'   => "/classes/{$classId}/assignments/{$id}",
        ]);

        return response()->json([
            'success' => true,
            'message' => $isLate ? 'Submitted (late).' : 'Assignment submitted!',
            'status'  => $status,
        ]);
    }

    // ─── Get all submissions (teacher view) ───────────────────────
    public function submissions(Request $request, int $classId, int $id): JsonResponse
    {
        $user       = $request->user();
        $assignment = Assignment::findOrFail($id);

        if ($assignment->teacher_id !== $user->id && $user->role->name !== 'school_admin') {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

        $submissions = AssignmentSubmission::where('assignment_id', $id)
            ->with(['student', 'files'])
            ->orderBy('submitted_at')
            ->get()
            ->map(fn($s) => [
                'id'           => $s->id,
                'student'      => ['id' => $s->student->id, 'full_name' => $s->student->first_name . ' ' . $s->student->last_name, 'email' => $s->student->email],
                'text_answer'  => $s->text_answer,
                'status'       => $s->status,
                'score'        => $s->score,
                'max_score'    => $assignment->max_score,
                'feedback'     => $s->feedback,
                'submitted_at' => $s->submitted_at?->toISOString(),
                'graded_at'    => $s->graded_at?->toISOString(),
                'files'        => $s->files->map(fn($f) => ['id' => $f->id, 'name' => $f->original_name, 'url' => Storage::disk('public')->url($f->file_path), 'type' => $f->file_type]),
            ]);

        $stats = [
            'total'     => $submissions->count(),
            'submitted' => $submissions->whereIn('status', ['submitted', 'late'])->count(),
            'graded'    => $submissions->where('status', 'graded')->count(),
            'avg_score' => round($submissions->whereNotNull('score')->avg('score') ?? 0, 1),
        ];

        return response()->json(['success' => true, 'submissions' => $submissions, 'stats' => $stats]);
    }

    // ─── Grade a submission ───────────────────────────────────────
    public function grade(Request $request, int $classId, int $id, int $studentId): JsonResponse
    {
        $user       = $request->user();
        $assignment = Assignment::findOrFail($id);

        if ($assignment->teacher_id !== $user->id && $user->role->name !== 'school_admin') {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

        $request->validate([
            'score'    => 'required|numeric|min:0|max:' . $assignment->max_score,
            'feedback' => 'nullable|string|max:2000',
        ]);

        $submission = AssignmentSubmission::where('assignment_id', $id)
            ->where('student_id', $studentId)->firstOrFail();

        $submission->update([
            'score'     => $request->score,
            'feedback'  => $request->feedback,
            'status'    => 'graded',
            'graded_at' => now(),
        ]);

        // Notify student
        $percentage = round(($request->score / $assignment->max_score) * 100);
        Notification::create([
            'user_id'      => $studentId,
            'type'         => 'assignment_graded',
            'title'        => "Assignment graded: {$assignment->title}",
            'body'         => "Score: {$request->score}/{$assignment->max_score} ({$percentage}%)",
            'related_type' => 'assignment',
            'related_id'   => $assignment->id,
            'action_url'   => "/classes/{$classId}/assignments/{$id}",
        ]);

        return response()->json([
            'success'    => true,
            'message'    => 'Grade saved!',
            'score'      => $request->score,
            'percentage' => $percentage,
        ]);
    }

    // ─── Helpers ──────────────────────────────────────────────────
    private function formatAssignment(Assignment $a): array
    {
        return [
            'id'           => $a->id,
            'class_id'     => $a->class_id,
            'title'        => $a->title,
            'description'  => $a->description,
            'max_score'    => $a->max_score,
            'due_date'     => $a->due_date?->toISOString(),
            'allow_late'   => (bool) $a->allow_late,
            'is_published' => (bool) $a->is_published,
            'teacher'      => $a->teacher ? ['id' => $a->teacher->id, 'full_name' => $a->teacher->first_name . ' ' . $a->teacher->last_name] : null,
            'files'        => $a->files ? $a->files->map(fn($f) => ['id' => $f->id, 'name' => $f->original_name, 'url' => Storage::disk('public')->url($f->file_path), 'type' => $f->file_type]) : [],
            'created_at'   => $a->created_at->toISOString(),
        ];
    }

    private function attachFile($uploadedFile, string $type, int $relatedId, int $userId): void
    {
        $originalName = $uploadedFile->getClientOriginalName();
        $storedName   = time() . '_' . $originalName;
        $path         = $uploadedFile->storeAs("{$type}s/{$relatedId}", $storedName, 'public');
        File::create([
            'uploader_id'   => $userId,
            'related_type'  => $type,
            'related_id'    => $relatedId,
            'original_name' => $originalName,
            'stored_name'   => $storedName,
            'file_path'     => $path,
            'file_type'     => $uploadedFile->getMimeType(),
            'file_size'     => $uploadedFile->getSize(),
        ]);
    }

    private function notifyStudents(Classes $class, Assignment $assignment, string $type, string $title, string $body): void
    {
        $studentIds    = $class->enrollments()->pluck('student_id');
        $notifications = $studentIds->map(fn($id) => [
            'user_id'      => $id,
            'type'         => $type,
            'title'        => $title,
            'body'         => $body,
            'related_type' => 'assignment',
            'related_id'   => $assignment->id,
            'action_url'   => "/classes/{$class->id}/assignments/{$assignment->id}",
            'created_at'   => now(),
        ])->toArray();

        Notification::insert($notifications);
    }
}
