<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\StudyRoom;
use App\Models\StudyRoomMember;
use App\Models\StudyRoomMessage;
use App\Services\AiRouterService;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class StudyRoomController extends Controller
{
    public function index(Request $request)
    {
        $userId = $request->user()->id;

        $publicRooms = StudyRoom::where('is_public', true)
            ->where('is_active', true)
            ->withCount('members')
            ->get();

        $joinedRooms = StudyRoom::whereHas('members', function ($q) use ($userId) {
            $q->where('user_id', $userId);
        })
        ->withCount('members')
        ->get();

        return response()->json([
            'success' => true,
            'data' => [
                'public_rooms' => $publicRooms,
                'joined_rooms' => $joinedRooms
            ]
        ]);
    }

    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:200',
            'subject' => 'nullable|string|max:100',
            'description' => 'nullable|string',
            'is_public' => 'boolean',
        ]);

        $room = StudyRoom::create([
            'creator_id' => $request->user()->id,
            'name' => $request->name,
            'subject' => $request->subject,
            'description' => $request->description,
            'is_public' => $request->is_public ?? true,
            'join_code' => Str::upper(Str::random(6)),
        ]);

        StudyRoomMember::create([
            'study_room_id' => $room->id,
            'user_id' => $request->user()->id,
            'role' => 'moderator',
        ]);

        return response()->json([
            'success' => true,
            'data' => $room
        ]);
    }

    public function show($id)
    {
        $room = StudyRoom::with(['members.user'])->findOrFail($id);
        return response()->json([
            'success' => true,
            'data' => $room
        ]);
    }

    public function join(Request $request)
    {
        $request->validate([
            'join_code' => 'required|string',
        ]);

        $room = StudyRoom::where('join_code', $request->join_code)->firstOrFail();

        $existing = StudyRoomMember::where('study_room_id', $room->id)
            ->where('user_id', $request->user()->id)
            ->first();

        if (!$existing) {
            StudyRoomMember::create([
                'study_room_id' => $room->id,
                'user_id' => $request->user()->id,
                'role' => 'member',
            ]);
        }

        return response()->json([
            'success' => true,
            'data' => $room
        ]);
    }

    public function leave(Request $request, $id)
    {
        $room = StudyRoom::findOrFail($id);
        
        StudyRoomMember::where('study_room_id', $room->id)
            ->where('user_id', $request->user()->id)
            ->delete();

        return response()->json([
            'success' => true,
            'data' => null
        ]);
    }

    public function messages($id)
    {
        $messages = StudyRoomMessage::where('study_room_id', $id)
            ->with('user')
            ->orderBy('created_at', 'desc')
            ->paginate(50);

        return response()->json([
            'success' => true,
            'data' => $messages
        ]);
    }

    public function sendMessage(Request $request, $id)
    {
        $request->validate([
            'body' => 'required|string',
        ]);

        $room = StudyRoom::findOrFail($id);

        $message = StudyRoomMessage::create([
            'study_room_id' => $room->id,
            'user_id' => $request->user()->id,
            'body' => $request->body,
        ]);

        $aiResponse = null;
        if (str_contains(strtolower($request->body), '@edulink ')) {
            $question = trim(str_ireplace('@edulink ', '', $request->body));
            if ($question) {
                $aiRouter = new AiRouterService();
                $response = $aiRouter->ask($question);
                
                $aiResponse = StudyRoomMessage::create([
                    'study_room_id' => $room->id,
                    'user_id' => $request->user()->id, // Using user_id, assuming there's no system user or it's allowed. If needed, we can make it nullable. But migration says cascadeOnDelete constrained. I'll use the user's ID but is_ai_response = true.
                    'body' => $response['response'] ?? 'Sorry, I could not generate a response.',
                    'is_ai_response' => true,
                ]);
            }
        }

        return response()->json([
            'success' => true,
            'data' => [
                'message' => $message,
                'ai_response' => $aiResponse
            ]
        ]);
    }
}
