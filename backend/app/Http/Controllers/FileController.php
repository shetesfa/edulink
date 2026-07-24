<?php

namespace App\Http\Controllers;

use App\Models\Assignment;
use App\Models\AssignmentSubmission;
use App\Models\Classes;
use App\Models\Enrollment;
use App\Models\File;
use App\Models\GroupChatMember;
use App\Models\Lesson;
use App\Models\Message;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Storage;

// ─────────────────────────────────────────────────────────────
// FileController
// ─────────────────────────────────────────────────────────────
class FileController extends Controller
{
    public function upload(Request $request): JsonResponse
    {
        $request->validate([
            'file'         => 'required|file|max:102400',
            'related_type' => 'nullable|in:lesson,assignment,message,submission',
            'related_id'   => 'nullable|integer',
        ]);

        $user         = $request->user();
        if ($request->filled('related_type') || $request->filled('related_id')) {
            if (!$request->filled('related_type') || !$request->filled('related_id')) {
                return response()->json(['success' => false, 'message' => 'Both related_type and related_id are required.'], 422);
            }

            if (!$this->canAttachTo($request->related_type, (int) $request->related_id, $user)) {
                return response()->json(['success' => false, 'message' => 'Unauthorized file target.'], 403);
            }
        }

        $uploadedFile = $request->file('file');
        $originalName = $uploadedFile->getClientOriginalName();
        $storedName   = time().'_'.preg_replace('/[^a-zA-Z0-9._-]/', '_', $originalName);
        $folder       = $request->related_type ? $request->related_type.'s' : 'uploads';
        $path         = $uploadedFile->storeAs("{$folder}/{$user->id}", $storedName, 'public');

        $file = File::create([
            'uploader_id'   => $user->id,
            'related_type'  => $request->related_type,
            'related_id'    => $request->related_id,
            'original_name' => $originalName,
            'stored_name'   => $storedName,
            'file_path'     => $path,
            'file_type'     => $uploadedFile->getMimeType(),
            'file_size'     => $uploadedFile->getSize(),
        ]);

        return response()->json([
            'success' => true,
            'file'    => [
                'id'   => $file->id,
                'name' => $file->original_name,
                'url'  => Storage::disk('public')->url($path),
                'type' => $file->file_type,
                'size' => $file->file_size,
            ],
        ], 201);
    }

    public function download(Request $request, int $id): \Symfony\Component\HttpFoundation\StreamedResponse
    {
        $file = File::findOrFail($id);
        abort_unless($this->canAccessFile($file, $request->user()), 403, 'Unauthorized');

        $file->increment('download_count');
        return Storage::disk('public')->download($file->file_path, $file->original_name);
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $file = File::findOrFail($id);
        if ($file->uploader_id !== $request->user()->id && $request->user()->role->name !== 'school_admin') {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }
        Storage::disk('public')->delete($file->file_path);
        $file->delete();
        return response()->json(['success' => true]);
    }

    private function canAccessFile(File $file, $user): bool
    {
        if ($file->is_public || $file->uploader_id === $user->id) {
            return true;
        }

        return match ($file->related_type) {
            'lesson' => $this->canAccessLesson((int) $file->related_id, $user),
            'assignment' => $this->canAccessAssignment((int) $file->related_id, $user),
            'submission' => $this->canAccessSubmission((int) $file->related_id, $user),
            'message' => $this->canAccessMessage((int) $file->related_id, $user),
            default => false,
        };
    }

    private function canAttachTo(string $type, int $id, $user): bool
    {
        return match ($type) {
            'lesson' => $this->canManageLesson($id, $user),
            'assignment' => $this->canManageAssignment($id, $user),
            'submission' => $this->canAccessSubmission($id, $user),
            'message' => $this->canAccessMessage($id, $user),
            default => false,
        };
    }

    private function canAccessLesson(int $lessonId, $user): bool
    {
        $lesson = Lesson::find($lessonId);
        if (!$lesson) {
            return false;
        }

        return $this->canAccessClass((int) $lesson->class_id, $user);
    }

    private function canAccessAssignment(int $assignmentId, $user): bool
    {
        $assignment = Assignment::find($assignmentId);
        if (!$assignment) {
            return false;
        }

        return $this->canAccessClass((int) $assignment->class_id, $user);
    }

    private function canManageLesson(int $lessonId, $user): bool
    {
        $lesson = Lesson::find($lessonId);
        return $lesson ? $this->canManageClass((int) $lesson->class_id, $user) : false;
    }

    private function canManageAssignment(int $assignmentId, $user): bool
    {
        $assignment = Assignment::find($assignmentId);
        return $assignment ? $this->canManageClass((int) $assignment->class_id, $user) : false;
    }

    private function canAccessSubmission(int $submissionId, $user): bool
    {
        $submission = AssignmentSubmission::with('assignment')->find($submissionId);
        if (!$submission || !$submission->assignment) {
            return false;
        }

        return $submission->student_id === $user->id
            || $this->canManageClass((int) $submission->assignment->class_id, $user);
    }

    private function canAccessMessage(int $messageId, $user): bool
    {
        $message = Message::find($messageId);
        if (!$message) {
            return false;
        }

        if ($message->group_id) {
            return GroupChatMember::where('group_id', $message->group_id)
                ->where('user_id', $user->id)
                ->exists();
        }

        return $message->sender_id === $user->id || $message->receiver_id === $user->id;
    }

    private function canAccessClass(int $classId, $user): bool
    {
        return $this->canManageClass($classId, $user)
            || Enrollment::where('class_id', $classId)->where('student_id', $user->id)->exists();
    }

    private function canManageClass(int $classId, $user): bool
    {
        $class = Classes::find($classId);
        if (!$class) {
            return false;
        }

        return $class->teacher_id === $user->id
            || ($user->role->name === 'school_admin' && $class->school_id === $user->school_id);
    }
}
