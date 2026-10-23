<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class VideoMeeting extends Model
{
    protected $table = 'video_meetings';

    protected $fillable = [
        'class_id', 'host_id', 'title', 'room_id', 'scheduled_at',
        'started_at', 'ended_at', 'status', 'is_recorded', 'recording_url',
        'participant_count',
    ];

    protected $casts = [
        'scheduled_at' => 'datetime',
        'started_at' => 'datetime',
        'ended_at' => 'datetime',
        'is_recorded' => 'boolean',
    ];

    public function schoolClass()
    {
        return $this->belongsTo(SchoolClass::class, 'class_id');
    }

    public function host()
    {
        return $this->belongsTo(User::class, 'host_id');
    }

    public static function generateUniqueRoomId(): string
    {
        do {
            $room = 'edulink-' . Str::lower(Str::random(10));
        } while (self::where('room_id', $room)->exists());

        return $room;
    }
}
