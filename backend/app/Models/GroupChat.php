<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class GroupChat extends Model
{
    protected $fillable = [
        'name', 'description', 'avatar', 'type', 'class_id', 'created_by',
        'invite_link', 'join_code', 'is_public',
    ];

    protected $casts = [
        'is_public' => 'boolean',
    ];

    public function schoolClass()
    {
        return $this->belongsTo(SchoolClass::class, 'class_id');
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function members()
    {
        return $this->belongsToMany(User::class, 'group_chat_members', 'group_id', 'user_id')
            ->withPivot(['role', 'joined_at', 'last_read_at', 'is_muted'])
            ->withTimestamps();
    }

    public function memberships()
    {
        return $this->hasMany(GroupChatMember::class, 'group_id');
    }

    public function messages()
    {
        return $this->hasMany(Message::class, 'group_id');
    }

    public static function generateUniqueJoinCode(): string
    {
        do {
            $code = strtoupper(Str::random(6));
        } while (self::where('join_code', $code)->exists());

        return $code;
    }
}
