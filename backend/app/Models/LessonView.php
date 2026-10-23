<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class LessonView extends Model
{
    public $timestamps = false;
    protected $fillable = ['lesson_id', 'user_id', 'viewed_at'];
    protected $casts = ['viewed_at' => 'datetime'];

    public function lesson()
    {
        return $this->belongsTo(Lesson::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
