<?php

namespace App\Http\Controllers;

use App\Models\Announcement;
use App\Models\Classes;
use App\Models\Notification;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class AnnouncementController extends Controller
{
    public function index(Request $request, int $classId): JsonResponse
    {
        $announcements = Announcement::where('class_id', $classId)
            ->with('author')
            ->orderBy('is_pinned', 'desc')
            ->orderBy('created_at', 'desc')
            ->get()
            ->map(fn($a) => [
                'id'         => $a->id,
                'title'      => $a->title,
                'body'       => $a->body,
                'is_pinned'  => (bool)$a->is_pinned,
                'author'     => [
                    'id'        => $a->author?->id,
                    'full_name' => $a->author?->first_name.' '.$a->author?->last_name,
                ],
                'created_at' => $a->created_at->toISOString(),
            ]);

        return response()->json(['success' => true, 'announcements' => $announcements]);
    }

    public function store(Request $request, int $classId): JsonResponse
    {
        $user  = $request->user();
        $class = Classes::findOrFail($classId);

        if ($class->teacher_id !== $user->id && $user->role->name !== 'school_admin') {
            return response()->json(['success' => false, 'message' => 'Only teachers can post announcements'], 403);
        }

        $request->validate([
            'title' => 'required|string|max:300',
            'body'  => 'required|string|max:5000',
        ]);

        $ann = Announcement::create([
            'class_id'  => $classId,
            'author_id' => $user->id,
            'title'     => $request->title,
            'body'      => $request->body,
        ]);

        // Notify all enrolled students
        $studentIds    = $class->enrollments()->pluck('student_id');
        $notifications = $studentIds->map(fn($sid) => [
            'user_id'      => $sid,
            'type'         => 'new_announcement',
            'title'        => "📢 {$ann->title}",
            'body'         => $class->name,
            'related_type' => 'class',
            'related_id'   => $classId,
            'action_url'   => "/classes/{$classId}",
            'created_at'   => now(),
        ])->toArray();

        if ($notifications) Notification::insert($notifications);

        return response()->json([
            'success'      => true,
            'announcement' => [
                'id'         => $ann->id,
                'title'      => $ann->title,
                'body'       => $ann->body,
                'is_pinned'  => false,
                'author'     => ['id' => $user->id, 'full_name' => $user->first_name.' '.$user->last_name],
                'created_at' => $ann->created_at->toISOString(),
            ],
        ], 201);
    }

    public function update(Request $request, int $classId, int $id): JsonResponse
    {
        $user = $request->user();
        $ann  = Announcement::findOrFail($id);

        if ($ann->author_id !== $user->id && $user->role->name !== 'school_admin') {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

        $ann->update($request->only(['title','body','is_pinned']));

        return response()->json(['success' => true, 'announcement' => $ann]);
    }

    public function destroy(Request $request, int $classId, int $id): JsonResponse
    {
        $user = $request->user();
        $ann  = Announcement::findOrFail($id);

        if ($ann->author_id !== $user->id && $user->role->name !== 'school_admin') {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

        $ann->delete();
        return response()->json(['success' => true, 'message' => 'Deleted.']);
    }
}
