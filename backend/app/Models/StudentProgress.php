<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class StudentProgress extends Model
{
    protected $table = 'student_progress';

    protected $fillable = [
        'student_id', 'class_id', 'lessons_viewed', 'lessons_total',
        'assignments_submitted', 'assignments_total', 'avg_quiz_score',
        'quizzes_taken', 'last_activity',
    ];

    protected $casts = [
        'last_activity' => 'datetime',
        'avg_quiz_score' => 'decimal:2',
    ];

    public function student()
    {
        return $this->belongsTo(User::class, 'student_id');
    }

    public function schoolClass()
    {
        return $this->belongsTo(SchoolClass::class, 'class_id');
    }

    public function completionPercent(): int
    {
        $totalItems = $this->lessons_total + $this->assignments_total;
        $doneItems = $this->lessons_viewed + $this->assignments_submitted;

        return $totalItems > 0 ? (int) round(($doneItems / $totalItems) * 100) : 0;
    }
}
