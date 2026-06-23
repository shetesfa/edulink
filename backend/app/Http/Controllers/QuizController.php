<?php

namespace App\Http\Controllers;

use App\Models\Quiz;
use App\Models\QuizQuestion;
use App\Models\QuizAttempt;
use App\Models\Classes;
use App\Models\Notification;
use App\Models\StudentProgress;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class QuizController extends Controller
{
    // ─── List quizzes for a class ─────────────────────────────────
    public function index(Request $request, int $classId): JsonResponse
    {
        $user  = $request->user();
        $class = Classes::findOrFail($classId);

        $query = Quiz::where('class_id', $classId)->with('teacher');

        if ($user->role->name === 'student') {
            $query->where('is_published', 1)
                ->where(fn($q) => $q->whereNull('opens_at')->orWhere('opens_at', '<=', now()))
                ->where(fn($q) => $q->whereNull('closes_at')->orWhere('closes_at', '>=', now()));
        }

        $quizzes = $query->orderBy('created_at', 'desc')->get()->map(function ($quiz) use ($user) {
            $attempt = QuizAttempt::where('quiz_id', $quiz->id)
                ->where('student_id', $user->id)
                ->orderBy('created_at', 'desc')
                ->first();

            return [
                'id'              => $quiz->id,
                'title'           => $quiz->title,
                'description'     => $quiz->description,
                'time_limit'      => $quiz->time_limit_minutes,
                'max_attempts'    => $quiz->max_attempts,
                'pass_score'      => $quiz->pass_score,
                'is_published'    => (bool) $quiz->is_published,
                'opens_at'        => $quiz->opens_at?->toISOString(),
                'closes_at'       => $quiz->closes_at?->toISOString(),
                'questions_count' => $quiz->questions()->count(),
                'created_at'      => $quiz->created_at->toISOString(),
                'my_attempt'      => $attempt ? [
                    'id'          => $attempt->id,
                    'score'       => $attempt->score,
                    'percentage'  => $attempt->percentage,
                    'passed'      => (bool) $attempt->passed,
                    'submitted_at'=> $attempt->submitted_at?->toISOString(),
                ] : null,
                'attempts_used'   => QuizAttempt::where('quiz_id', $quiz->id)
                    ->where('student_id', $user->id)->count(),
            ];
        });

        return response()->json(['success' => true, 'quizzes' => $quizzes]);
    }

    // ─── Create quiz ──────────────────────────────────────────────
    public function store(Request $request, int $classId): JsonResponse
    {
        $user  = $request->user();
        $class = Classes::findOrFail($classId);

        if ($class->teacher_id !== $user->id && $user->role->name !== 'school_admin') {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

        $validated = $request->validate([
            'title'              => 'required|string|max:300',
            'description'        => 'nullable|string',
            'time_limit_minutes' => 'nullable|integer|min:1|max:300',
            'max_attempts'       => 'integer|min:1|max:10',
            'shuffle_questions'  => 'boolean',
            'show_answers_after' => 'boolean',
            'pass_score'         => 'numeric|min:0|max:100',
            'is_published'       => 'boolean',
            'opens_at'           => 'nullable|date',
            'closes_at'          => 'nullable|date|after:opens_at',
            'questions'          => 'required|array|min:1',
            'questions.*.question_type' => 'required|in:multiple_choice,true_false,fill_blank,essay',
            'questions.*.question_text' => 'required|string',
            'questions.*.options'       => 'nullable|array',
            'questions.*.correct_answer'=> 'nullable|string',
            'questions.*.points'        => 'numeric|min:0|max:100',
            'questions.*.explanation'   => 'nullable|string',
        ]);

        $quiz = Quiz::create([
            'class_id'           => $classId,
            'teacher_id'         => $user->id,
            'title'              => $validated['title'],
            'description'        => $validated['description'] ?? null,
            'time_limit_minutes' => $validated['time_limit_minutes'] ?? null,
            'max_attempts'       => $validated['max_attempts'] ?? 1,
            'shuffle_questions'  => $validated['shuffle_questions'] ?? false,
            'show_answers_after' => $validated['show_answers_after'] ?? true,
            'pass_score'         => $validated['pass_score'] ?? 50,
            'is_published'       => $validated['is_published'] ?? false,
            'opens_at'           => $validated['opens_at'] ?? null,
            'closes_at'          => $validated['closes_at'] ?? null,
        ]);

        // Save questions
        foreach ($validated['questions'] as $index => $q) {
            QuizQuestion::create([
                'quiz_id'       => $quiz->id,
                'question_type' => $q['question_type'],
                'question_text' => $q['question_text'],
                'options'       => isset($q['options']) ? json_encode($q['options']) : null,
                'correct_answer'=> $q['correct_answer'] ?? null,
                'points'        => $q['points'] ?? 1,
                'order_index'   => $index,
                'explanation'   => $q['explanation'] ?? null,
            ]);
        }

        // Notify enrolled students if published
        if ($quiz->is_published) {
            $this->notifyStudents($class, $quiz->id, 'new_quiz', "New quiz: {$quiz->title}");
        }

        return response()->json([
            'success' => true,
            'message' => 'Quiz created!',
            'quiz'    => $quiz->load('questions'),
        ], 201);
    }

    // ─── Get quiz for taking (student view) ───────────────────────
    public function take(Request $request, int $quizId): JsonResponse
    {
        $user  = $request->user();
        $quiz  = Quiz::with('questions')->findOrFail($quizId);

        // Check attempt count
        $used = QuizAttempt::where('quiz_id', $quizId)->where('student_id', $user->id)->count();
        if ($used >= $quiz->max_attempts) {
            return response()->json(['success' => false, 'message' => 'You have used all your attempts.'], 403);
        }

        // Check time window
        if ($quiz->opens_at && now()->lt($quiz->opens_at)) {
            return response()->json(['success' => false, 'message' => 'This quiz is not open yet.'], 403);
        }
        if ($quiz->closes_at && now()->gt($quiz->closes_at)) {
            return response()->json(['success' => false, 'message' => 'This quiz has closed.'], 403);
        }

        $questions = $quiz->questions->map(fn($q) => [
            'id'            => $q->id,
            'question_type' => $q->question_type,
            'question_text' => $q->question_text,
            'options'       => $q->options ? json_decode($q->options) : null,
            'points'        => $q->points,
            // Do NOT send correct_answer to student
        ]);

        if ($quiz->shuffle_questions) {
            $questions = $questions->shuffle()->values();
        }

        return response()->json([
            'success'    => true,
            'quiz'       => [
                'id'          => $quiz->id,
                'title'       => $quiz->title,
                'description' => $quiz->description,
                'time_limit'  => $quiz->time_limit_minutes,
                'questions'   => $questions,
            ],
            'started_at' => now()->toISOString(),
        ]);
    }

    // ─── Submit quiz answers ──────────────────────────────────────
    public function submit(Request $request, int $quizId): JsonResponse
    {
        $user = $request->user();
        $quiz = Quiz::with('questions')->findOrFail($quizId);

        $request->validate([
            'answers'             => 'required|array',
            'time_taken_seconds'  => 'nullable|integer',
        ]);

        // Check attempt limit
        $used = QuizAttempt::where('quiz_id', $quizId)->where('student_id', $user->id)->count();
        if ($used >= $quiz->max_attempts) {
            return response()->json(['success' => false, 'message' => 'No attempts remaining.'], 403);
        }

        // Auto-grade
        $answers   = $request->answers;
        $totalPoints = 0;
        $earnedPoints = 0;
        $gradedAnswers = [];

        foreach ($quiz->questions as $question) {
            $totalPoints += $question->points;
            $studentAnswer = $answers[$question->id] ?? null;
            $isCorrect = false;

            if ($question->question_type !== 'essay' && $studentAnswer !== null) {
                $correct = strtolower(trim($question->correct_answer ?? ''));
                $given   = strtolower(trim($studentAnswer));
                $isCorrect = ($correct === $given);
                if ($isCorrect) $earnedPoints += $question->points;
            }

            $gradedAnswers[$question->id] = [
                'given'       => $studentAnswer,
                'correct'     => $quiz->show_answers_after ? $question->correct_answer : null,
                'is_correct'  => $question->question_type === 'essay' ? null : $isCorrect,
                'points'      => $isCorrect ? $question->points : 0,
                'explanation' => ($quiz->show_answers_after && !$isCorrect) ? $question->explanation : null,
            ];
        }

        $percentage = $totalPoints > 0 ? round(($earnedPoints / $totalPoints) * 100, 2) : 0;
        $passed     = $percentage >= $quiz->pass_score;

        $attempt = QuizAttempt::create([
            'quiz_id'             => $quizId,
            'student_id'          => $user->id,
            'answers'             => json_encode($answers),
            'score'               => $earnedPoints,
            'max_score'           => $totalPoints,
            'percentage'          => $percentage,
            'passed'              => $passed,
            'time_taken_seconds'  => $request->time_taken_seconds,
            'submitted_at'        => now(),
        ]);

        // Update progress
        $this->updateProgress($user->id, $quiz->class_id);

        return response()->json([
            'success'     => true,
            'result'      => [
                'score'       => $earnedPoints,
                'max_score'   => $totalPoints,
                'percentage'  => $percentage,
                'passed'      => $passed,
                'grade'       => $this->letterGrade($percentage),
                'answers'     => $quiz->show_answers_after ? $gradedAnswers : [],
            ],
        ]);
    }

    // ─── Quiz analytics (teacher view) ───────────────────────────
    public function analytics(Request $request, int $quizId): JsonResponse
    {
        $quiz     = Quiz::with('questions')->findOrFail($quizId);
        $attempts = QuizAttempt::where('quiz_id', $quizId)->with('student')->get();

        if ($attempts->isEmpty()) {
            return response()->json(['success' => true, 'analytics' => ['no_data' => true]]);
        }

        $scores      = $attempts->pluck('percentage');
        $passCount   = $attempts->where('passed', 1)->count();
        $distribution = [
            'A (90-100)' => $attempts->whereBetween('percentage', [90, 100])->count(),
            'B (80-89)'  => $attempts->whereBetween('percentage', [80, 89])->count(),
            'C (70-79)'  => $attempts->whereBetween('percentage', [70, 79])->count(),
            'D (60-69)'  => $attempts->whereBetween('percentage', [60, 69])->count(),
            'F (0-59)'   => $attempts->where('percentage', '<', 60)->count(),
        ];

        return response()->json([
            'success'    => true,
            'analytics'  => [
                'total_attempts' => $attempts->count(),
                'avg_score'      => round($scores->avg(), 1),
                'highest_score'  => $scores->max(),
                'lowest_score'   => $scores->min(),
                'pass_rate'      => round(($passCount / $attempts->count()) * 100, 1),
                'distribution'   => $distribution,
                'student_results' => $attempts->map(fn($a) => [
                    'student_name' => $a->student->first_name . ' ' . $a->student->last_name,
                    'score'        => $a->score,
                    'percentage'   => $a->percentage,
                    'passed'       => (bool) $a->passed,
                    'time_taken'   => $a->time_taken_seconds,
                    'submitted_at' => $a->submitted_at?->toISOString(),
                ])->toArray(),
            ],
        ]);
    }

    // ─── Delete quiz ──────────────────────────────────────────────
    public function destroy(Request $request, int $quizId): JsonResponse
    {
        $quiz = Quiz::findOrFail($quizId);
        if ($quiz->teacher_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }
        $quiz->delete();
        return response()->json(['success' => true, 'message' => 'Quiz deleted.']);
    }

    // ─── Helpers ──────────────────────────────────────────────────
    private function letterGrade(float $pct): string
    {
        return match (true) {
            $pct >= 90 => 'A',
            $pct >= 80 => 'B',
            $pct >= 70 => 'C',
            $pct >= 60 => 'D',
            default    => 'F',
        };
    }

    private function updateProgress(int $studentId, int $classId): void
    {
        $progress = StudentProgress::where('student_id', $studentId)->where('class_id', $classId)->first();
        if (!$progress) return;

        $quizIds   = Quiz::where('class_id', $classId)->pluck('id');
        $avgScore  = QuizAttempt::whereIn('quiz_id', $quizIds)->where('student_id', $studentId)->avg('percentage');
        $taken     = QuizAttempt::whereIn('quiz_id', $quizIds)->where('student_id', $studentId)
            ->distinct('quiz_id')->count('quiz_id');

        $progress->update([
            'avg_quiz_score'  => round($avgScore ?? 0, 2),
            'quizzes_taken'   => $taken,
            'last_activity'   => now(),
        ]);
    }

    private function notifyStudents(Classes $class, int $relatedId, string $type, string $title): void
    {
        $studentIds = $class->enrollments()->pluck('student_id');
        $notifications = $studentIds->map(fn($id) => [
            'user_id'      => $id,
            'type'         => $type,
            'title'        => $title,
            'body'         => "Class: {$class->name}",
            'related_type' => 'quiz',
            'related_id'   => $relatedId,
            'action_url'   => "/classes/{$class->id}/quizzes/{$relatedId}",
            'created_at'   => now(),
        ])->toArray();

        Notification::insert($notifications);
    }
}
