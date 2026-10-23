<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class QuizQuestion extends Model
{
    protected $fillable = [
        'quiz_id', 'question_type', 'question_text', 'options',
        'correct_answer', 'points', 'order_index', 'explanation',
    ];

    protected $casts = [
        'options' => 'array',
        'points' => 'decimal:2',
    ];

    public function quiz()
    {
        return $this->belongsTo(Quiz::class);
    }

    /**
     * Only usable for auto-gradable types (multiple_choice, true_false, fill_blank).
     * Essay questions always need manual grading.
     */
    public function isAnsweredCorrectly(?string $givenAnswer): ?bool
    {
        if ($this->question_type === 'essay') {
            return null; // cannot auto-grade
        }

        if ($givenAnswer === null) {
            return false;
        }

        if ($this->question_type === 'fill_blank' || $this->question_type === 'short_answer') {
            return strtolower(trim($givenAnswer)) === strtolower(trim((string) $this->correct_answer));
        }

        return trim($givenAnswer) === trim((string) $this->correct_answer);
    }
}
