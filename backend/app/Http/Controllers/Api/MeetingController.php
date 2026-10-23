<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Meetings\CreateMeetingRequest;
use App\Models\SchoolClass;
use App\Models\VideoMeeting;
use App\Services\MeetingService;
use App\Services\NotificationDispatchService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class MeetingController extends Controller
{
    public function __construct(
        private MeetingService $meetingService,
        private NotificationDispatchService $notifier,
    ) {}

    /**
     * GET /api/meetings
     * Meetings the user hosts, plus meetings for classes they belong to.
     */
    public function index(Request $request)
    {
        $user = $request->user();
        $classIds = $user->enrolledClasses()->pluck('classes.id')
            ->merge($user->classesTaught()->pluck('id'));

        $meetings = VideoMeeting::where('host_id', $user->id)
            ->orWhereIn('class_id', $classIds)
            ->with('host', 'schoolClass')
            ->orderByDesc('scheduled_at')
            ->get();

        return response()->json(['success' => true, 'data' => ['meetings' => $meetings]]);
    }

    /**
     * POST /api/meetings
     */
    public function store(CreateMeetingRequest $request)
    {
        if ($request->class_id) {
            $class = SchoolClass::findOrFail($request->class_id);
            Gate::forUser($request->user())->authorize('manage', $class);
        }

        $meeting = VideoMeeting::create([
            'class_id' => $request->class_id,
            'host_id' => $request->user()->id,
            'title' => $request->title,
            'room_id' => VideoMeeting::generateUniqueRoomId(),
            'scheduled_at' => $request->scheduled_at,
            'status' => 'scheduled',
        ]);

        if ($request->class_id) {
            $this->notifier->notifyMany($class->students, [
                'type' => 'new_meeting',
                'title' => "Meeting scheduled: {$meeting->title}",
                'body' => $class->name,
                'icon' => 'video',
                'related_type' => 'meeting',
                'related_id' => $meeting->id,
                'action_url' => "/meetings/{$meeting->id}",
                'email_body' => "A meeting \"{$meeting->title}\" was scheduled in {$class->name}"
                    . ($meeting->scheduled_at ? " for {$meeting->scheduled_at->format('M j, Y g:i A')}." : '.'),
            ]);
        }

        return response()->json(['success' => true, 'message' => 'Meeting scheduled.', 'data' => ['meeting' => $meeting]], 201);
    }

    /**
     * GET /api/meetings/{meeting}
     */
    public function show(Request $request, VideoMeeting $meeting)
    {
        return response()->json(['success' => true, 'data' => ['meeting' => $meeting->load('host', 'schoolClass')]]);
    }

    /**
     * POST /api/meetings/{meeting}/start  (Host only)
     */
    public function start(Request $request, VideoMeeting $meeting)
    {
        if ($meeting->host_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'Only the host can start this meeting.'], 403);
        }

        $meeting->update(['status' => 'live', 'started_at' => now()]);

        return response()->json(['success' => true, 'message' => 'Meeting started.', 'data' => ['meeting' => $meeting->fresh()]]);
    }

    /**
     * POST /api/meetings/{meeting}/end  (Host only)
     */
    public function end(Request $request, VideoMeeting $meeting)
    {
        if ($meeting->host_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'Only the host can end this meeting.'], 403);
        }

        $meeting->update(['status' => 'ended', 'ended_at' => now()]);

        return response()->json(['success' => true, 'message' => 'Meeting ended.', 'data' => ['meeting' => $meeting->fresh()]]);
    }

    /**
     * GET /api/meetings/{meeting}/token
     * Returns everything Flutter needs to open the Jitsi call.
     */
    public function token(Request $request, VideoMeeting $meeting)
    {
        if ($meeting->status === 'ended') {
            return response()->json(['success' => false, 'message' => 'This meeting has already ended.'], 422);
        }

        // If class-linked, only members/teacher of that class may join
        if ($meeting->class_id) {
            Gate::forUser($request->user())->authorize('view', $meeting->schoolClass);
        }

        $joinInfo = $this->meetingService->buildJoinInfo($meeting, $request->user());
        $meeting->increment('participant_count');

        return response()->json(['success' => true, 'data' => ['join' => $joinInfo]]);
    }

    /**
     * DELETE /api/meetings/{meeting}  (Host only)
     */
    public function destroy(Request $request, VideoMeeting $meeting)
    {
        if ($meeting->host_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'Only the host can delete this meeting.'], 403);
        }

        $meeting->delete();

        return response()->json(['success' => true, 'message' => 'Meeting deleted.']);
    }
}
