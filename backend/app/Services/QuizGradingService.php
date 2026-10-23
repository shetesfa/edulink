<?php

namespace App\Services;

use App\Models\Quiz;
use App\Models\QuizAttempt;

class QuizGradingService
{
    /**
     * Grade an attempt against its quiz's questions.
     * Essay questions are skipped (score 0 for now) and flagged for manual grading.
     *
     * @param array $answers  [question_id => given answer]
     */
    public function grade(Quiz $quiz, array $answers): array
    {
        $questions = $quiz->questions;
        $totalScore = 0;
        $maxScore = 0;
        $needsManualGrading = false;

        foreach ($questions as $question) {
            $maxScore += (float) $question->points;
            $given = $answers[$question->id] ?? null;

            if ($question->question_type === 'essay') {
                $needsManualGrading = true;
                continue; // teacher will award points later
            }

            if ($question->isAnsweredCorrectly($given)) {
                $totalScore += (float) $question->points;
            }
        }

        $percentage = $maxScore > 0 ? round(($totalScore / $maxScore) * 100, 2) : 0;
        $passed = $needsManualGrading ? null : $percentage >= (float) $quiz->pass_score;

        return [
            'score' => $totalScore,
            'max_score' => $maxScore,
            'percentage' => $percentage,
            'passed' => $passed,
            'needs_manual_grading' => $needsManualGrading,
        ];
    }

    /**
     * Re-grade an attempt after a teacher manually scores essay questions.
     * $essayScores = [question_id => points awarded]
     */
    public function applyManualEssayScores(QuizAttempt $attempt, array $essayScores): array
    {
        $quiz = $attempt->quiz;
        $autoResult = $this->grade($quiz, $attempt->answers);

        $manualTotal = array_sum($essayScores);
        $finalScore = $autoResult['score'] + $manualTotal;
        $maxScore = $autoResult['max_score'];
        $percentage = $maxScore > 0 ? round(($finalScore / $maxScore) * 100, 2) : 0;

        return [
            'score' => $finalScore,
            'max_score' => $maxScore,
            'percentage' => $percentage,
            'passed' => $percentage >= (float) $quiz->pass_score,
            'needs_manual_grading' => false,
        ];
    }
}
