<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    /**
     * GET /api/notifications
     */
    public function index(Request $request)
    {
        $notifications = AppNotification::where('user_id', $request->user()->id)
            ->latest()
            ->paginate(20);

        return response()->json(['success' => true, 'data' => ['notifications' => $notifications]]);
    }

    /**
     * GET /api/notifications/unread-count
     */
    public function unreadCount(Request $request)
    {
        $count = AppNotification::where('user_id', $request->user()->id)->where('is_read', false)->count();

        return response()->json(['success' => true, 'data' => ['unread_count' => $count]]);
    }

    /**
     * POST /api/notifications/{notification}/read
     */
    public function markRead(Request $request, AppNotification $notification)
    {
        if ($notification->user_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'Not your notification.'], 403);
        }

        $notification->update(['is_read' => true]);

        return response()->json(['success' => true, 'message' => 'Marked as read.']);
    }

    /**
     * POST /api/notifications/read-all
     */
    public function markAllRead(Request $request)
    {
        AppNotification::where('user_id', $request->user()->id)->where('is_read', false)->update(['is_read' => true]);

        return response()->json(['success' => true, 'message' => 'All notifications marked as read.']);
    }

    /**
     * DELETE /api/notifications/{notification}
     */
    public function destroy(Request $request, AppNotification $notification)
    {
        if ($notification->user_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'Not your notification.'], 403);
        }

        $notification->delete();

        return response()->json(['success' => true, 'message' => 'Notification deleted.']);
    }
}
