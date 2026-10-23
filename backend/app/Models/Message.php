<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Message extends Model
{
    protected $fillable = [
        'sender_id', 'receiver_id', 'group_id', 'reply_to_id', 'forwarded_from_id',
        'message_type', 'body', 'is_edited', 'is_deleted', 'is_pinned',
        'reactions', 'metadata', 'client_message_id',
    ];

    protected $casts = [
        'is_edited' => 'boolean',
        'is_deleted' => 'boolean',
        'is_pinned' => 'boolean',
        'reactions' => 'array',
        'metadata' => 'array',
    ];

    public function sender()
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    public function receiver()
    {
        return $this->belongsTo(User::class, 'receiver_id');
    }

    public function group()
    {
        return $this->belongsTo(GroupChat::class, 'group_id');
    }

    public function replyTo()
    {
        return $this->belongsTo(Message::class, 'reply_to_id');
    }

    public function forwardedFrom()
    {
        return $this->belongsTo(Message::class, 'forwarded_from_id');
    }

    public function files()
    {
        return $this->hasMany(FileUpload::class, 'related_id')->where('related_type', 'message');
    }

    public function reads()
    {
        return $this->hasMany(MessageRead::class);
    }

    public function toggleReaction(int $userId, string $emoji): array
    {
        $reactions = $this->reactions ?? [];
        $users = $reactions[$emoji] ?? [];

        if (in_array($userId, $users)) {
            $users = array_values(array_diff($users, [$userId]));
        } else {
            $users[] = $userId;
        }

        if (empty($users)) {
            unset($reactions[$emoji]);
        } else {
            $reactions[$emoji] = $users;
        }

        $this->reactions = $reactions;
        $this->save();

        return $reactions;
    }
}
