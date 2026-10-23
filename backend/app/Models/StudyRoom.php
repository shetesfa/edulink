<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class StudyRoom extends Model
{
    use HasFactory;

    protected $fillable = [
        'creator_id',
        'name',
        'subject',
        'description',
        'join_code',
        'is_public',
        'is_active',
        'linked_lesson_id',
    ];

    public function creator()
    {
        return $this->belongsTo(User::class, 'creator_id');
    }

    public function lesson()
    {
        return $this->belongsTo(Lesson::class, 'linked_lesson_id');
    }

    public function members()
    {
        return $this->hasMany(StudyRoomMember::class);
    }

    public function messages()
    {
        return $this->hasMany(StudyRoomMessage::class);
    }
}
