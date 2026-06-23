<?php

namespace App\Http\Controllers;

use App\Models\Lesson;
use App\Models\LessonBookmark;
use App\Models\LessonComment;
use App\Models\Classes;
use App\Models\File;
use App\Models\Notification;
use App\Models\StudentProgress;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Storage;

class LessonController extends Controller
{
    // ─── List lessons ─────────────────────────────────────────────
    public function index(Request $request, int $classId): JsonResponse
    {
        $user   = $request->user();
        $class  = Classes::findOrFail($classId);

        $query = Lesson::where('class_id', $classId)->with(['teacher', 'files']);

        if ($user->role->name === 'student') {
            $query->where('is_published', 1);
        }

        $lessons = $query->orderBy('order_index')->orderBy('created_at')->get()
            ->map(fn($l) => $this->formatLesson($l, $user->id));

        return response()->json(['success' => true, 'lessons' => $lessons]);
    }

    // ─── Create lesson ────────────────────────────────────────────
    public function store(Request $request, int $classId): JsonResponse
    {
        $user  = $request->user();
        $class = Classes::findOrFail($classId);

        if ($class->teacher_id !== $user->id && $user->role->name !== 'school_admin') {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

        $validated = $request->validate([
            'title'            => 'required|string|max:300',
            'description'      => 'nullable|string|max:2000',
            'content'          => 'nullable|string',
            'order_index'      => 'nullable|integer',
            'is_published'     => 'boolean',
            'allow_comments'   => 'boolean',
            'allow_downloads'  => 'boolean',
            'files'            => 'nullable|array',
            'files.*'          => 'file|max:102400', // 100MB per file
        ]);

        $lesson = Lesson::create([
            'class_id'        => $classId,
            'teacher_id'      => $user->id,
            'title'           => $validated['title'],
            'description'     => $validated['description'] ?? null,
            'content'         => $validated['content'] ?? null,
            'order_index'     => $validated['order_index'] ?? 0,
            'is_published'    => $validated['is_published'] ?? true,
            'allow_comments'  => $validated['allow_comments'] ?? true,
            'allow_downloads' => $validated['allow_downloads'] ?? true,
        ]);

        // Handle file uploads
        if ($request->hasFile('files')) {
            foreach ($request->file('files') as $uploadedFile) {
                $this->attachFile($uploadedFile, $lesson->id, $user->id);
            }
        }

        // Update progress totals for enrolled students
        StudentProgress::where('class_id', $classId)
            ->increment('lessons_total');

        // Notify students if published
        if ($lesson->is_published) {
            $this->notifyStudents($class, $lesson->id, 'new_lesson',
                "📚 New lesson: {$lesson->title}", "in {$class->name}");
        }

        return response()->json([
            'success' => true,
            'message' => 'Lesson created!',
            'lesson'  => $this->formatLesson($lesson->load(['teacher', 'files']), $user->id),
        ], 201);
    }

    // ─── Get single lesson ────────────────────────────────────────
    public function show(Request $request, int $classId, int $id): JsonResponse
    {
        $user   = $request->user();
        $lesson = Lesson::with(['teacher', 'files'])->findOrFail($id);

        if ($lesson->class_id !== $classId) {
            return response()->json(['success' => false, 'message' => 'Not found'], 404);
        }

        // Track view + update progress
        $lesson->increment('views');
        $this->trackView($user->id, $classId, $lesson->id);

        $data                = $this->formatLesson($lesson, $user->id);
        $data['is_bookmarked'] = LessonBookmark::where('lesson_id', $id)
            ->where('user_id', $user->id)->exists();
        $data['comments_count'] = LessonComment::where('lesson_id', $id)
            ->whereNull('parent_id')->count();

        return response()->json(['success' => true, 'lesson' => $data]);
    }

    // ─── Update lesson ────────────────────────────────────────────
    public function update(Request $request, int $classId, int $id): JsonResponse
    {
        $user   = $request->user();
        $lesson = Lesson::findOrFail($id);
        $class  = Classes::findOrFail($classId);

        if ($lesson->teacher_id !== $user->id && $user->role->name !== 'school_admin') {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

        $validated = $request->validate([
            'title'           => 'sometimes|string|max:300',
            'description'     => 'nullable|string|max:2000',
            'content'         => 'nullable|string',
            'order_index'     => 'nullable|integer',
            'is_published'    => 'boolean',
            'allow_comments'  => 'boolean',
            'allow_downloads' => 'boolean',
        ]);

        $wasUnpublished = !$lesson->is_published;
        $lesson->update($validated);

        // Notify on first publish
        if ($wasUnpublished && ($validated['is_published'] ?? false)) {
            $this->notifyStudents($class, $lesson->id, 'new_lesson',
                "📚 New lesson: {$lesson->title}", "in {$class->name}");
        }

        // Handle new files
        if ($request->hasFile('files')) {
            foreach ($request->file('files') as $uploadedFile) {
                $this->attachFile($uploadedFile, $lesson->id, $user->id);
            }
        }

        return response()->json([
            'success' => true,
            'lesson'  => $this->formatLesson($lesson->fresh(['teacher', 'files']), $user->id),
        ]);
    }

    // ─── Delete lesson ────────────────────────────────────────────
    public function destroy(Request $request, int $classId, int $id): JsonResponse
    {
        $user   = $request->user();
        $lesson = Lesson::findOrFail($id);

        if ($lesson->teacher_id !== $user->id && $user->role->name !== 'school_admin') {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

        // Delete associated files from disk
        foreach ($lesson->files as $file) {
            Storage::disk('public')->delete($file->file_path);
            $file->delete();
        }

        $lesson->delete();

        StudentProgress::where('class_id', $classId)
            ->where('lessons_total', '>', 0)
            ->decrement('lessons_total');

        return response()->json(['success' => true, 'message' => 'Lesson deleted.']);
    }

    // ─── Toggle bookmark ──────────────────────────────────────────
    public function toggleBookmark(Request $request, int $classId, int $id): JsonResponse
    {
        $user = $request->user();
        $existing = LessonBookmark::where('lesson_id', $id)->where('user_id', $user->id)->first();

        if ($existing) {
            $existing->delete();
            return response()->json(['success' => true, 'bookmarked' => false, 'message' => 'Bookmark removed.']);
        }

        LessonBookmark::create(['lesson_id' => $id, 'user_id' => $user->id]);
        return response()->json(['success' => true, 'bookmarked' => true, 'message' => 'Lesson bookmarked!']);
    }

    // ─── Add comment ──────────────────────────────────────────────
    public function addComment(Request $request, int $classId, int $id): JsonResponse
    {
        $lesson = Lesson::findOrFail($id);

        if (!$lesson->allow_comments) {
            return response()->json(['success' => false, 'message' => 'Comments are disabled for this lesson.'], 403);
        }

        $request->validate([
            'body'      => 'required|string|max:2000',
            'parent_id' => 'nullable|exists:lesson_comments,id',
        ]);

        $user    = $request->user();
        $comment = LessonComment::create([
            'lesson_id' => $id,
            'user_id'   => $user->id,
            'parent_id' => $request->parent_id,
            'body'      => $request->body,
        ]);

        return response()->json([
            'success' => true,
            'comment' => [
                'id'         => $comment->id,
                'body'       => $comment->body,
                'parent_id'  => $comment->parent_id,
                'user'       => [
                    'id'           => $user->id,
                    'full_name'    => $user->first_name . ' ' . $user->last_name,
                    'profile_photo'=> $user->profile_photo,
                ],
                'created_at' => $comment->created_at->toISOString(),
            ],
        ], 201);
    }

    // ─── Get comments ─────────────────────────────────────────────
    public function getComments(Request $request, int $classId, int $id): JsonResponse
    {
        $comments = LessonComment::where('lesson_id', $id)
            ->whereNull('parent_id')
            ->with(['user', 'replies.user'])
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        $formatted = $comments->map(fn($c) => [
            'id'         => $c->id,
            'body'       => $c->body,
            'user'       => ['id' => $c->user->id, 'full_name' => $c->user->first_name . ' ' . $c->user->last_name, 'profile_photo' => $c->user->profile_photo],
            'created_at' => $c->created_at->toISOString(),
            'replies'    => $c->replies->map(fn($r) => [
                'id'         => $r->id,
                'body'       => $r->body,
                'user'       => ['id' => $r->user->id, 'full_name' => $r->user->first_name . ' ' . $r->user->last_name, 'profile_photo' => $r->user->profile_photo],
                'created_at' => $r->created_at->toISOString(),
            ]),
        ]);

        return response()->json(['success' => true, 'comments' => $formatted, 'total' => $comments->total()]);
    }

    // ─── Helpers ──────────────────────────────────────────────────
    private function attachFile($uploadedFile, int $lessonId, int $userId): void
    {
        $originalName = $uploadedFile->getClientOriginalName();
        $storedName   = time() . '_' . $originalName;
        $path         = $uploadedFile->storeAs("lessons/{$lessonId}", $storedName, 'public');

        File::create([
            'uploader_id'   => $userId,
            'related_type'  => 'lesson',
            'related_id'    => $lessonId,
            'original_name' => $originalName,
            'stored_name'   => $storedName,
            'file_path'     => $path,
            'file_type'     => $uploadedFile->getMimeType(),
            'file_size'     => $uploadedFile->getSize(),
        ]);
    }

    private function formatLesson(Lesson $lesson, int $userId): array
    {
        return [
            'id'              => $lesson->id,
            'class_id'        => $lesson->class_id,
            'title'           => $lesson->title,
            'description'     => $lesson->description,
            'content'         => $lesson->content,
            'order_index'     => $lesson->order_index,
            'is_published'    => (bool) $lesson->is_published,
            'allow_comments'  => (bool) $lesson->allow_comments,
            'allow_downloads' => (bool) $lesson->allow_downloads,
            'views'           => $lesson->views,
            'teacher'         => $lesson->teacher ? [
                'id'        => $lesson->teacher->id,
                'full_name' => $lesson->teacher->first_name . ' ' . $lesson->teacher->last_name,
            ] : null,
            'files'           => $lesson->files ? $lesson->files->map(fn($f) => [
                'id'            => $f->id,
                'name'          => $f->original_name,
                'type'          => $f->file_type,
                'size'          => $f->file_size,
                'url'           => Storage::disk('public')->url($f->file_path),
                'downloads'     => $f->download_count,
            ]) : [],
            'created_at'      => $lesson->created_at->toISOString(),
            'updated_at'      => $lesson->updated_at->toISOString(),
        ];
    }

    private function trackView(int $userId, int $classId, int $lessonId): void
    {
        $progress = StudentProgress::where('student_id', $userId)->where('class_id', $classId)->first();
        if ($progress) {
            $progress->update(['last_activity' => now()]);

            // Only count once per student per lesson using cache
            $cacheKey = "lesson_view_{$userId}_{$lessonId}";
            if (!\Cache::has($cacheKey)) {
                \Cache::put($cacheKey, true, now()->addDays(7));
                $progress->increment('lessons_viewed');
                $total = max($progress->fresh()->lessons_total, 1);
                $pct   = round(($progress->fresh()->lessons_viewed / $total) * 100);
                $progress->update(['progress_percent' => min($pct, 100)]);
            }
        }
    }

    private function notifyStudents(Classes $class, int $relatedId, string $type, string $title, string $body = ''): void
    {
        $studentIds    = $class->enrollments()->pluck('student_id');
        $notifications = $studentIds->map(fn($id) => [
            'user_id'      => $id,
            'type'         => $type,
            'title'        => $title,
            'body'         => $body,
            'related_type' => 'lesson',
            'related_id'   => $relatedId,
            'action_url'   => "/classes/{$class->id}/lessons/{$relatedId}",
            'created_at'   => now(),
        ])->toArray();

        Notification::insert($notifications);
    }
}
