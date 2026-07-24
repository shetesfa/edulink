<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\Assignment;
use App\Models\AssignmentSubmission;
use App\Models\Notification;
use App\Models\Classes;
use App\Models\Enrollment;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class AssignmentController extends Controller
{
    // ─── List assignments for a class ─────────────────────────────
    public function index(Request $request, $classId): JsonResponse
    {
        $user = $request->user();

        $assignments = Assignment::where('class_id', $classId)
            ->orderByDesc('is_pinned')
            ->orderByDesc('created_at')
            ->get()
            ->map(function ($a) use ($user) {
                $mySub = $a->submissions()->where('student_id', $user->id)->latest('submitted_at')->first();
                return [
                    'id'          => $a->id,
                    'title'       => $a->title,
                    'description' => $a->description,
                    'due_date'    => $a->due_date?->toISOString(),
                    'max_score'   => $a->max_score,
                    'is_pinned'   => (bool) $a->is_pinned,
                    'allow_late'  => (bool) $a->allow_late,
                    'class_id'    => $a->class_id,
                    'created_at'  => $a->created_at?->toISOString(),
                    'my_submission' => $mySub ? [
                        'id'           => $mySub->id,
                        'status'       => $mySub->status,
                        'score'        => $mySub->score,
                        'submitted_at' => $mySub->submitted_at?->toISOString(),
                    ] : null,
                ];
            });

        return response()->json(['assignments' => $assignments]);
    }

    // ─── Create assignment ─────────────────────────────────────────
    public function store(Request $request, $classId): JsonResponse
    {
        $this->authorizeTeacher($request->user());

        $validated = $request->validate([
            'title'       => 'required|string|max:255',
            'description' => 'nullable|string',
            'due_date'    => 'nullable|date',
            'max_score'   => 'integer|min:1|max:1000',
            'allow_late'  => 'boolean',
            'attachments' => 'nullable|array',
            'attachments.*' => 'file|max:20480',
        ]);

        $attachments = [];
        if ($request->hasFile('attachments')) {
            foreach ($request->file('attachments') as $file) {
                $path = $file->store("assignments/{$classId}", 'public');
                $attachments[] = [
                    'url'           => Storage::disk('public')->url($path),
                    'original_name' => $file->getClientOriginalName(),
                    'size'          => $file->getSize(),
                    'mime'          => $file->getMimeType(),
                ];
            }
        }

        $assignment = Assignment::create([
            'class_id'    => $classId,
            'teacher_id'  => $request->user()->id,
            'title'       => $validated['title'],
            'description' => $validated['description'] ?? null,
            'due_date'    => $validated['due_date'] ?? null,
            'max_score'   => $validated['max_score'] ?? 100,
            'allow_late'  => $validated['allow_late'] ?? false,
        ]);

        if (!empty($attachments)) {
            $insertData = array_map(function($att) use ($assignment, $request) {
                return [
                    'assignment_id' => $assignment->id,
                    'uploader_id'   => $request->user()->id,
                    'original_name' => $att['original_name'],
                    'stored_name'   => basename($att['url']),
                    'file_path'     => $att['url'],
                    'file_size'     => $att['size'],
                    'file_type'     => $att['mime'],
                    'created_at'    => now(),
                ];
            }, $attachments);
            \Illuminate\Support\Facades\DB::table('assignment_attachments')->insert($insertData);
        }

        // Notify all enrolled students
        $class = Classes::findOrFail($classId);
        $studentIds = $class->enrollments()->pluck('student_id');
        $notifications = $studentIds->map(fn($id) => [
            'user_id'      => $id,
            'type'         => 'new_assignment',
            'title'        => "📝 New Assignment: {$assignment->title}",
            'body'         => $assignment->description ? substr($assignment->description, 0, 100) . '...' : 'Check your class for details.',
            'icon'         => 'FileText',
            'related_type' => 'assignment',
            'related_id'   => $assignment->id,
            'action_url'   => "/classes/{$classId}/assignments/{$assignment->id}",
            'is_read'      => 0,
            'created_at'   => now(),
        ])->toArray();

        if (!empty($notifications)) {
            Notification::insert($notifications);
        }

        return response()->json(['success' => true, 'assignment' => $assignment], 201);
    }

    // ─── Get single assignment ─────────────────────────────────────
    public function show(Request $request, $classId, $id): JsonResponse
    {
        $user       = $request->user();
        $assignment = Assignment::where('class_id', $classId)->findOrFail($id);
        $mySub      = $assignment->submissions()->where('student_id', $user->id)->latest('submitted_at')->first();

        $data = $assignment->toArray();
        $dbAtts = \Illuminate\Support\Facades\DB::table('assignment_attachments')->where('assignment_id', $assignment->id)->get();
        $data['attachments']  = $dbAtts->map(fn($a) => [
            'url'           => $a->file_path,
            'original_name' => $a->original_name,
            'size'          => $a->file_size,
            'mime'          => $a->file_type,
        ]);
        $data['my_submission'] = $mySub ? [
            'id'          => $mySub->id,
            'text_answer' => $mySub->text_answer,
            'status'      => $mySub->status,
            'score'       => $mySub->score,
            'feedback'    => $mySub->feedback,
            'submitted_at'=> $mySub->submitted_at?->toISOString(),
            'graded_at'   => $mySub->graded_at?->toISOString(),
        ] : null;

        return response()->json(['assignment' => $data]);
    }

    // ─── Update assignment ─────────────────────────────────────────
    public function update(Request $request, $classId, $id): JsonResponse
    {
        $this->authorizeTeacher($request->user());
        $assignment = Assignment::where('class_id', $classId)->findOrFail($id);
        $assignment->update($request->only(['title', 'description', 'due_date', 'max_score', 'allow_late']));
        return response()->json(['success' => true, 'assignment' => $assignment]);
    }

    // ─── Delete assignment ─────────────────────────────────────────
    public function destroy(Request $request, $classId, $id): JsonResponse
    {
        $this->authorizeTeacher($request->user());
        Assignment::where('class_id', $classId)->findOrFail($id)->delete();
        return response()->json(['success' => true]);
    }

    // ─── Student: submit assignment ────────────────────────────────
    public function submit(Request $request, $classId, $id): JsonResponse
    {
        $user       = $request->user();
        $assignment = Assignment::where('class_id', $classId)->findOrFail($id);

        // Check due date
        $isLate = $assignment->due_date && now()->isAfter($assignment->due_date);
        if ($isLate && !$assignment->allow_late) {
            return response()->json([
                'success' => false,
                'message' => 'The deadline has passed and late submissions are not accepted.',
            ], 422);
        }

        $request->validate([
            'text_answer' => 'nullable|string',
            'files'       => 'nullable|array',
            'files.*'     => 'file|max:20480',
        ]);

        $fileData = [];
        if ($request->hasFile('files')) {
            foreach ($request->file('files') as $file) {
                $path = $file->store("submissions/{$assignment->id}/{$user->id}", 'public');
                $fileData[] = [
                    'url'           => Storage::disk('public')->url($path),
                    'stored_name'   => basename($path),
                    'original_name' => $file->getClientOriginalName(),
                    'size'          => $file->getSize(),
                    'mime'          => $file->getMimeType(),
                ];
            }
        }

        $submittedAt = now();

        // Upsert submission
        $submission = AssignmentSubmission::updateOrCreate(
            ['assignment_id' => $assignment->id, 'student_id' => $user->id],
            [
                'text_answer'  => $request->text_answer,
                'status'       => $isLate ? 'late' : 'submitted',
                'submitted_at' => $submittedAt,
            ]
        );

        // Save files into assignment_attachments (delete old ones first on re-submit)
        if (!empty($fileData)) {
            \Illuminate\Support\Facades\DB::table('assignment_attachments')
                ->where('submission_id', $submission->id)
                ->delete();

            $insertData = array_map(fn($f) => [
                'assignment_id' => $assignment->id,
                'submission_id' => $submission->id,
                'uploader_id'   => $user->id,
                'original_name' => $f['original_name'],
                'stored_name'   => $f['stored_name'],
                'file_path'     => $f['url'],
                'file_size'     => $f['size'],
                'file_type'     => $f['mime'],
                'created_at'    => now(),
            ], $fileData);

            \Illuminate\Support\Facades\DB::table('assignment_attachments')->insert($insertData);
        }

        // Return files for immediate frontend display
        $savedFiles = \Illuminate\Support\Facades\DB::table('assignment_attachments')
            ->where('submission_id', $submission->id)
            ->get(['original_name','file_path','file_size','file_type'])
            ->map(fn($f) => [
                'url'           => $f->file_path,
                'original_name' => $f->original_name,
                'size'          => $f->file_size,
                'mime'          => $f->file_type,
            ])->values();

        return response()->json([
            'success'    => true,
            'message'    => $isLate ? 'Late submission received.' : 'Assignment submitted!',
            'submission' => [
                'id'           => $submission->id,
                'status'       => $submission->status,
                'text_answer'  => $submission->text_answer,
                'submitted_at' => $submission->submitted_at?->toISOString(),
                'files'        => $savedFiles,
            ],
        ]);
    }

    // ─── Teacher: list all submissions ────────────────────────────
    public function submissions(Request $request, $classId, $id): JsonResponse
    {
        $this->authorizeTeacher($request->user());
        $assignment = Assignment::where('class_id', $classId)->findOrFail($id);

        $submissions = $assignment->submissions()
            ->with('student:id,first_name,last_name,email,profile_photo')
            ->orderBy('submitted_at')
            ->get()
            ->map(fn($s) => [
                'id'               => $s->id,
                'student_name'     => $s->student ? "{$s->student->first_name} {$s->student->last_name}" : 'Unknown',
                'student_email'    => $s->student?->email,
                'text_answer'      => $s->text_answer,
                'status'           => $s->status,
                'score'            => $s->score,
                'feedback'         => $s->feedback,
                'submitted_at'     => $s->submitted_at?->toISOString(),
                'graded_at'        => $s->graded_at?->toISOString(),
                'files'            => \Illuminate\Support\Facades\DB::table('assignment_attachments')
                                        ->where('submission_id', $s->id)
                                        ->get(['original_name','file_path','file_size','file_type'])
                                        ->map(fn($f) => [
                                            'url'           => $f->file_path,
                                            'original_name' => $f->original_name,
                                            'size'          => $f->file_size,
                                            'mime'          => $f->file_type,
                                        ])->values(),
            ]);

        return response()->json(['submissions' => $submissions]);
    }

    // ─── Teacher: grade a submission ──────────────────────────────
    public function grade(Request $request, $classId, $id, $submissionId): JsonResponse
    {
        $this->authorizeTeacher($request->user());

        $request->validate([
            'score'    => 'required|numeric|min:0',
            'feedback' => 'nullable|string|max:2000',
        ]);

        $submission = AssignmentSubmission::findOrFail($submissionId);
        $submission->update([
            'score'     => $request->score,
            'feedback'  => $request->feedback,
            'status'    => 'graded',
            'graded_at' => now(),
        ]);

        return response()->json([
            'success'    => true,
            'submission' => [
                'id'        => $submission->id,
                'score'     => $submission->score,
                'feedback'  => $submission->feedback,
                'status'    => $submission->status,
                'graded_at' => $submission->graded_at?->toISOString(),
            ],
        ]);
    }

    // ─── Teacher: toggle pin ──────────────────────────────────────
    public function togglePin(Request $request, $classId, $id): JsonResponse
    {
        $this->authorizeTeacher($request->user());
        $assignment = Assignment::where('class_id', $classId)->findOrFail($id);

        $newState = !$assignment->is_pinned;
        $assignment->update([
            'is_pinned' => $newState,
            'pinned_at' => $newState ? now() : null,
            'pinned_by' => $newState ? $request->user()->id : null,
        ]);

        // Broadcast to class via socket (non-fatal)
        $this->broadcastPinUpdate($classId, [
            'type'         => 'assignment',
            'id'           => $assignment->id,
            'title'        => $assignment->title,
            'class_id'     => $classId,
            'is_pinned'    => $newState,
            'teacher_name' => $request->user()->full_name ?? 'Teacher',
            'due_date'     => $assignment->due_date?->toISOString(),
        ]);

        return response()->json([
            'success'   => true,
            'is_pinned' => $newState,
            'message'   => $newState
                ? '📌 Pinned to all students\' dashboards!'
                : 'Unpinned from dashboards.',
        ]);
    }

    // ─────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────
    private function authorizeTeacher($user): void
    {
        if ($user->role_id < 3) abort(403, 'Only teachers can manage assignments.');
    }

    private function broadcastPinUpdate($classId, array $item): void
    {
        try {
            $port   = config('services.socket.internal_port', 3002);
            $secret = config('services.socket.secret', 'edulink_internal');
            \Illuminate\Support\Facades\Http::timeout(2)
                ->withHeaders(['X-Internal-Secret' => $secret])
                ->post("http://localhost:{$port}/broadcast", [
                    'room'  => "class:{$classId}",
                    'event' => 'class:pin-update',
                    'data'  => ['class_id' => $classId, 'item' => $item],
                ]);
        } catch (\Exception $e) {
            Log::debug('Pin broadcast non-critical: ' . $e->getMessage());
        }
    }
}
