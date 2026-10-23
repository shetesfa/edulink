<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Lessons\CreateLessonRequest;
use App\Http\Requests\Lessons\UpdateLessonRequest;
use App\Http\Requests\Lessons\CommentLessonRequest;
use App\Models\SchoolClass;
use App\Models\Lesson;
use App\Models\LessonBookmark;
use App\Models\LessonComment;
use App\Models\FileUpload;
use App\Services\FileUploadService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Response as FacadesResponse;

class LessonController extends Controller
{
    public function __construct(private FileUploadService $fileUploadService) {}

    /**
     * GET /api/classes/{class}/lessons
     */
    public function index(Request $request, SchoolClass $class)
    {
        Gate::forUser($request->user())->authorize('view', $class);

        $query = $class->lessons()->with('files')->orderBy('order_index')->orderBy('created_at');

        // Students never see unpublished draft lessons
        if (!Gate::forUser($request->user())->allows('manage', $class)) {
            $query->where('is_published', true);
        }

        return response()->json([
            'success' => true,
            'data' => ['lessons' => $query->get()],
        ]);
    }

    /**
     * POST /api/classes/{class}/lessons  (Teacher only)
     */
    public function store(CreateLessonRequest $request, SchoolClass $class)
    {
        Gate::forUser($request->user())->authorize('manage', $class);

        $data = $request->safe()->except('attachments');
        $data['class_id'] = $class->id;
        $data['teacher_id'] = $request->user()->id;

        $lesson = Lesson::create($data);

        $this->storeAttachments($request, $lesson);

        return response()->json([
            'success' => true,
            'message' => 'Lesson created.',
            'data' => ['lesson' => $lesson->fresh('files')],
        ], 201);
    }

    /**
     * GET /api/lessons/{lesson}
     */
    public function show(Request $request, Lesson $lesson)
    {
        Gate::forUser($request->user())->authorize('view', $lesson->schoolClass);

        $lesson->increment('views');

        \App\Models\LessonView::updateOrCreate(
            ['lesson_id' => $lesson->id, 'user_id' => $request->user()->id],
            ['viewed_at' => now()]
        );

        app(\App\Services\ProgressService::class)->recalculate($request->user(), $lesson->schoolClass);

        return response()->json([
            'success' => true,
            'data' => [
                'lesson' => $lesson->load('files', 'teacher', 'comments'),
                'is_bookmarked' => $lesson->isBookmarkedBy($request->user()->id),
            ],
        ]);
    }

    /**
     * PUT /api/lessons/{lesson}  (Teacher only)
     */
    public function update(UpdateLessonRequest $request, Lesson $lesson)
    {
        Gate::forUser($request->user())->authorize('manage', $lesson->schoolClass);

        $lesson->update($request->validated());

        return response()->json([
            'success' => true,
            'message' => 'Lesson updated.',
            'data' => ['lesson' => $lesson->fresh('files')],
        ]);
    }

    /**
     * DELETE /api/lessons/{lesson}  (Teacher only)
     */
    public function destroy(Request $request, Lesson $lesson)
    {
        Gate::forUser($request->user())->authorize('manage', $lesson->schoolClass);

        $lesson->delete();

        return response()->json(['success' => true, 'message' => 'Lesson deleted.']);
    }

    /**
     * POST /api/lessons/{lesson}/attachments  (Teacher only, add more files later)
     */
    public function uploadAttachments(Request $request, Lesson $lesson)
    {
        Gate::forUser($request->user())->authorize('manage', $lesson->schoolClass);

        $request->validate([
            'attachments' => ['required', 'array'],
            'attachments.*' => ['file', 'max:51200'],
        ]);

        $this->storeAttachments($request, $lesson);

        return response()->json([
            'success' => true,
            'message' => 'Attachments uploaded.',
            'data' => ['lesson' => $lesson->fresh('files')],
        ]);
    }

    private function storeAttachments(Request $request, Lesson $lesson): void
    {
        if (!$request->hasFile('attachments')) {
            return;
        }

        foreach ($request->file('attachments') as $file) {
            try {
                $this->fileUploadService->store($file, $request->user()->id, 'lesson', $lesson->id, false);
            } catch (\InvalidArgumentException $e) {
                // Skip invalid files silently rather than failing the whole request;
                // a real client should validate extensions before upload too.
                continue;
            }
        }
    }

    /**
     * GET /api/files/{file}/download
     */
    public function downloadFile(Request $request, FileUpload $file)
    {
        // Only allow download if the requester can view the related lesson's class
        if ($file->related_type === 'lesson') {
            $lesson = Lesson::find($file->related_id);
            if (!$lesson || !$lesson->allow_downloads || !Gate::forUser($request->user())->allows('view', $lesson->schoolClass)) {
                return response()->json(['success' => false, 'message' => 'You cannot download this file.'], 403);
            }
        }

        $disk = $file->is_public ? 'public' : 'local';

        if (!Storage::disk($disk)->exists($file->file_path)) {
            return response()->json(['success' => false, 'message' => 'File not found.'], 404);
        }

        $file->increment('download_count');

        return Storage::disk($disk)->download($file->file_path, $file->original_name);
    }

    /**
     * POST /api/lessons/{lesson}/bookmark  (toggle)
     */
    public function toggleBookmark(Request $request, Lesson $lesson)
    {
        Gate::forUser($request->user())->authorize('view', $lesson->schoolClass);

        $existing = LessonBookmark::where('lesson_id', $lesson->id)
            ->where('user_id', $request->user()->id)
            ->first();

        if ($existing) {
            $existing->delete();
            return response()->json(['success' => true, 'message' => 'Bookmark removed.', 'data' => ['bookmarked' => false]]);
        }

        LessonBookmark::create(['lesson_id' => $lesson->id, 'user_id' => $request->user()->id]);

        return response()->json(['success' => true, 'message' => 'Lesson bookmarked.', 'data' => ['bookmarked' => true]]);
    }

    /**
     * GET /api/lessons/{lesson}/comments
     */
    public function comments(Request $request, Lesson $lesson)
    {
        Gate::forUser($request->user())->authorize('view', $lesson->schoolClass);

        return response()->json([
            'success' => true,
            'data' => ['comments' => $lesson->comments()->latest()->get()],
        ]);
    }

    /**
     * POST /api/lessons/{lesson}/comments
     */
    public function addComment(CommentLessonRequest $request, Lesson $lesson)
    {
        Gate::forUser($request->user())->authorize('view', $lesson->schoolClass);

        if (!$lesson->allow_comments) {
            return response()->json(['success' => false, 'message' => 'Comments are disabled for this lesson.'], 403);
        }

        $comment = LessonComment::create([
            'lesson_id' => $lesson->id,
            'user_id' => $request->user()->id,
            'parent_id' => $request->parent_id,
            'body' => $request->body,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Comment added.',
            'data' => ['comment' => $comment->load('user')],
        ], 201);
    }

    /**
     * DELETE /api/lessons/comments/{comment}  (author or teacher only)
     */
    public function deleteComment(Request $request, LessonComment $comment)
    {
        $lesson = $comment->lesson;
        $isAuthor = $comment->user_id === $request->user()->id;
        $isTeacher = Gate::forUser($request->user())->allows('manage', $lesson->schoolClass);

        if (!$isAuthor && !$isTeacher) {
            return response()->json(['success' => false, 'message' => 'You cannot delete this comment.'], 403);
        }

        $comment->delete();

        return response()->json(['success' => true, 'message' => 'Comment deleted.']);
    }
}
