<?php

namespace App\Http\Controllers;

use App\Models\VideoMeeting;
use App\Models\Classes;
use App\Models\Notification;
use Firebase\JWT\JWT;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Str;

class VideoMeetingController extends Controller
{
    // ─── List meetings ────────────────────────────────────────────
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $meetings = VideoMeeting::where('host_id', $user->id)
            ->orWhereHas('class.enrollments', fn($q) => $q->where('student_id', $user->id))
            ->with(['host', 'class'])
            ->orderBy('scheduled_at', 'asc')
            ->get()
            ->map(fn($m) => $this->formatMeeting($m));

        return response()->json(['success' => true, 'meetings' => $meetings]);
    }

    // ─── Create meeting ───────────────────────────────────────────
    public function create(Request $request): JsonResponse
    {
        $request->validate([
            'title'        => 'required|string|max:300',
            'class_id'     => 'nullable|exists:classes,id',
            'scheduled_at' => 'nullable|date|after:now',
            'is_recorded'  => 'boolean',
        ]);

        $user = $request->user();

        // Generate unique Jitsi room ID
        $roomId = 'edulink-' . Str::random(12) . '-' . time();

        $meeting = VideoMeeting::create([
            'class_id'     => $request->class_id,
            'host_id'      => $user->id,
            'title'        => $request->title,
            'room_id'      => $roomId,
            'scheduled_at' => $request->scheduled_at,
            'is_recorded'  => $request->is_recorded ?? false,
            'status'       => 'scheduled',
        ]);

        // Notify class students if linked to a class
        if ($request->class_id) {
            $class = Classes::findOrFail($request->class_id);
            $studentIds = $class->enrollments()->pluck('student_id');
            $scheduledStr = $meeting->scheduled_at
                ? $meeting->scheduled_at->format('M d \a\t H:i')
                : 'Starting soon';

            $notifications = $studentIds->map(fn($id) => [
                'user_id'      => $id,
                'type'         => 'meeting_scheduled',
                'title'        => "🎥 Meeting: {$meeting->title}",
                'body'         => $scheduledStr,
                'related_type' => 'meeting',
                'related_id'   => $meeting->id,
                'action_url'   => "/meetings/{$meeting->id}",
                'created_at'   => now(),
            ])->toArray();

            Notification::insert($notifications);
        }

        return response()->json([
            'success' => true,
            'meeting' => $this->formatMeeting($meeting->load(['host', 'class'])),
        ], 201);
    }

    // ─── Get meeting ──────────────────────────────────────────────
    public function show(Request $request, int $id): JsonResponse
    {
        $meeting = VideoMeeting::with(['host', 'class'])->findOrFail($id);
        return response()->json(['success' => true, 'meeting' => $this->formatMeeting($meeting)]);
    }

    // ─── Start meeting ────────────────────────────────────────────
    public function start(Request $request, int $id): JsonResponse
    {
        $user    = $request->user();
        $meeting = VideoMeeting::findOrFail($id);

        if ($meeting->host_id !== $user->id) {
            return response()->json(['success' => false, 'message' => 'Only the host can start the meeting'], 403);
        }

        $meeting->update(['status' => 'live', 'started_at' => now()]);

        return response()->json(['success' => true, 'meeting' => $this->formatMeeting($meeting->fresh(['host', 'class']))]);
    }

    // ─── End meeting ──────────────────────────────────────────────
    public function end(Request $request, int $id): JsonResponse
    {
        $user    = $request->user();
        $meeting = VideoMeeting::findOrFail($id);

        if ($meeting->host_id !== $user->id) {
            return response()->json(['success' => false, 'message' => 'Only the host can end the meeting'], 403);
        }

        $meeting->update(['status' => 'ended', 'ended_at' => now()]);

        return response()->json(['success' => true, 'message' => 'Meeting ended.']);
    }

    // ─── Get Jitsi JWT token ──────────────────────────────────────
    public function getJitsiToken(Request $request, int $id): JsonResponse
    {
        $user    = $request->user();
        $meeting = VideoMeeting::findOrFail($id);

        $appId     = config('services.jitsi.app_id');
        $appSecret = config('services.jitsi.app_secret');
        $domain    = config('services.jitsi.domain', 'meet.jit.si');

        $isHost    = $meeting->host_id === $user->id;

        // Build Jitsi JWT
        $payload = [
            'iss'     => $appId,
            'sub'     => $domain,
            'aud'     => 'jitsi',
            'room'    => $meeting->room_id,
            'iat'     => time(),
            'exp'     => time() + 10800, // 3 hours
            'nbf'     => time() - 10,
            'context' => [
                'user' => [
                    'id'           => (string) $user->id,
                    'name'         => $user->first_name . ' ' . $user->last_name,
                    'email'        => $user->email,
                    'avatar'       => $user->profile_photo,
                    'moderator'    => $isHost,
                ],
                'features' => [
                    'livestreaming' => $isHost,
                    'recording'     => $isHost && $meeting->is_recorded,
                    'screen-sharing'=> true,
                    'outbound-call' => false,
                ],
            ],
            'moderator' => $isHost,
        ];

        // If no Jitsi app configured, generate a simple token
        if (!$appSecret || $appSecret === 'YOUR_JITSI_APP_SECRET') {
            // Use public Jitsi (meet.jit.si) without auth — works free
            return response()->json([
                'success'  => true,
                'token'    => null,  // Public Jitsi doesn't need token
                'room_id'  => $meeting->room_id,
                'domain'   => 'meet.jit.si',
                'is_host'  => $isHost,
                'user_info'=> ['name' => $user->first_name . ' ' . $user->last_name, 'email' => $user->email],
            ]);
        }

        $token = JWT::encode($payload, $appSecret, 'HS256');

        return response()->json([
            'success'  => true,
            'token'    => $token,
            'room_id'  => $meeting->room_id,
            'domain'   => $domain,
            'is_host'  => $isHost,
            'user_info'=> ['name' => $user->first_name . ' ' . $user->last_name, 'email' => $user->email],
        ]);
    }

    // ─── Format helper ────────────────────────────────────────────
    private function formatMeeting(VideoMeeting $m): array
    {
        return [
            'id'               => $m->id,
            'title'            => $m->title,
            'room_id'          => $m->room_id,
            'status'           => $m->status,
            'scheduled_at'     => $m->scheduled_at?->toISOString(),
            'started_at'       => $m->started_at?->toISOString(),
            'ended_at'         => $m->ended_at?->toISOString(),
            'is_recorded'      => (bool) $m->is_recorded,
            'recording_url'    => $m->recording_url,
            'participant_count'=> $m->participant_count,
            'class'            => $m->class ? ['id' => $m->class->id, 'name' => $m->class->name] : null,
            'host'             => $m->host ? ['id' => $m->host->id, 'full_name' => $m->host->first_name . ' ' . $m->host->last_name, 'profile_photo' => $m->host->profile_photo] : null,
            'created_at'       => $m->created_at->toISOString(),
        ];
    }
}
