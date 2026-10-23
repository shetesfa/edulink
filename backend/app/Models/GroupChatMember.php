<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class GroupChatMember extends Model
{
    protected $fillable = ['group_id', 'user_id', 'role', 'joined_at', 'last_read_at', 'is_muted'];

    protected $casts = [
        'joined_at' => 'datetime',
        'last_read_at' => 'datetime',
        'is_muted' => 'boolean',
    ];

    public function group()
    {
        return $this->belongsTo(GroupChat::class, 'group_id');
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
