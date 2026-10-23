<?php

namespace App\Services;

use App\Models\User;
use App\Models\SchoolClass;
use App\Models\StudentProgress;
use App\Models\LessonView;
use App\Models\AssignmentSubmission;
use App\Models\QuizAttempt;
use Illuminate\Support\Carbon;

class ProgressService
{
    /**
     * Recompute a student's progress row for a class from the real,
     * current state of lessons/assignments/quizzes - never trust a stale
     * cached number, always derive it fresh.
     */
    public function recalculate(User $student, SchoolClass $class): StudentProgress
    {
        $lessonsTotal = $class->lessons()->where('is_published', true)->count();
        $lessonIds = $class->lessons()->where('is_published', true)->pluck('id');
        $lessonsViewed = LessonView::where('user_id', $student->id)->whereIn('lesson_id', $lessonIds)->count();

        $assignmentsTotal = $class->assignments()->where('is_published', true)->count();
        $assignmentIds = $class->assignments()->where('is_published', true)->pluck('id');
        $assignmentsSubmitted = AssignmentSubmission::where('student_id', $student->id)
            ->whereIn('assignment_id', $assignmentIds)->count();

        $quizIds = $class->quizzes()->pluck('id');
        $attempts = QuizAttempt::where('student_id', $student->id)->whereIn('quiz_id', $quizIds)->get();
        $quizzesTaken = $attempts->pluck('quiz_id')->unique()->count();
        $avgQuizScore = $attempts->count() > 0 ? round($attempts->avg('percentage'), 2) : 0;

        $lastActivityCandidates = array_filter([
            LessonView::where('user_id', $student->id)->whereIn('lesson_id', $lessonIds)->max('viewed_at'),
            AssignmentSubmission::where('student_id', $student->id)->whereIn('assignment_id', $assignmentIds)->max('submitted_at'),
            $attempts->max('submitted_at'),
        ]);
        $lastActivity = empty($lastActivityCandidates) ? null : Carbon::parse(max($lastActivityCandidates));

        return StudentProgress::updateOrCreate(
            ['student_id' => $student->id, 'class_id' => $class->id],
            [
                'lessons_total' => $lessonsTotal,
                'lessons_viewed' => $lessonsViewed,
                'assignments_total' => $assignmentsTotal,
                'assignments_submitted' => $assignmentsSubmitted,
                'quizzes_taken' => $quizzesTaken,
                'avg_quiz_score' => $avgQuizScore,
                'last_activity' => $lastActivity,
            ]
        );
    }
}
