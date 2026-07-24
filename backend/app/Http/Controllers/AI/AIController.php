<?php

namespace App\Http\Controllers\AI;

use App\Http\Controllers\Controller;
use App\Services\AIRouterService;
use App\Models\Lesson;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class AIController extends Controller
{
    public function __construct(private AIRouterService $ai) {}

    // ─── General ask ─────────────────────────────────────────────
    public function ask(Request $request): JsonResponse
    {
        $request->validate([
            'prompt'   => 'required|string|max:4000',
            'language' => 'nullable|in:en,am',
            'context'  => 'nullable|array',
        ]);

        $result = $this->ai->ask($request->prompt, [
            'language' => $request->language ?? 'en',
            'context'  => $request->context ?? [],
        ]);

        return response()->json($result);
    }

    // ─── Generate quiz from lesson ────────────────────────────────
    public function generateQuiz(Request $request): JsonResponse
    {
        $request->validate([
            'lesson_id'   => 'required_without:content|exists:lessons,id',
            'content'     => 'required_without:lesson_id|string|max:8000',
            'count'       => 'integer|min:1|max:30',
            'type'        => 'in:mixed,multiple_choice,true_false,fill_blank',
        ]);

        $content = $request->content;
        if ($request->lesson_id) {
            $lesson  = Lesson::findOrFail($request->lesson_id);
            $content = $lesson->content ?? $lesson->title . ': ' . $lesson->description;
        }

        $result = $this->ai->generateQuiz($content, $request->count ?? 10, $request->type ?? 'mixed');

        return response()->json($result);
    }

    // ─── Summarize lesson ─────────────────────────────────────────
    public function summarize(Request $request): JsonResponse
    {
        $request->validate([
            'lesson_id' => 'required_without:content|exists:lessons,id',
            'content'   => 'required_without:lesson_id|string|max:10000',
            'language'  => 'nullable|in:en,am',
        ]);

        $content = $request->content;
        if ($request->lesson_id) {
            $lesson  = Lesson::findOrFail($request->lesson_id);
            $content = $lesson->content ?? $lesson->description;
        }

        $result = $this->ai->summarizeLesson($content, $request->language ?? 'en');

        return response()->json($result);
    }

    // ─── Translate to Amharic ─────────────────────────────────────
    public function translate(Request $request): JsonResponse
    {
        $request->validate([
            'content'     => 'required|string|max:8000',
            'target_lang' => 'in:am,en',
        ]);

        if (($request->target_lang ?? 'am') === 'am') {
            $result = $this->ai->translateToAmharic($request->content);
        } else {
            $result = $this->ai->ask("Translate this Amharic text to English:\n\n" . $request->content);
        }

        return response()->json($result);
    }

    // ─── Generate assignment ──────────────────────────────────────
    public function generateAssignment(Request $request): JsonResponse
    {
        $request->validate([
            'topic'       => 'required|string|max:500',
            'grade_level' => 'nullable|string|max:50',
            'count'       => 'integer|min:1|max:20',
        ]);

        $result = $this->ai->generateAssignment(
            $request->topic,
            $request->grade_level ?? 'high school',
            $request->count ?? 5
        );

        return response()->json($result);
    }

    // ─── Explain concept ──────────────────────────────────────────
    public function explain(Request $request): JsonResponse
    {
        $request->validate([
            'concept'  => 'required|string|max:500',
            'level'    => 'nullable|in:simple,normal,advanced',
            'language' => 'nullable|in:en,am',
        ]);

        $level = $request->level ?? 'normal';
        $levelMap = [
            'simple'   => 'Explain this to a 10-year-old using simple words and fun examples:',
            'normal'   => 'Explain this clearly to a high school student with examples:',
            'advanced' => 'Provide a thorough academic explanation with depth:',
        ];

        $prompt = $levelMap[$level] . "\n\n" . $request->concept;

        $result = $this->ai->ask($prompt, ['language' => $request->language ?? 'en']);

        return response()->json($result);
    }

    // ─── Provider status (admin only) ────────────────────────────
    public function providerStatus(Request $request): JsonResponse
    {
        if ($request->user()->role->name !== 'school_admin') {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }

        return response()->json([
            'success'   => true,
            'providers' => $this->ai->getProviderStatus(),
        ]);
    }
}
