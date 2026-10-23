<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Announcements\AnnouncementRequest;
use App\Models\SchoolClass;
use App\Models\Announcement;
use App\Services\NotificationDispatchService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class AnnouncementController extends Controller
{
    public function __construct(private NotificationDispatchService $notifier) {}

    /**
     * GET /api/classes/{class}/announcements
     */
    public function index(Request $request, SchoolClass $class)
    {
        Gate::forUser($request->user())->authorize('view', $class);

        $announcements = $class->announcements()
            ->with('author')
            ->orderByDesc('is_pinned')
            ->latest()
            ->get();

        return response()->json(['success' => true, 'data' => ['announcements' => $announcements]]);
    }

    /**
     * POST /api/classes/{class}/announcements  (Teacher only)
     */
    public function store(AnnouncementRequest $request, SchoolClass $class)
    {
        Gate::forUser($request->user())->authorize('manage', $class);

        $announcement = Announcement::create([
            'class_id' => $class->id,
            'author_id' => $request->user()->id,
            'title' => $request->title,
            'body' => $request->body,
            'is_pinned' => $request->boolean('is_pinned'),
        ]);

        $this->notifier->notifyMany($class->students, [
            'type' => 'new_announcement',
            'title' => "New announcement in {$class->name}",
            'body' => $announcement->title,
            'icon' => 'megaphone',
            'related_type' => 'announcement',
            'related_id' => $announcement->id,
            'action_url' => "/classes/{$class->id}/announcements/{$announcement->id}",
            'email_body' => "{$request->user()->fullName()} posted a new announcement in {$class->name}: \"{$announcement->title}\"",
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Announcement posted.',
            'data' => ['announcement' => $announcement->load('author')],
        ], 201);
    }

    /**
     * PUT /api/announcements/{announcement}  (Teacher only)
     */
    public function update(AnnouncementRequest $request, Announcement $announcement)
    {
        Gate::forUser($request->user())->authorize('manage', $announcement->schoolClass);

        $announcement->update($request->validated());

        return response()->json(['success' => true, 'message' => 'Announcement updated.', 'data' => ['announcement' => $announcement->fresh()]]);
    }

    /**
     * DELETE /api/announcements/{announcement}  (Teacher only)
     */
    public function destroy(Request $request, Announcement $announcement)
    {
        Gate::forUser($request->user())->authorize('manage', $announcement->schoolClass);
        $announcement->delete();

        return response()->json(['success' => true, 'message' => 'Announcement deleted.']);
    }
}
