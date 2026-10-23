<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Chat\SendMessageRequest;
use App\Http\Requests\Chat\CreateGroupRequest;
use App\Http\Requests\Chat\JoinGroupRequest;
use App\Models\User;
use App\Models\Message;
use App\Models\MessageRead;
use App\Models\GroupChat;
use App\Models\GroupChatMember;
use App\Services\ChatService;
use App\Events\MessageUpdated;
use App\Events\UserTyping;
use Illuminate\Http\Request;

class ChatController extends Controller
{
    public function __construct(private ChatService $chatService) {}

    /**
     * GET /api/chat/conversations
     * Lists private conversations + groups the user belongs to, each with
     * the last message and unread count - everything a chat list screen needs.
     */
    public function conversations(Request $request)
    {
        $userId = $request->user()->id;

        // Private: distinct set of people this user has exchanged messages with
        $partnerIds = Message::where(function ($q) use ($userId) {
                $q->where('sender_id', $userId)->orWhere('receiver_id', $userId);
            })
            ->whereNotNull('receiver_id')
            ->get(['sender_id', 'receiver_id'])
            ->flatMap(fn ($m) => [$m->sender_id, $m->receiver_id])
            ->unique()
            ->reject(fn ($id) => $id == $userId)
            ->values();

        $privateConversations = User::whereIn('id', $partnerIds)->get()->map(function ($partner) use ($userId) {
            $lastMessage = Message::where(function ($q) use ($userId, $partner) {
                    $q->where('sender_id', $userId)->where('receiver_id', $partner->id);
                })->orWhere(function ($q) use ($userId, $partner) {
                    $q->where('sender_id', $partner->id)->where('receiver_id', $userId);
                })->latest()->first();

            $unread = Message::where('sender_id', $partner->id)
                ->where('receiver_id', $userId)
                ->whereDoesntHave('reads', fn ($q) => $q->where('user_id', $userId))
                ->count();

            return [
                'type' => 'private',
                'user' => $partner,
                'last_message' => $lastMessage,
                'unread_count' => $unread,
            ];
        });

        $groups = $request->user()->belongsToMany(GroupChat::class, 'group_chat_members', 'user_id', 'group_id')
            ->withPivot('last_read_at')->get()
            ->map(function ($group) use ($userId) {
                $lastMessage = $group->messages()->latest()->first();
                $unread = $group->messages()
                    ->when($group->pivot->last_read_at, fn ($q) => $q->where('created_at', '>', $group->pivot->last_read_at))
                    ->count();

                return [
                    'type' => 'group',
                    'group' => $group,
                    'last_message' => $lastMessage,
                    'unread_count' => $unread,
                ];
            });

        $all = $privateConversations->concat($groups)->sortByDesc(function ($c) {
            return $c['last_message']->created_at ?? now()->subYears(10);
        })->values();

        return response()->json(['success' => true, 'data' => ['conversations' => $all]]);
    }

    /**
     * GET /api/chat/private/{userId}
     * Supports incremental/offline sync via ?since=2026-07-20T10:00:00Z
     */
    public function privateHistory(Request $request, int $userId)
    {
        $me = $request->user()->id;

        $query = Message::where(function ($q) use ($me, $userId) {
                $q->where('sender_id', $me)->where('receiver_id', $userId);
            })->orWhere(function ($q) use ($me, $userId) {
                $q->where('sender_id', $userId)->where('receiver_id', $me);
            })
            ->where('is_deleted', false)
            ->with('sender', 'replyTo', 'files')
            ->orderBy('created_at');

        if ($request->filled('since')) {
            $query->where('created_at', '>', $request->since);
        }

        $messages = $query->paginate(50);

        return response()->json(['success' => true, 'data' => ['messages' => $messages]]);
    }

    /**
     * POST /api/chat/private/{userId}
     */
    public function sendPrivate(SendMessageRequest $request, int $userId)
    {
        $message = $this->chatService->send($request, $request->user()->id, $userId, null);

        return response()->json(['success' => true, 'message' => 'Message sent.', 'data' => ['message' => $message]], 201);
    }

