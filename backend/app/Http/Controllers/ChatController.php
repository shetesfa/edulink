<?php

namespace App\Http\Controllers;

use App\Models\Message;
use App\Models\GroupChat;
use App\Models\GroupChatMember;
use App\Models\User;
use App\Models\File;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ChatController extends Controller
{
    // ─── Conversations list ───────────────────────────────────────
    public function conversations(Request $request): JsonResponse
    {
        $user = $request->user();

        // Get all users this person has chatted with
        $conversations = Message::where(function ($q) use ($user) {
                $q->where('sender_id', $user->id)->orWhere('receiver_id', $user->id);
            })
            ->whereNotNull('receiver_id')
            ->whereNull('group_id')
            ->select('sender_id', 'receiver_id')
            ->distinct()
            ->get()
            ->map(function ($msg) use ($user) {
                $otherId = $msg->sender_id === $user->id ? $msg->receiver_id : $msg->sender_id;
                return $otherId;
            })
            ->unique()
            ->values();

        $users = User::whereIn('id', $conversations)->get()->map(function ($u) use ($user) {
            $last = Message::where(function ($q) use ($user, $u) {
                    $q->where('sender_id', $user->id)->where('receiver_id', $u->id);
                })->orWhere(function ($q) use ($user, $u) {
                    $q->where('sender_id', $u->id)->where('receiver_id', $user->id);
                })
                ->latest()
                ->first();

            return [
                'id'              => $u->id,
                'full_name'       => $u->first_name . ' ' . $u->last_name,
                'profile_photo'   => $u->profile_photo ? Storage::disk('public')->url($u->profile_photo) : null,
                'is_online'       => (bool) $u->is_online,
                'last_seen'       => $u->last_seen?->toISOString(),
                'last_message'    => $last?->is_deleted ? 'Message deleted' : $last?->body,
                'last_message_at' => $last?->created_at->toISOString(),
                'type'            => 'private',
            ];
        });

        return response()->json(['success' => true, 'conversations' => $users]);
    }

    // ─── Private messages ─────────────────────────────────────────
    public function privateMessages(Request $request, int $userId): JsonResponse
    {
        $user = $request->user();
        $page = $request->get('page', 1);

        $messages = Message::where(function ($q) use ($user, $userId) {
                $q->where('sender_id', $user->id)->where('receiver_id', $userId);
            })
            ->orWhere(function ($q) use ($user, $userId) {
                $q->where('sender_id', $userId)->where('receiver_id', $user->id);
            })
            ->whereNull('group_id')
            ->with(['sender', 'replyTo.sender', 'files'])
            ->orderBy('created_at', 'desc')
            ->paginate(50, ['*'], 'page', $page);

        return response()->json([
            'success'  => true,
            'messages' => $messages->items() ? array_map([$this, 'formatMessage'], array_reverse($messages->items())) : [],
            'has_more' => $messages->hasMorePages(),
            'total'    => $messages->total(),
        ]);
    }

    // ─── Send private message ─────────────────────────────────────
    public function sendPrivate(Request $request, int $userId): JsonResponse
    {
        $request->validate([
            'body'         => 'nullable|string|max:10000',
            'type'         => 'in:text,image,video,audio,file,voice',
            'reply_to_id'  => 'nullable|exists:messages,id',
            'file_id'      => 'nullable|exists:files,id',
        ]);

        $sender   = $request->user();
        $receiver = User::findOrFail($userId);

        $message = Message::create([
            'sender_id'    => $sender->id,
            'receiver_id'  => $receiver->id,
            'message_type' => $request->type ?? 'text',
            'body'         => $request->body,
            'reply_to_id'  => $request->reply_to_id,
        ]);

        if ($request->file_id) {
            File::where('id', $request->file_id)->update(['related_type' => 'message', 'related_id' => $message->id]);
        }

        return response()->json(['success' => true, 'message' => $this->formatMessage($message->load(['sender', 'replyTo', 'files']))]);
    }

    // ─── Group chats list ─────────────────────────────────────────
    public function groups(Request $request): JsonResponse
    {
        $user   = $request->user();
        $groups = GroupChat::whereHas('members', fn($q) => $q->where('user_id', $user->id))
            ->with(['lastMessage.sender'])
            ->withCount('members')
            ->get()
            ->map(function ($g) use ($user) {
                $member = $g->members()->where('user_id', $user->id)->first();
                $last   = $g->lastMessage;
                return [
                    'id'              => $g->id,
                    'name'            => $g->name,
                    'description'     => $g->description,
                    'avatar'          => $g->avatar ? Storage::disk('public')->url($g->avatar) : null,
                    'type'            => $g->type,
                    'class_id'        => $g->class_id,
                    'join_code'       => $g->join_code,
                    'members_count'   => $g->members_count,
                    'my_role'         => $member?->pivot->role ?? 'member',
                    'is_muted'        => (bool) $member?->pivot->is_muted,
                    'last_message'    => $last ? ($last->is_deleted ? 'Message deleted' : ($last->sender?->first_name . ': ' . $last->body)) : null,
                    'last_message_at' => $last?->created_at?->toISOString(),
                    'type_chat'       => 'group',
                ];
            });

        return response()->json(['success' => true, 'groups' => $groups]);
    }

    // ─── Group messages ───────────────────────────────────────────
    public function groupMessages(Request $request, int $groupId): JsonResponse
    {
        $user  = $request->user();
        $page  = $request->get('page', 1);

        // Verify membership
        $isMember = GroupChatMember::where('group_id', $groupId)->where('user_id', $user->id)->exists();
        if (!$isMember) return response()->json(['success' => false, 'message' => 'Not a member of this group'], 403);

        $messages = Message::where('group_id', $groupId)
            ->with(['sender', 'replyTo.sender', 'files'])
            ->orderBy('created_at', 'desc')
            ->paginate(50, ['*'], 'page', $page);

        // Update last read
        GroupChatMember::where('group_id', $groupId)->where('user_id', $user->id)
            ->update(['last_read_at' => now()]);

        return response()->json([
            'success'  => true,
            'messages' => $messages->items() ? array_map([$this, 'formatMessage'], array_reverse($messages->items())) : [],
            'has_more' => $messages->hasMorePages(),
        ]);
    }

    // ─── Send group message ───────────────────────────────────────
    public function sendGroup(Request $request, int $groupId): JsonResponse
    {
        $request->validate([
            'body'        => 'nullable|string|max:10000',
            'type'        => 'in:text,image,video,audio,file,voice',
            'reply_to_id' => 'nullable|exists:messages,id',
            'file_id'     => 'nullable|exists:files,id',
        ]);

        $user     = $request->user();
        $isMember = GroupChatMember::where('group_id', $groupId)->where('user_id', $user->id)->exists();
        if (!$isMember) return response()->json(['success' => false, 'message' => 'Not a member'], 403);

        $message = Message::create([
            'sender_id'    => $user->id,
            'group_id'     => $groupId,
            'message_type' => $request->type ?? 'text',
            'body'         => $request->body,
            'reply_to_id'  => $request->reply_to_id,
        ]);

        if ($request->file_id) {
            File::where('id', $request->file_id)->update(['related_type' => 'message', 'related_id' => $message->id]);
        }

        return response()->json(['success' => true, 'message' => $this->formatMessage($message->load(['sender', 'replyTo', 'files']))]);
    }

    // ─── Create group ─────────────────────────────────────────────
    public function createGroup(Request $request): JsonResponse
    {
        $request->validate([
            'name'        => 'required|string|max:200',
            'description' => 'nullable|string|max:500',
            'avatar'      => 'nullable|image|max:5120',
            'member_ids'  => 'nullable|array',
            'member_ids.*'=> 'exists:users,id',
            'is_public'   => 'boolean',
        ]);

        $user  = $request->user();
        $group = GroupChat::create([
            'name'        => $request->name,
            'description' => $request->description,
            'type'        => 'custom',
            'created_by'  => $user->id,
            'join_code'   => strtoupper(Str::random(8)),
            'invite_link' => Str::random(32),
            'is_public'   => $request->is_public ?? false,
        ]);

        if ($request->hasFile('avatar')) {
            $path = $request->file('avatar')->store("group-avatars/{$group->id}", 'public');
            $group->update(['avatar' => $path]);
        }

        // Add creator as owner
        GroupChatMember::create(['group_id' => $group->id, 'user_id' => $user->id, 'role' => 'owner']);

        // Add other members
        if ($request->member_ids) {
            foreach ($request->member_ids as $memberId) {
                if ($memberId !== $user->id) {
                    GroupChatMember::create(['group_id' => $group->id, 'user_id' => $memberId, 'role' => 'member']);
                }
            }
        }

        return response()->json(['success' => true, 'group' => $group->load('members')], 201);
    }

    // ─── Join group by code ───────────────────────────────────────
    public function joinGroup(Request $request): JsonResponse
    {
        $request->validate(['join_code' => 'required|string']);
        $user  = $request->user();
        $group = GroupChat::where('join_code', strtoupper($request->join_code))
            ->orWhere('invite_link', $request->join_code)->firstOrFail();

        $exists = GroupChatMember::where('group_id', $group->id)->where('user_id', $user->id)->exists();
        if ($exists) return response()->json(['success' => false, 'message' => 'Already a member'], 409);

        GroupChatMember::create(['group_id' => $group->id, 'user_id' => $user->id, 'role' => 'member']);
        return response()->json(['success' => true, 'message' => "Joined {$group->name}!", 'group' => $group]);
    }

    // ─── Update group ─────────────────────────────────────────────
    public function updateGroup(Request $request, int $groupId): JsonResponse
    {
        $user   = $request->user();
        $group  = GroupChat::findOrFail($groupId);
        $member = GroupChatMember::where('group_id', $groupId)->where('user_id', $user->id)->firstOrFail();

        if (!in_array($member->role, ['admin', 'owner'])) {
            return response()->json(['success' => false, 'message' => 'Only admins can edit the group'], 403);
        }

        $request->validate([
            'name'        => 'sometimes|string|max:200',
            'description' => 'nullable|string|max:500',
            'avatar'      => 'nullable|image|max:5120',
        ]);

        if ($request->hasFile('avatar')) {
            if ($group->avatar) Storage::disk('public')->delete($group->avatar);
            $group->avatar = $request->file('avatar')->store("group-avatars/{$group->id}", 'public');
        }

        $group->fill($request->only(['name', 'description']))->save();
        return response()->json(['success' => true, 'group' => $group]);
    }

    // ─── Leave group ──────────────────────────────────────────────
    public function leaveGroup(Request $request, int $groupId): JsonResponse
    {
        $user = $request->user();
        GroupChatMember::where('group_id', $groupId)->where('user_id', $user->id)->delete();
        return response()->json(['success' => true, 'message' => 'Left the group.']);
    }

    // ─── Add member ───────────────────────────────────────────────
    public function addMember(Request $request, int $groupId): JsonResponse
    {
        $request->validate(['user_id' => 'required|exists:users,id']);
        $exists = GroupChatMember::where('group_id', $groupId)->where('user_id', $request->user_id)->exists();
        if ($exists) return response()->json(['success' => false, 'message' => 'Already a member'], 409);
        GroupChatMember::create(['group_id' => $groupId, 'user_id' => $request->user_id, 'role' => 'member']);
        return response()->json(['success' => true, 'message' => 'Member added.']);
    }

    // ─── Remove member ────────────────────────────────────────────
    public function removeMember(Request $request, int $groupId, int $userId): JsonResponse
    {
        $user   = $request->user();
        $member = GroupChatMember::where('group_id', $groupId)->where('user_id', $user->id)->firstOrFail();
        if (!in_array($member->role, ['admin','owner'])) return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        GroupChatMember::where('group_id', $groupId)->where('user_id', $userId)->delete();
        return response()->json(['success' => true, 'message' => 'Member removed.']);
    }

    // ─── Edit message ─────────────────────────────────────────────
    public function editMessage(Request $request, int $id): JsonResponse
    {
        $request->validate(['body' => 'required|string|max:10000']);
        $message = Message::findOrFail($id);
        if ($message->sender_id !== $request->user()->id) return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        $message->update(['body' => $request->body, 'is_edited' => true]);
        return response()->json(['success' => true]);
    }

    // ─── Delete message ───────────────────────────────────────────
    public function deleteMessage(Request $request, int $id): JsonResponse
    {
        $message = Message::findOrFail($id);
        if ($message->sender_id !== $request->user()->id) return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        $message->update(['is_deleted' => true, 'body' => null]);
        return response()->json(['success' => true]);
    }

    // ─── React to message ─────────────────────────────────────────
    public function reactToMessage(Request $request, int $id): JsonResponse
    {
        $request->validate(['emoji' => 'required|string|max:10']);
        $user    = $request->user();
        $message = Message::findOrFail($id);
        $reactions = $message->reactions ? json_decode($message->reactions, true) : [];
        $emoji   = $request->emoji;

        if (!isset($reactions[$emoji])) $reactions[$emoji] = [];

        if (in_array($user->id, $reactions[$emoji])) {
            $reactions[$emoji] = array_filter($reactions[$emoji], fn($uid) => $uid !== $user->id);
        } else {
            $reactions[$emoji][] = $user->id;
        }

        $reactions[$emoji] = array_values($reactions[$emoji]);
        if (empty($reactions[$emoji])) unset($reactions[$emoji]);

        $message->update(['reactions' => json_encode($reactions)]);
        return response()->json(['success' => true, 'reactions' => $reactions]);
    }

    // ─── Pin message ──────────────────────────────────────────────
    public function pinMessage(Request $request, int $id): JsonResponse
    {
        $message = Message::findOrFail($id);
        $message->update(['is_pinned' => !$message->is_pinned]);
        return response()->json(['success' => true, 'pinned' => (bool) $message->is_pinned]);
    }

    // ─── Forward message ──────────────────────────────────────────
    public function forwardMessage(Request $request, int $id): JsonResponse
    {
        $request->validate([
            'receiver_id' => 'nullable|exists:users,id',
            'group_id'    => 'nullable|exists:group_chats,id',
        ]);

        $original = Message::findOrFail($id);
        $user     = $request->user();

        $forwarded = Message::create([
            'sender_id'          => $user->id,
            'receiver_id'        => $request->receiver_id,
            'group_id'           => $request->group_id,
            'message_type'       => $original->message_type,
            'body'               => $original->body,
            'forwarded_from_id'  => $original->id,
        ]);

        return response()->json(['success' => true, 'message' => $this->formatMessage($forwarded->load('sender'))]);
    }

    // ─── Mark as read ─────────────────────────────────────────────
    public function markRead(Request $request, int $id): JsonResponse
    {
        $user    = $request->user();
        $message = Message::findOrFail($id);
        \DB::table('message_reads')->updateOrInsert(
            ['message_id' => $id, 'user_id' => $user->id],
            ['read_at' => now()]
        );
        return response()->json(['success' => true]);
    }

    // ─── Search messages ──────────────────────────────────────────
    public function searchMessages(Request $request): JsonResponse
    {
        $request->validate(['q' => 'required|string|min:2|max:100']);
        $user = $request->user();

        $results = Message::where('body', 'LIKE', "%{$request->q}%")
            ->where('is_deleted', 0)
            ->where(function ($q) use ($user) {
                $q->where('sender_id', $user->id)
                  ->orWhere('receiver_id', $user->id)
                  ->orWhereHas('group.members', fn($m) => $m->where('user_id', $user->id));
            })
            ->with(['sender', 'group'])
            ->orderBy('created_at', 'desc')
            ->limit(50)
            ->get()
            ->map([$this, 'formatMessage']);

        return response()->json(['success' => true, 'results' => $results]);
    }

    // ─── Format helper ────────────────────────────────────────────
    public function formatMessage(Message $msg): array
    {
        return [
            'id'           => $msg->id,
            'sender_id'    => $msg->sender_id,
            'receiver_id'  => $msg->receiver_id,
            'group_id'     => $msg->group_id,
            'message_type' => $msg->message_type,
            'body'         => $msg->is_deleted ? null : $msg->body,
            'is_edited'    => (bool) $msg->is_edited,
            'is_deleted'   => (bool) $msg->is_deleted,
            'is_pinned'    => (bool) $msg->is_pinned,
            'reactions'    => $msg->reactions ? json_decode($msg->reactions, true) : [],
            'reply_to'     => $msg->replyTo ? [
                'id'          => $msg->replyTo->id,
                'body'        => $msg->replyTo->body,
                'sender_name' => $msg->replyTo->sender
                    ? $msg->replyTo->sender->first_name . ' ' . $msg->replyTo->sender->last_name
                    : 'Unknown',
            ] : null,
            'sender'       => $msg->sender ? [
                'id'     => $msg->sender->id,
                'name'   => $msg->sender->first_name . ' ' . $msg->sender->last_name,
                'avatar' => $msg->sender->profile_photo,
            ] : null,
            'files'        => $msg->files ? $msg->files->map(fn($f) => [
                'id'   => $f->id,
                'name' => $f->original_name,
                'type' => $f->file_type,
                'url'  => Storage::disk('public')->url($f->file_path),
                'size' => $f->file_size,
            ]) : [],
            'forwarded_from_id' => $msg->forwarded_from_id,
            'created_at'   => $msg->created_at->toISOString(),
            'updated_at'   => $msg->updated_at->toISOString(),
        ];
    }
}
