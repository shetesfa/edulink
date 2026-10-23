<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class StudyRoomMember extends Model
{
    use HasFactory;

    protected $fillable = [
        'study_room_id',
        'user_id',
        'role',
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
