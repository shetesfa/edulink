<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\Quiz;
use App\Models\QuizAttempt;
use App\Models\QuizQuestion;
use App\Models\Notification;
use App\Models\Classes;
use App\Models\Enrollment;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class QuizController extends Controller
{
    // ─────────────────────────────────────────────────────────────
    // LIST quizzes for a class
    // ─────────────────────────────────────────────────────────────
    public function index(Request $request, $classId): JsonResponse
    {
        $user = $request->user();

        $quizzes = Quiz::where('class_id', $classId)
            ->withCount('questions')
            ->orderByDesc('is_pinned')
            ->orderByDesc('created_at')
            ->get()
            ->map(function ($quiz) use ($user) {
                $myAttempt = $quiz->attempts()
                    ->where('student_id', $user->id)
                    ->latest('submitted_at')
                    ->first();

                return [
                    'id'              => $quiz->id,
                    'title'           => $quiz->title,
                    'description'     => $quiz->description,
                    'time_limit'      => $quiz->time_limit_minutes,
                    'pass_percentage' => $quiz->pass_score ?? 50,
                    'is_active'       => (bool) $quiz->is_published,
                    'is_pinned'       => (bool) $quiz->is_pinned,
                    'questions_count' => $quiz->questions_count,
                    'class_id'        => $quiz->class_id,
                    'created_at'      => $quiz->created_at?->toISOString(),
                    'max_attempts'    => $quiz->max_attempts ?? 1,
                    'attempts_used'   => $quiz->attempts()->where('student_id', $user->id)->count(),
                    'opens_at'        => $quiz->opens_at?->toISOString(),
                    'closes_at'       => $quiz->closes_at?->toISOString(),
                    'my_attempt'      => $myAttempt ? [
                        'id'           => $myAttempt->id,
                        'score'        => $myAttempt->score,
                        'percentage'   => $myAttempt->percentage,
                        'passed'       => (bool) $myAttempt->passed,
                        'submitted_at' => $myAttempt->submitted_at?->toISOString(),
                    ] : null,
                ];
            });

        return response()->json(['quizzes' => $quizzes]);
    }

    // ─────────────────────────────────────────────────────────────
    // CREATE quiz (teacher)
    // ─────────────────────────────────────────────────────────────
    public function store(Request $request, $classId): JsonResponse
    {
        $this->authorizeTeacher($request->user(), $classId);

        $validated = $request->validate([
            'title'           => 'required|string|max:255',
            'description'     => 'nullable|string',
            'time_limit'      => 'nullable|integer|min:1|max:180',
            'pass_percentage' => 'integer|min:1|max:100',
            'show_answers'    => 'boolean',
            'shuffle'         => 'boolean',
            'is_active'       => 'boolean',
            'questions'       => 'required|array|min:1',
            'questions.*.text'           => 'required|string',
            'questions.*.type'           => 'required|in:mcq,true_false,short_answer',
            'questions.*.options'        => 'nullable|array',
            'questions.*.correct_answer' => 'required|string',
            'questions.*.points'         => 'integer|min:1',
            'questions.*.explanation'    => 'nullable|string',
        ]);

        $quiz = DB::transaction(function () use ($validated, $classId, $request) {
            $quiz = Quiz::create([
                'class_id'           => $classId,
                'teacher_id'         => $request->user()->id,
                'title'              => $validated['title'],
                'description'        => $validated['description'] ?? null,
                'time_limit_minutes' => $validated['time_limit'] ?? null,
                'pass_score'         => $validated['pass_percentage'] ?? 50,
                'show_answers_after' => $validated['show_answers'] ?? true,
                'shuffle_questions'  => $validated['shuffle'] ?? false,
                'is_published'       => $validated['is_active'] ?? true,
            ]);

            $typeMap = [
                'mcq'          => 'multiple_choice',
                'true_false'   => 'true_false',
                'short_answer' => 'essay',
            ];

            foreach ($validated['questions'] as $i => $q) {
                QuizQuestion::create([
                    'quiz_id'        => $quiz->id,
                    'question_text'  => $q['text'],
                    'question_type'  => $typeMap[$q['type']] ?? $q['type'],
                    'options'        => isset($q['options']) ? json_encode($q['options']) : null,
                    'correct_answer' => $q['correct_answer'],
                    'points'         => $q['points'] ?? 1,
                    'explanation'    => $q['explanation'] ?? null,
                    'order_index'    => $i,
                ]);
            }

            return $quiz;
        });

        // Notify all enrolled students
        $class = Classes::findOrFail($classId);
        $studentIds = $class->enrollments()->pluck('student_id');
        $notifications = $studentIds->map(fn($id) => [
            'user_id'      => $id,
            'type'         => 'new_quiz',
            'title'        => "📊 New Quiz: {$quiz->title}",
            'body'         => $quiz->description ? substr($quiz->description, 0, 100) . '...' : 'Check your class for details.',
            'icon'         => 'HelpCircle',
            'related_type' => 'quiz',
            'related_id'   => $quiz->id,
            'action_url'   => "/classes/{$classId}/quizzes/{$quiz->id}",
            'is_read'      => 0,
            'created_at'   => now(),
        ])->toArray();

        if (!empty($notifications)) {
            Notification::insert($notifications);
        }

        return response()->json(['success' => true, 'quiz' => $quiz->load('questions')], 201);
    }

    // ─────────────────────────────────────────────────────────────
    // SHOW single quiz (for detail/edit)
    // ─────────────────────────────────────────────────────────────
    public function show(Request $request, $classId, $quizId): JsonResponse
    {
        $quiz = Quiz::where('class_id', $classId)->with('questions')->findOrFail($quizId);

        return response()->json(['quiz' => $quiz]);
    }

    // ─────────────────────────────────────────────────────────────
    // TAKE quiz (student — returns questions without correct answers)
    // ─────────────────────────────────────────────────────────────
    public function take(Request $request, $classId, $quizId): JsonResponse
    {
        $user = $request->user();
        $quiz = Quiz::where('class_id', $classId)->findOrFail($quizId);

        if (!$quiz->is_published) {
            return response()->json(['success' => false, 'message' => 'This quiz is not available yet.'], 403);
        }

        $questions = $quiz->questions()
            ->orderBy('order_index')
            ->get()
            ->map(fn($q) => [
                'id'            => $q->id,
                'question_text' => $q->question_text,
                'question_type' => $q->question_type,
                'options'       => is_string($q->options) ? json_decode($q->options) : $q->options,
                'points'        => $q->points,
                // Never expose correct_answer to students
            ]);

        if ($quiz->shuffle_questions) $questions = $questions->shuffle()->values();

        return response()->json([
            'quiz' => [
                'id'           => $quiz->id,
                'title'        => $quiz->title,
                'description'  => $quiz->description,
                'time_limit'   => $quiz->time_limit_minutes,
                'questions'    => $questions,
            ]
        ]);
    }

    // ─────────────────────────────────────────────────────────────
    // SUBMIT quiz (student)
    // ─────────────────────────────────────────────────────────────
    public function submit(Request $request, $classId, $quizId): JsonResponse
    {
        $user = $request->user();
        $quiz = Quiz::where('class_id', $classId)->with('questions')->findOrFail($quizId);

        $request->validate([
            'answers'            => 'required|array',
            'answers.*'          => 'nullable|string',
            'time_taken_seconds' => 'nullable|integer|min:0',
        ]);

        $submittedAt = now();
        $answers     = $request->answers;
        $timeTaken   = $request->time_taken_seconds ?? 0;

        // Grade
        $totalPoints   = 0;
        $earnedPoints  = 0;
        $answerRecords = [];

        foreach ($quiz->questions as $question) {
            $totalPoints += $question->points;
            $submitted = $answers[$question->id] ?? null;
            $isCorrect = $this->checkAnswer($submitted, $question->correct_answer, $question->question_type);
            $earned    = $isCorrect ? $question->points : 0;
            $earnedPoints += $earned;

            $answerRecords[] = [
                'question_id'     => $question->id,
                'selected_answer' => $submitted,
                'is_correct'      => $isCorrect,
                'points_earned'   => $earned,
            ];
        }

        $percentage = $totalPoints > 0 ? round(($earnedPoints / $totalPoints) * 100, 2) : 0;
        $passed     = $percentage >= ($quiz->pass_score ?? 50);

        // Store attempt with answers as JSON (no separate table)
        $attempt = QuizAttempt::create([
            'quiz_id'             => $quiz->id,
            'student_id'          => $user->id,
            'answers'             => json_encode($answerRecords),
            'score'               => $earnedPoints,
            'max_score'           => $totalPoints,
            'percentage'          => $percentage,
            'passed'              => $passed,
            'time_taken_seconds'  => $timeTaken,
            'submitted_at'        => $submittedAt,
        ]);

        // Build response with per-question review
        $showAnswers = $quiz->show_answers_after ?? true;
        $review = [];
        if ($showAnswers) {
            foreach ($quiz->questions as $question) {
                $a = collect($answerRecords)->firstWhere('question_id', $question->id);
                $review[] = [
                    'question_text'   => $question->question_text,
                    'selected_answer' => $a['selected_answer'] ?? null,
                    'correct_answer'  => $question->correct_answer,
                    'is_correct'      => $a['is_correct'] ?? false,
                    'explanation'     => $question->explanation,
                ];
            }
        }

        return response()->json([
            'success' => true,
            'attempt' => [
                'id'                 => $attempt->id,
                'score'              => $earnedPoints,
                'max_score'          => $totalPoints,
                'percentage'         => $percentage,
                'passed'             => $passed,
                'submitted_at'       => $submittedAt->toISOString(),
                'time_taken_seconds' => $timeTaken,
                'answers'            => $review,
            ],
        ]);
    }

    // ─────────────────────────────────────────────────────────────
    // ANALYTICS  — teacher view (class aggregate)
    // ─────────────────────────────────────────────────────────────
    public function analytics(Request $request, $classId, $quizId): JsonResponse
    {
        $quiz = Quiz::where('class_id', $classId)->with('questions')->findOrFail($quizId);

        $attempts = QuizAttempt::where('quiz_id', $quizId)
            ->with('student:id,first_name,last_name,email')
            ->get();

        $stats = [
            'total_attempts'   => $attempts->count(),
            'avg_percentage'   => round($attempts->avg('percentage') ?? 0, 1),
            'highest'          => round($attempts->max('percentage') ?? 0, 1),
            'lowest'           => round($attempts->min('percentage') ?? 0, 1),
            'pass_rate'        => $attempts->count() > 0
                ? round(($attempts->where('passed', 1)->count() / $attempts->count()) * 100, 1)
                : 0,
            'avg_time_seconds' => round($attempts->avg('time_taken_seconds') ?? 0),
        ];

        // Per-question stats (parsed from JSON answers across all attempts)
        $questionStats = $quiz->questions->map(function ($q) use ($attempts) {
            $totalAnswers  = 0;
            $correctCount  = 0;
            foreach ($attempts as $attempt) {
                $decoded = is_string($attempt->answers) ? json_decode($attempt->answers, true) : ($attempt->answers ?? []);
                if (!is_array($decoded)) continue;
                $ans = collect($decoded)->firstWhere('question_id', $q->id);
                if ($ans) {
                    $totalAnswers++;
                    if (!empty($ans['is_correct'])) $correctCount++;
                }
            }
            return [
                'id'             => $q->id,
                'question_text'  => $q->question_text,
                'correct_answer' => $q->correct_answer,
                'total_answers'  => $totalAnswers,
                'correct_count'  => $correctCount,
            ];
        });

        return response()->json([
            'quiz'      => ['id' => $quiz->id, 'title' => $quiz->title, 'class_name' => $quiz->class?->name],
            'stats'     => $stats,
            'questions' => $questionStats,
        ]);
    }

    // ─────────────────────────────────────────────────────────────
    // ATTEMPTS  — for teacher: all students; for student: own
    // ─────────────────────────────────────────────────────────────
    public function attempts(Request $request, $classId, $quizId): JsonResponse
    {
        $user = $request->user();
        $quiz = Quiz::where('class_id', $classId)->with('questions')->findOrFail($quizId);
        $isTeacher = $user->role_id >= 3;

        if ($isTeacher) {
            $attempts = QuizAttempt::where('quiz_id', $quizId)
                ->with('student:id,first_name,last_name,email')
                ->orderByDesc('submitted_at')
                ->get()
                ->map(fn($a) => [
                    'id'                 => $a->id,
                    'student_id'         => $a->student_id,
                    'student_name'       => $a->student ? "{$a->student->first_name} {$a->student->last_name}" : 'Unknown',
                    'student_email'      => $a->student?->email,
                    'score'              => $a->score,
                    'max_score'          => $a->max_score,
                    'percentage'         => round($a->percentage ?? 0, 1),
                    'passed'             => (bool) $a->passed,
                    'submitted_at'       => $a->submitted_at?->toISOString(),
                    'time_taken_seconds' => $a->time_taken_seconds,
                ]);

            return response()->json(['attempts' => $attempts]);
        }

        // Student: their own attempt
        $attempt = QuizAttempt::where('quiz_id', $quizId)
            ->where('student_id', $user->id)
            ->latest('submitted_at')
            ->first();

        if (!$attempt) {
            return response()->json(['attempt' => null, 'my_attempt' => null]);
        }

        $showAnswers = $quiz->show_answers_after ?? true;
        $decoded     = is_string($attempt->answers) ? json_decode($attempt->answers, true) : ($attempt->answers ?? []);

        $answers = [];
        if ($showAnswers && is_array($decoded)) {
            foreach ($decoded as $a) {
                $question = $quiz->questions->firstWhere('id', $a['question_id'] ?? null);
                $answers[] = [
                    'question_text'   => $question?->question_text,
                    'selected_answer' => $a['selected_answer'] ?? null,
                    'correct_answer'  => $question?->correct_answer,
                    'is_correct'      => (bool) ($a['is_correct'] ?? false),
                    'explanation'     => $question?->explanation,
                ];
            }
        }

        return response()->json([
            'attempt'    => [
                'id'                 => $attempt->id,
                'score'              => $attempt->score,
                'max_score'          => $attempt->max_score,
                'percentage'         => round($attempt->percentage ?? 0, 1),
                'passed'             => (bool) $attempt->passed,
                'submitted_at'       => $attempt->submitted_at?->toISOString(),
                'time_taken_seconds' => $attempt->time_taken_seconds,
                'answers'            => $answers,
            ],
            'my_attempt' => ['submitted_at' => $attempt->submitted_at?->toISOString()],
        ]);
    }

    // ─────────────────────────────────────────────────────────────
    // PIN / UNPIN  (teacher only)
    // ─────────────────────────────────────────────────────────────
    public function togglePin(Request $request, $classId, $quizId): JsonResponse
    {
        $this->authorizeTeacher($request->user(), $classId);

        $quiz = Quiz::where('class_id', $classId)->findOrFail($quizId);
        $newState = !$quiz->is_pinned;

        $quiz->update([
            'is_pinned' => $newState,
            'pinned_at' => $newState ? now() : null,
            'pinned_by' => $newState ? $request->user()->id : null,
        ]);

        // Broadcast via socket server
        $this->broadcastPinUpdate($classId, [
            'type'        => 'quiz',
            'id'          => $quiz->id,
            'title'       => $quiz->title,
            'class_id'    => $classId,
            'is_pinned'   => $newState,
            'teacher_name'=> $request->user()->full_name ?? 'Teacher',
            'class_name'  => $quiz->class?->name,
            'due_date'    => null,
        ]);

        return response()->json([
            'success'   => true,
            'is_pinned' => $newState,
            'message'   => $newState ? 'Quiz pinned to student dashboards!' : 'Quiz unpinned.',
        ]);
    }

    // ─────────────────────────────────────────────────────────────
    // UPDATE / DELETE
    // ─────────────────────────────────────────────────────────────
    public function update(Request $request, $classId, $quizId): JsonResponse
    {
        $this->authorizeTeacher($request->user(), $classId);
        $quiz = Quiz::where('class_id', $classId)->findOrFail($quizId);

        // Map frontend field names to DB column names
        $map = [
            'title'           => 'title',
            'description'     => 'description',
            'time_limit'      => 'time_limit_minutes',
            'pass_percentage' => 'pass_score',
            'show_answers'    => 'show_answers_after',
            'shuffle'         => 'shuffle_questions',
            'is_active'       => 'is_published',
        ];

        $update = [];
        foreach ($map as $input => $column) {
            if ($request->has($input)) {
                $update[$column] = $request->input($input);
            }
        }

        if (!empty($update)) $quiz->update($update);

        return response()->json(['success' => true, 'quiz' => $quiz]);
    }

    public function destroy(Request $request, $classId, $quizId): JsonResponse
    {
        $this->authorizeTeacher($request->user(), $classId);
        Quiz::where('class_id', $classId)->findOrFail($quizId)->delete();
        return response()->json(['success' => true, 'message' => 'Quiz deleted.']);
    }

    // ─────────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────────
    private function checkAnswer(?string $submitted, ?string $correct, string $type): bool
    {
        if ($submitted === null || $correct === null) return false;
        return strtolower(trim($submitted)) === strtolower(trim($correct));
    }

    private function authorizeTeacher($user, $classId): void
    {
        if ($user->role_id < 3) {
            abort(403, 'Only teachers and admins can manage quizzes.');
        }
    }

    private function broadcastPinUpdate($classId, array $item): void
    {
        try {
            $internalPort = config('services.socket.internal_port', 3002);
            $secret       = config('services.socket.secret', 'edulink_internal');
            \Illuminate\Support\Facades\Http::timeout(2)->withHeaders(['X-Internal-Secret' => $secret])
                ->post("http://localhost:{$internalPort}/broadcast", [
                    'room'  => "class:{$classId}",
                    'event' => 'class:pin-update',
                    'data'  => ['class_id' => $classId, 'item' => $item],
                ]);
        } catch (\Exception $e) {
            Log::debug('Socket broadcast failed (non-critical): ' . $e->getMessage());
        }
    }
}
