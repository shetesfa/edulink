<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;

class PortfolioController extends Controller
{
    public function myPortfolio(Request $request)
    {
        return $this->getPortfolioData($request->user());
    }

    public function publicProfile($userId)
    {
        $user = User::findOrFail($userId);
        return $this->getPortfolioData($user);
    }

    private function getPortfolioData(User $user)
    {
        $lessonsViewed = \App\Models\LessonView::where('user_id', $user->id)->count();
        $quizzesTaken = \App\Models\QuizAttempt::where('student_id', $user->id)->count();
        
        $submissions = \App\Models\AssignmentSubmission::where('student_id', $user->id)->get();
        $assignmentsSubmitted = $submissions->count();
        
        $onTimeSubmissions = $submissions->filter(function($sub) {
            return $sub->status !== 'late';
        })->count();

        $quizScores = \App\Models\QuizAttempt::where('student_id', $user->id)
            ->join('quizzes', 'quiz_attempts.quiz_id', '=', 'quizzes.id')
            ->join('classes', 'quizzes.class_id', '=', 'classes.id')
            ->select('classes.subject', 'quiz_attempts.score', 'quiz_attempts.max_score')
            ->get();

        $totalScore = 0;
        $totalMax = 0;
        $subjectScoresMap = [];

        foreach ($quizScores as $q) {
            $scoreVal = (float)$q->score;
            $maxVal   = (float)($q->max_score ?: 100);
            $totalScore += $scoreVal;
            $totalMax += $maxVal;
            
            if (!isset($subjectScoresMap[$q->subject])) {
                $subjectScoresMap[$q->subject] = ['total' => 0, 'max' => 0];
            }
            $subjectScoresMap[$q->subject]['total'] += $scoreVal;
            $subjectScoresMap[$q->subject]['max'] += $maxVal;
        }
        
        foreach ($submissions as $sub) {
            if ($sub->score !== null) {
                $assignment = \App\Models\Assignment::with('schoolClass')->find($sub->assignment_id);
                if ($assignment) {
                    $maxScore = $assignment->max_score ?? 100;
                    $totalScore += $sub->score;
                    $totalMax += $maxScore;
                    
                    $subj = $assignment->schoolClass->subject ?? 'General';
                    if (!isset($subjectScoresMap[$subj])) {
                        $subjectScoresMap[$subj] = ['total' => 0, 'max' => 0];
                    }
                    $subjectScoresMap[$subj]['total'] += $sub->score;
                    $subjectScoresMap[$subj]['max'] += $maxScore;
                }
            }
        }

        $averageScore = $totalMax > 0 ? ($totalScore / $totalMax) * 100 : 0;
        
        $subjectScores = [];
        foreach ($subjectScoresMap as $subj => $data) {
            $subjectScores[] = [
                'subject' => $subj,
                'avg_score' => $data['max'] > 0 ? ($data['total'] / $data['max']) * 100 : 0
            ];
        }

        $badges = [];
        foreach ($quizScores as $q) {
            if ($q->score >= 100) {
                $badges[] = 'Quiz Master';
                break;
            }
        }

        $consecutiveOnTime = 0;
        $hasStreak = false;
        foreach ($submissions->sortByDesc('created_at') as $sub) {
            if ($sub->status !== 'late') {
                $consecutiveOnTime++;
                if ($consecutiveOnTime >= 5) {
                    $hasStreak = true;
                    break;
                }
            } else {
                $consecutiveOnTime = 0;
            }
        }
        if ($hasStreak) $badges[] = 'Perfect Streak';

        if ($averageScore >= 90) $badges[] = 'Study Champion';
        if ($lessonsViewed >= 20) $badges[] = 'Active Learner';
        if ($averageScore >= 95) $badges[] = 'Top Student';

        $activities = [];
        
        $recentQuizzes = \App\Models\QuizAttempt::where('student_id', $user->id)->orderBy('created_at', 'desc')->take(10)->get();
        foreach ($recentQuizzes as $q) {
            $activities[] = ['type' => 'quiz', 'date' => $q->created_at];
        }

        $recentSubs = \App\Models\AssignmentSubmission::where('student_id', $user->id)->orderBy('created_at', 'desc')->take(10)->get();
        foreach ($recentSubs as $s) {
            $activities[] = ['type' => 'assignment', 'date' => $s->created_at];
        }

        $recentLessons = \App\Models\LessonView::where('user_id', $user->id)->orderBy('created_at', 'desc')->take(10)->get();
        foreach ($recentLessons as $l) {
            $activities[] = ['type' => 'lesson', 'date' => $l->created_at];
        }

        usort($activities, function($a, $b) {
            return $b['date'] <=> $a['date'];
        });

        $activities = array_slice($activities, 0, 10);

        return response()->json([
            'success' => true,
            'data' => [
                'stats' => [
                    'lessons_viewed' => $lessonsViewed,
                    'quizzes_taken' => $quizzesTaken,
                    'assignments_submitted' => $assignmentsSubmitted,
                    'average_score' => $averageScore,
                    'on_time_submissions' => $onTimeSubmissions,
                ],
                'subject_scores' => $subjectScores,
                'badges' => $badges,
                'recent_activity' => $activities,
            ]
        ]);
    }
}
