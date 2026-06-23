<?php
// ─── NotificationController ───────────────────────────────────
namespace App\Http\Controllers;

use App\Models\Notification;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class NotificationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $notifications = Notification::where('user_id', $request->user()->id)
            ->orderBy('created_at', 'desc')
            ->take(50)->get()
            ->map(fn($n) => [
                'id'           => $n->id,
                'type'         => $n->type,
                'title'        => $n->title,
                'body'         => $n->body,
                'icon'         => $n->icon,
                'related_type' => $n->related_type,
                'related_id'   => $n->related_id,
                'action_url'   => $n->action_url,
                'is_read'      => (bool) $n->is_read,
                'created_at'   => $n->created_at->toISOString(),
            ]);

        return response()->json(['success' => true, 'notifications' => $notifications]);
    }

    public function unreadCount(Request $request): JsonResponse
    {
        $count = Notification::where('user_id', $request->user()->id)->where('is_read', 0)->count();
        return response()->json(['success' => true, 'count' => $count]);
    }

    public function markRead(Request $request, int $id): JsonResponse
    {
        Notification::where('id', $id)->where('user_id', $request->user()->id)->update(['is_read' => 1]);
        return response()->json(['success' => true]);
    }

    public function markAllRead(Request $request): JsonResponse
    {
        Notification::where('user_id', $request->user()->id)->where('is_read', 0)->update(['is_read' => 1]);
        return response()->json(['success' => true]);
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        Notification::where('id', $id)->where('user_id', $request->user()->id)->delete();
        return response()->json(['success' => true]);
    }
}