    /**
     * POST /api/chat/groups
     */
    public function createGroup(CreateGroupRequest $request)
    {
        $group = GroupChat::create([
            'name' => $request->name,
            'description' => $request->description,
            'type' => 'custom',
            'created_by' => $request->user()->id,
            'is_public' => $request->boolean('is_public'),
            'join_code' => GroupChat::generateUniqueJoinCode(),
        ]);

        GroupChatMember::create(['group_id' => $group->id, 'user_id' => $request->user()->id, 'role' => 'owner']);

        foreach ($request->input('member_ids', []) as $memberId) {
            if ($memberId != $request->user()->id) {
                GroupChatMember::firstOrCreate(['group_id' => $group->id, 'user_id' => $memberId]);
            }
        }

        return response()->json(['success' => true, 'message' => 'Group created.', 'data' => ['group' => $group->load('members')]], 201);
    }

    /**
     * POST /api/chat/groups/join
     */
    public function joinGroup(JoinGroupRequest $request)
    {
        $group = GroupChat::where('join_code', $request->join_code)->firstOrFail();

        $existing = GroupChatMember::where('group_id', $group->id)->where('user_id', $request->user()->id)->first();
        if ($existing) {
            return response()->json(['success' => false, 'message' => 'You already joined this group.'], 422);
        }

        GroupChatMember::create(['group_id' => $group->id, 'user_id' => $request->user()->id]);

        return response()->json(['success' => true, 'message' => "Joined \"{$group->name}\".", 'data' => ['group' => $group]]);
    }

    /**
     * POST /api/chat/groups/{group}/leave
     */
    public function leaveGroup(Request $request, GroupChat $group)
    {
        GroupChatMember::where('group_id', $group->id)->where('user_id', $request->user()->id)->delete();

        return response()->json(['success' => true, 'message' => 'Left the group.']);
    }

    /**
     * GET /api/chat/groups/{group}/messages
     */
    public function groupHistory(Request $request, GroupChat $group)
    {
        $this->ensureMember($request, $group);

        $query = $group->messages()->where('is_deleted', false)->with('sender', 'replyTo', 'files')->orderBy('created_at');

        if ($request->filled('since')) {
            $query->where('created_at', '>', $request->since);
        }

        return response()->json(['success' => true, 'data' => ['messages' => $query->paginate(50)]]);
    }

    /**
     * POST /api/chat/groups/{group}/messages
     */
    public function sendGroupMessage(SendMessageRequest $request, GroupChat $group)
    {
        $this->ensureMember($request, $group);

        $message = $this->chatService->send($request, $request->user()->id, null, $group->id);

        return response()->json(['success' => true, 'message' => 'Message sent.', 'data' => ['message' => $message]], 201);
    }

