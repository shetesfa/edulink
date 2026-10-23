<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Quizzes\CreateQuizRequest;
use App\Http\Requests\Quizzes\AddQuestionRequest;
use App\Http\Requests\Quizzes\SubmitQuizAttemptRequest;
use App\Models\SchoolClass;
use App\Models\Quiz;
use App\Models\QuizQuestion;
use App\Models\QuizAttempt;
use App\Services\QuizGradingService;
use App\Services\NotificationDispatchService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class QuizController extends Controller
{
    public function __construct(
        private QuizGradingService $gradingService,
        private NotificationDispatchService $notifier,
    ) {}

    /**
     * GET /api/classes/{class}/quizzes
     */
    public function index(Request $request, SchoolClass $class)
    {
        Gate::forUser($request->user())->authorize('view', $class);

        $query = $class->quizzes()->withCount('questions')->latest();

        if (!Gate::forUser($request->user())->allows('manage', $class)) {
            $query->where('is_published', true);
        }

        return response()->json(['success' => true, 'data' => ['quizzes' => $query->get()]]);
    }

    /**
     * POST /api/classes/{class}/quizzes  (Teacher only) - can include questions inline
     */
    public function store(CreateQuizRequest $request, SchoolClass $class)
    {
        Gate::forUser($request->user())->authorize('manage', $class);

        $data = $request->safe()->except('questions');
        $data['class_id'] = $class->id;
        $data['teacher_id'] = $request->user()->id;
        if (!array_key_exists('is_published', $data)) {
            $data['is_published'] = true;
        }

        $quiz = Quiz::create($data);

        foreach ($request->input('questions', []) as $index => $q) {
            QuizQuestion::create([
                'quiz_id' => $quiz->id,
                'question_type' => $q['question_type'],
                'question_text' => $q['question_text'],
                'options' => $q['options'] ?? null,
                'correct_answer' => $q['correct_answer'] ?? null,
                'points' => $q['points'] ?? 1,
                'order_index' => $index,
                'explanation' => $q['explanation'] ?? null,
            ]);
        }

        $this->notifyIfPublished($quiz);

        return response()->json([
            'success' => true,
            'message' => 'Quiz created.',
            'data' => ['quiz' => $quiz->fresh('questions')],
        ], 201);
    }

    private function notifyIfPublished(Quiz $quiz): void
    {
        if (!$quiz->is_published) {
            return;
        }

        $this->notifier->notifyMany($quiz->schoolClass->students, [
            'type' => 'new_quiz',
            'title' => "New quiz: {$quiz->title}",
            'body' => $quiz->schoolClass->name,
            'icon' => 'help-circle',
            'related_type' => 'quiz',
            'related_id' => $quiz->id,
            'action_url' => "/quizzes/{$quiz->id}",
            'email_body' => "A new quiz \"{$quiz->title}\" is now available in {$quiz->schoolClass->name}.",
        ]);
    }

    /**
     * GET /api/quizzes/{quiz}
     * Students get questions WITHOUT correct_answer. Teachers get everything.
     */
    public function show(Request $request, Quiz $quiz)
    {
        Gate::forUser($request->user())->authorize('view', $quiz->schoolClass);

        $isTeacher = Gate::forUser($request->user())->allows('manage', $quiz->schoolClass);
        $quiz->load('questions');

        if (!$isTeacher) {
            $quiz->questions->each(function ($q) {
                $q->makeHidden(['correct_answer']);
            });

            $attemptsUsed = $quiz->attempts()->where('student_id', $request->user()->id)->count();
            return response()->json([
                'success' => true,
                'data' => [
                    'quiz' => $quiz,
                    'attempts_used' => $attemptsUsed,
                    'attempts_remaining' => max(0, $quiz->max_attempts - $attemptsUsed),
                    'is_open' => $quiz->isOpen(),
                ],
            ]);
        }

        return response()->json(['success' => true, 'data' => ['quiz' => $quiz]]);
    }

    /**
     * PUT /api/quizzes/{quiz}  (Teacher only)
     */
    public function update(CreateQuizRequest $request, Quiz $quiz)
    {
        Gate::forUser($request->user())->authorize('manage', $quiz->schoolClass);
        $wasPublished = $quiz->is_published;

        $quiz->update($request->safe()->except('questions'));

        if (!$wasPublished && $quiz->is_published) {
            $this->notifyIfPublished($quiz->fresh());
        }

        return response()->json(['success' => true, 'message' => 'Quiz updated.', 'data' => ['quiz' => $quiz->fresh('questions')]]);
    }

    /**
     * DELETE /api/quizzes/{quiz}  (Teacher only)
     */
    public function destroy(Request $request, Quiz $quiz)
    {
        Gate::forUser($request->user())->authorize('manage', $quiz->schoolClass);
        $quiz->delete();

        return response()->json(['success' => true, 'message' => 'Quiz deleted.']);
    }

    /**
     * POST /api/quizzes/{quiz}/questions  (Teacher only - add one question at a time)
     */
    public function addQuestion(AddQuestionRequest $request, Quiz $quiz)
    {
        Gate::forUser($request->user())->authorize('manage', $quiz->schoolClass);

        $data = $request->validated();
        $data['quiz_id'] = $quiz->id;
        $data['order_index'] = $data['order_index'] ?? $quiz->questions()->count();

        $question = QuizQuestion::create($data);

        return response()->json(['success' => true, 'message' => 'Question added.', 'data' => ['question' => $question]], 201);
    }

    /**
     * DELETE /api/quizzes/questions/{question}  (Teacher only)
     */
    public function deleteQuestion(Request $request, QuizQuestion $question)
    {
        Gate::forUser($request->user())->authorize('manage', $question->quiz->schoolClass);
        $question->delete();

        return response()->json(['success' => true, 'message' => 'Question deleted.']);
    }

    /**
     * GET /api/quizzes/{quiz}/take  (Student) - starts/resumes an attempt view
     */
    public function take(Request $request, Quiz $quiz)
    {
        Gate::forUser($request->user())->authorize('view', $quiz->schoolClass);

        if (!$quiz->is_published || !$quiz->isOpen()) {
            return response()->json(['success' => false, 'message' => 'This quiz is not currently open.'], 422);
        }

        $attemptsUsed = $quiz->attempts()->where('student_id', $request->user()->id)->count();
        if ($attemptsUsed >= $quiz->max_attempts) {
            return response()->json(['success' => false, 'message' => 'You have used all your attempts for this quiz.'], 422);
        }

        $questions = $quiz->questions()->get(['id', 'question_type', 'question_text', 'options', 'points', 'order_index']);

        if ($quiz->shuffle_questions) {
            $questions = $questions->shuffle()->values();
        }

        return response()->json([
            'success' => true,
            'data' => [
                'quiz' => $quiz->only(['id', 'title', 'description', 'time_limit_minutes']),
                'questions' => $questions,
            ],
        ]);
    }

    /**
     * POST /api/quizzes/{quiz}/submit  (Student)
     */
    public function submit(SubmitQuizAttemptRequest $request, Quiz $quiz)
    {
        Gate::forUser($request->user())->authorize('view', $quiz->schoolClass);

        if (!$quiz->is_published || !$quiz->isOpen()) {
            return response()->json(['success' => false, 'message' => 'This quiz is not currently open.'], 422);
        }

        $attemptsUsed = $quiz->attempts()->where('student_id', $request->user()->id)->count();
        if ($attemptsUsed >= $quiz->max_attempts) {
            return response()->json(['success' => false, 'message' => 'You have used all your attempts for this quiz.'], 422);
        }

        $result = $this->gradingService->grade($quiz, $request->answers);

        $attempt = QuizAttempt::create([
            'quiz_id' => $quiz->id,
            'student_id' => $request->user()->id,
            'answers' => $request->answers,
            'score' => $result['score'],
            'max_score' => $result['max_score'],
            'percentage' => $result['percentage'],
            'passed' => $result['passed'],
            'needs_manual_grading' => $result['needs_manual_grading'],
            'time_taken_seconds' => $request->time_taken_seconds,
            'submitted_at' => now(),
        ]);

        app(\App\Services\ProgressService::class)->recalculate($request->user(), $quiz->schoolClass);

        $responseData = ['attempt_id' => $attempt->id];

        if ($quiz->show_answers_after && !$result['needs_manual_grading']) {
            $responseData['score'] = $result['score'];
            $responseData['max_score'] = $result['max_score'];
            $responseData['percentage'] = $result['percentage'];
            $responseData['passed'] = $result['passed'];
        } else {
            $responseData['message_detail'] = $result['needs_manual_grading']
                ? 'Your quiz includes essay questions that need teacher grading.'
                : 'Results will be shown once your teacher enables them.';
        }

        return response()->json([
            'success' => true,
            'message' => 'Quiz submitted.',
            'data' => $responseData,
        ]);
    }

    /**
     * GET /api/quizzes/{quiz}/analytics  (Teacher only)
     */
    public function analytics(Request $request, Quiz $quiz)
    {
        Gate::forUser($request->user())->authorize('manage', $quiz->schoolClass);

        $attempts = $quiz->attempts()->with('student')->get();

        return response()->json([
            'success' => true,
            'data' => [
                'total_attempts' => $attempts->count(),
                'average_percentage' => round($attempts->avg('percentage') ?? 0, 2),
                'pass_rate' => $attempts->count() > 0
                    ? round($attempts->where('passed', true)->count() / $attempts->count() * 100, 2)
                    : 0,
                'needs_manual_grading_count' => $attempts->where('needs_manual_grading', true)->count(),
                'attempts' => $attempts,
            ],
        ]);
    }

    /**
     * GET /api/quizzes/{quiz}/attempts  (Student's own attempt history)
     */
    public function myAttempts(Request $request, Quiz $quiz)
    {
        Gate::forUser($request->user())->authorize('view', $quiz->schoolClass);

        $attempts = $quiz->attempts()
            ->where('student_id', $request->user()->id)
            ->latest()
            ->get();

        return response()->json(['success' => true, 'data' => ['attempts' => $attempts]]);
    }
}
