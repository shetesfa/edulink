<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class StudyRoomMessage extends Model
{
    use HasFactory;

    protected $fillable = [
        'study_room_id',
        'user_id',
        'body',
        'is_ai_response',
    ];

    public function studyRoom()
    {
        return $this->belongsTo(StudyRoom::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