    /**
     * PUT /api/chat/messages/{message}  (edit - author only)
     */
    public function editMessage(Request $request, Message $message)
    {
        if ($message->sender_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'You can only edit your own messages.'], 403);
        }

        $request->validate(['body' => ['required', 'string', 'max:5000']]);

        $message->update(['body' => $request->body, 'is_edited' => true]);
        broadcast(new MessageUpdated($message))->toOthers();

        return response()->json(['success' => true, 'message' => 'Message edited.', 'data' => ['message' => $message]]);
    }

    /**
     * DELETE /api/chat/messages/{message}  (soft delete - author only)
     */
    public function deleteMessage(Request $request, Message $message)
    {
        if ($message->sender_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'You can only delete your own messages.'], 403);
        }

        $message->update(['is_deleted' => true, 'body' => null]);
        broadcast(new MessageUpdated($message))->toOthers();

        return response()->json(['success' => true, 'message' => 'Message deleted.']);
    }

    /**
     * POST /api/chat/messages/{message}/pin  (toggle)
     */
    public function togglePin(Request $request, Message $message)
    {
        $message->update(['is_pinned' => !$message->is_pinned]);
        broadcast(new MessageUpdated($message))->toOthers();

        return response()->json(['success' => true, 'data' => ['is_pinned' => $message->is_pinned]]);
    }

    /**
     * POST /api/chat/messages/{message}/react
     */
    public function react(Request $request, Message $message)
    {
        $request->validate(['emoji' => ['required', 'string', 'max:8']]);

        $reactions = $message->toggleReaction($request->user()->id, $request->emoji);
        broadcast(new MessageUpdated($message))->toOthers();

        return response()->json(['success' => true, 'data' => ['reactions' => $reactions]]);
    }

    /**
     * POST /api/chat/messages/{message}/forward
     */
    public function forward(Request $request, Message $message)
    {
        $request->validate([
            'receiver_id' => ['required_without:group_id', 'nullable', 'exists:users,id'],
            'group_id' => ['required_without:receiver_id', 'nullable', 'exists:group_chats,id'],
            'client_message_id' => ['required', 'string', 'max:64'],
        ]);

        $forwarded = Message::create([
            'sender_id' => $request->user()->id,
            'receiver_id' => $request->receiver_id,
            'group_id' => $request->group_id,
            'forwarded_from_id' => $message->id,
            'message_type' => $message->message_type,
            'body' => $message->body,
            'client_message_id' => $request->client_message_id,
        ]);

        broadcast(new \App\Events\MessageSent($forwarded))->toOthers();

        return response()->json(['success' => true, 'message' => 'Message forwarded.', 'data' => ['message' => $forwarded]], 201);
    }

    /**
     * GET /api/chat/search?query=...
     */
    public function search(Request $request)
    {
        $request->validate(['query' => ['required', 'string', 'min:2']]);
        $userId = $request->user()->id;

        $messages = Message::where('is_deleted', false)
            ->where('body', 'like', '%' . $request->query . '%')
            ->where(function ($q) use ($userId) {
                $q->where('sender_id', $userId)
                  ->orWhere('receiver_id', $userId)
                  ->orWhereIn('group_id', GroupChat::whereHas('members', fn ($m) => $m->where('users.id', $userId))->pluck('id'));
            })
            ->with('sender')
            ->latest()
            ->limit(50)
            ->get();

        return response()->json(['success' => true, 'data' => ['messages' => $messages]]);
    }

    /**
     * POST /api/chat/groups/{group}/read  or  /api/chat/private/{userId}/read
     * Marks messages as read up to now.
     */
    public function markGroupRead(Request $request, GroupChat $group)
    {
        $this->ensureMember($request, $group);

        GroupChatMember::where('group_id', $group->id)->where('user_id', $request->user()->id)
            ->update(['last_read_at' => now()]);

        return response()->json(['success' => true, 'message' => 'Marked as read.']);
    }

    public function markPrivateRead(Request $request, int $userId)
    {
        $unread = Message::where('sender_id', $userId)->where('receiver_id', $request->user()->id)
            ->whereDoesntHave('reads', fn ($q) => $q->where('user_id', $request->user()->id))
            ->get();

        foreach ($unread as $message) {
            MessageRead::firstOrCreate(['message_id' => $message->id, 'user_id' => $request->user()->id], ['read_at' => now()]);
        }

        return response()->json(['success' => true, 'message' => 'Marked as read.']);
    }

    /**
     * POST /api/chat/typing  - lightweight, not persisted, just broadcast
     */
    public function typing(Request $request)
    {
        $request->validate([
            'receiver_id' => ['nullable', 'exists:users,id'],
            'group_id' => ['nullable', 'exists:group_chats,id'],
        ]);

        broadcast(new UserTyping(
            $request->user()->id,
            $request->user()->fullName(),
            $request->receiver_id,
            $request->group_id,
        ))->toOthers();

        return response()->json(['success' => true]);
    }

    /**
     * GET /api/chat/groups/{group}/members
     */
    public function groupMembers(Request $request, GroupChat $group)
    {
        $this->ensureMember($request, $group);

        return response()->json(['success' => true, 'data' => ['members' => $group->members()->get()]]);
    }

    /**
     * POST /api/chat/groups/{group}/members  (owner/admin only)
     */
    public function addGroupMember(Request $request, GroupChat $group)
    {
        $this->ensureGroupAdmin($request, $group);

        $request->validate(['user_id' => ['required', 'exists:users,id']]);

        GroupChatMember::firstOrCreate(['group_id' => $group->id, 'user_id' => $request->user_id]);

        return response()->json(['success' => true, 'message' => 'Member added.']);
    }

    /**
     * DELETE /api/chat/groups/{group}/members/{userId}  (owner/admin only)
     */
    public function removeGroupMember(Request $request, GroupChat $group, int $userId)
    {
        $this->ensureGroupAdmin($request, $group);

        GroupChatMember::where('group_id', $group->id)->where('user_id', $userId)->delete();

        return response()->json(['success' => true, 'message' => 'Member removed.']);
    }

    private function ensureGroupAdmin(Request $request, GroupChat $group): void
    {
        $membership = GroupChatMember::where('group_id', $group->id)->where('user_id', $request->user()->id)->first();
        abort_if(!$membership || !in_array($membership->role, ['owner', 'admin']), 403, 'Only group admins can manage members.');
    }

    private function ensureMember(Request $request, GroupChat $group): void
    {
        abort_unless(
            $group->members()->where('users.id', $request->user()->id)->exists(),
            403,
            'You are not a member of this group.'
        );
    }
}
