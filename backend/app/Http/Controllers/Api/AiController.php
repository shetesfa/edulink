<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Ai\AskAiRequest;
use App\Models\AiProvider;
use App\Models\AiUsage;
use App\Services\AiRouterService;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class AiController extends Controller
{
    public function __construct(private AiRouterService $router) {}

    /**
     * POST /api/ai/ask
     */
    public function ask(AskAiRequest $request)
    {
        $user = $request->user();
        $result = $this->router->ask($request->prompt, [
            'language' => $request->language ?? $user?->settings?->language ?? 'en',
            'user_id'  => $user?->id,
        ]);

        return response()->json($result);
    }

    /**
     * POST /api/ai/summarize
     */
    public function summarize(Request $request)
    {
        $request->validate(['text' => ['required', 'string', 'max:20000']]);

        $result = $this->router->ask($request->text, [
            'system' => 'Summarize the following school content into clear, short bullet points that a student can quickly review. Keep only the key facts and ideas.',
            'user_id' => $request->user()->id,
        ]);

        return response()->json($result);
    }

    /**
     * POST /api/ai/translate
     */
    public function translate(Request $request)
    {
        $request->validate([
            'text' => ['required', 'string', 'max:5000'],
            'target_language' => ['required', 'in:en,am'],
        ]);

        $targetName = $request->target_language === 'am' ? 'Amharic' : 'English';

        $result = $this->router->ask($request->text, [
            'system' => "Translate the following text to {$targetName}. Only return the translation, nothing else.",
            'user_id' => $request->user()->id,
        ]);

        return response()->json($result);
    }

    /**
     * POST /api/ai/quiz
     * Auto-generates quiz questions in JSON, ready to save via QuizController.
     */
    public function generateQuiz(Request $request)
    {
        $request->validate([
            'topic' => ['required', 'string', 'max:500'],
            'question_count' => ['nullable', 'integer', 'min:1', 'max:20'],
            'question_type' => ['nullable', 'in:multiple_choice,true_false,fill_blank,essay,mixed'],
        ]);

        $count = $request->question_count ?? 5;
        $type = $request->question_type ?? 'mixed';

        $prompt = "Create {$count} quiz questions about: {$request->topic}. "
            . "Question type(s): {$type}. "
            . 'Respond ONLY with valid JSON, no markdown, no explanation, in exactly this shape: '
            . '[{"question_type":"multiple_choice","question_text":"...","options":["A","B","C","D"],"correct_answer":"A","points":1,"explanation":"..."}]. '
            . 'For true_false use options ["True","False"]. For fill_blank and essay, options should be null.';

        $result = $this->router->ask($prompt, [
            'system' => 'You are a quiz question generator for an Ethiopian school platform. Always respond with valid, parseable JSON only.',
            'user_id' => $request->user()->id,
        ]);

        if ($result['success']) {
            $result['questions'] = $this->tryParseJson($result['response']);
        }

        return response()->json($result);
    }

    /**
     * POST /api/ai/assignment
     * Generates a homework/assignment description for a teacher to review and post.
     */
    public function generateAssignment(Request $request)
    {
        $request->validate([
            'topic' => ['required', 'string', 'max:500'],
            'grade_level' => ['nullable', 'string', 'max:100'],
        ]);

        $gradeContext = $request->grade_level ? " for {$request->grade_level} students" : '';

        $prompt = "Write a homework assignment prompt about: {$request->topic}{$gradeContext}. "
            . 'Include a short title, clear instructions, and what students should submit. Keep it concise and age-appropriate.';

        $result = $this->router->ask($prompt, [
            'system' => 'You are an assignment writer for an Ethiopian school platform.',
            'user_id' => $request->user()->id,
        ]);

        return response()->json($result);
    }

    /**
     * GET /api/ai/providers  (admin only - see routes/api.php gate)
     */
    public function providerStatus(Request $request)
    {
        $providers = AiProvider::orderBy('priority')->get()->map(function ($provider) {
            $today = Carbon::now()->toDateString();
            $usage = AiUsage::where('provider', $provider->name)->where('date', $today)->first();

            return [
                'name' => $provider->name,
                'display_name' => $provider->display_name,
                'is_active' => $provider->is_active,
                'priority' => $provider->priority,
                'daily_limit' => $provider->daily_limit,
                'used_today' => $usage->request_count ?? 0,
                'remaining_today' => max(0, $provider->daily_limit - ($usage->request_count ?? 0)),
            ];
        });

        return response()->json(['success' => true, 'data' => ['providers' => $providers]]);
    }

    /**
     * GET /api/ai/usage  (admin only)
     */
    public function usageStats(Request $request)
    {
        $days = (int) $request->input('days', 30);

        $usage = AiUsage::where('date', '>=', Carbon::now()->subDays($days))
            ->orderBy('date', 'desc')
            ->get()
            ->groupBy('provider');

        return response()->json(['success' => true, 'data' => ['usage_by_provider' => $usage]]);
    }

    private function tryParseJson(string $raw): ?array
    {
        // Models sometimes wrap JSON in ```json fences despite instructions - strip them defensively.
        $clean = preg_replace('/^```json\s*|\s*```$/m', '', trim($raw));
        $decoded = json_decode($clean, true);

        return json_last_error() === JSON_ERROR_NONE ? $decoded : null;
    }
}
