<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

class Quiz extends Model
{
    protected $fillable = [
        'class_id', 'teacher_id', 'title', 'description', 'time_limit_minutes',
        'max_attempts', 'shuffle_questions', 'show_answers_after', 'pass_score',
        'is_published', 'opens_at', 'closes_at',
    ];

    protected $casts = [
        'shuffle_questions' => 'boolean',
        'show_answers_after' => 'boolean',
        'is_published' => 'boolean',
        'opens_at' => 'datetime',
        'closes_at' => 'datetime',
        'pass_score' => 'decimal:2',
    ];

    public function schoolClass()
    {
        return $this->belongsTo(SchoolClass::class, 'class_id');
    }

    public function teacher()
    {
        return $this->belongsTo(User::class, 'teacher_id');
    }

    public function questions()
    {
        return $this->hasMany(QuizQuestion::class)->orderBy('order_index');
    }

    public function attempts()
    {
        return $this->hasMany(QuizAttempt::class);
    }

    public function isOpen(): bool
    {
        $now = Carbon::now();
        if ($this->opens_at && $now->lessThan($this->opens_at)) return false;
        if ($this->closes_at && $now->greaterThan($this->closes_at)) return false;
        return true;
    }

    public function totalPoints(): float
    {
        return (float) $this->questions()->sum('points');
    }
}
