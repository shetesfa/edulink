<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class UserSetting extends Model
{
    protected $fillable = [
        'user_id', 'dark_mode', 'language', 'notifications_enabled',
        'email_notifications', 'sound_enabled', 'show_online_status',
        'allow_messages_from', 'theme', 'font_size',
    ];

    protected $casts = [
        'dark_mode' => 'boolean',
        'notifications_enabled' => 'boolean',
        'email_notifications' => 'boolean',
        'sound_enabled' => 'boolean',
        'show_online_status' => 'boolean',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
