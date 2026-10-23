<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SchoolClass;
use App\Models\User;
use Illuminate\Http\Request;

class AnalyticsController extends Controller
{
    public function classPerformance(Request $request, $classId)
    {
        $class = SchoolClass::with(['students.quizAttempts.quiz', 'students.assignmentSubmissions.assignment'])->findOrFail($classId);

        $analytics = [];

        foreach ($class->students as $student) {
            $quizAttempts = $student->quizAttempts->filter(function ($attempt) use ($classId) {
                return $attempt->quiz->class_id == $classId;
            })->sortByDesc('created_at')->values();

            $quizCount = $quizAttempts->count();
            $quizAvg = $quizCount > 0 ? $quizAttempts->avg('score') : 0;
            $latest5 = $quizAttempts->take(5)->pluck('score')->toArray();

            $assignmentSubmissions = $student->assignmentSubmissions->filter(function ($sub) use ($classId) {
                return $sub->assignment->class_id == $classId;
            });
            $assignmentCount = $assignmentSubmissions->count();
            $assignmentAvg = $assignmentCount > 0 ? $assignmentSubmissions->avg('score') : 0;

            $status = 'normal';
            if ($quizCount >= 3 && $quizAvg >= 80) {
                $status = 'excellent';
            } elseif ($quizCount >= 3 && $quizAvg < 50) {
                $status = 'struggling';
            } elseif ($quizCount == 1 && $quizAvg < 50) {
                $status = 'first_time_low';
            } elseif ($quizCount >= 6) {
                $last3 = array_slice($latest5, 0, 3);
                $prev3 = $quizAttempts->slice(3, 3)->pluck('score')->toArray();
                if (count($last3) == 3 && count($prev3) == 3 && array_sum($last3) < array_sum($prev3)) {
                    $status = 'declining';
                }
            }

            $suggestion = match ($status) {
                'excellent' => 'Provide advanced materials.',
                'struggling' => 'Schedule a one-on-one session.',
                'declining' => 'Check in on their recent difficulties.',
                'first_time_low' => 'Review the basics with them.',
                'normal' => 'Keep up the good work.',
                default => 'Keep up the good work.'
            };

            $analytics[] = [
                'student' => $student,
                'quiz_attempts' => [
                    'count' => $quizCount,
                    'average_score' => $quizAvg,
                    'latest_scores' => $latest5,
                ],
                'assignment_submissions' => [
                    'count' => $assignmentCount,
                    'average_score' => $assignmentAvg,
                ],
                'performance_status' => $status,
                'suggestion' => $suggestion,
            ];
        }

        return response()->json([
            'success' => true,
            'data' => $analytics
        ]);
    }
}
