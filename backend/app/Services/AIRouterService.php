<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use App\Models\AiUsage;

/**
 * AIRouterService
 *
 * Manages a pool of 6 free AI providers.
 * Automatically rotates when one hits its daily limit.
 * Students NEVER see "AI unavailable" — there is always a fallback.
 *
 * Provider priority order:
 *   1. Gemini      (1,500 req/day  — fastest, best quality)
 *   2. Groq        (14,400 req/day — ultra fast Llama 3)
 *   3. Cohere      (1,000 req/day  — good reasoning)
 *   4. Mistral     (1,000 req/day  — solid performance)
 *   5. Together AI (1,000 req/day  — many models)
 *   6. HuggingFace (unlimited      — always available fallback)
 */
class AIRouterService
{
    /**
     * Provider definitions — order = priority
     */
    private array $providers = [
        'gemini' => [
            'name'        => 'Google Gemini',
            'daily_limit' => 1500,
            'handler'     => 'callGemini',
        ],
        'groq' => [
            'name'        => 'Groq (Llama 3)',
            'daily_limit' => 14400,
            'handler'     => 'callGroq',
        ],
        'cohere' => [
            'name'        => 'Cohere',
            'daily_limit' => 1000,
            'handler'     => 'callCohere',
        ],
        'mistral' => [
            'name'        => 'Mistral AI',
            'daily_limit' => 1000,
            'handler'     => 'callMistral',
        ],
        'together' => [
            'name'        => 'Together AI',
            'daily_limit' => 1000,
            'handler'     => 'callTogether',
        ],
        'huggingface' => [
            'name'        => 'HuggingFace',
            'daily_limit' => 999999,  // effectively unlimited
            'handler'     => 'callHuggingFace',
        ],
    ];

    /**
     * Main entry point: send a prompt, get a response.
     * Tries providers in priority order. Auto-failover on any error.
     */
    public function ask(string $prompt, array $options = []): array
    {
        $systemPrompt = $options['system'] ?? $this->getDefaultSystemPrompt();
        $context      = $options['context'] ?? [];
        $language     = $options['language'] ?? 'en';

        // Prepend language instruction if Amharic
        if ($language === 'am') {
            $systemPrompt = "You must respond ONLY in Amharic (አማርኛ). " . $systemPrompt;
        }

        $messages = array_merge($context, [
            ['role' => 'user', 'content' => $prompt]
        ]);

        foreach ($this->providers as $providerKey => $config) {
            // Skip if daily limit reached
            if ($this->isLimitReached($providerKey, $config['daily_limit'])) {
                Log::info("AIRouter: {$providerKey} limit reached, trying next.");
                continue;
            }

            // Skip if API key not configured
            if (!$this->isConfigured($providerKey)) {
                continue;
            }

            try {
                $handler  = $config['handler'];
                $response = $this->$handler($messages, $systemPrompt);

                if ($response) {
                    // Track usage
                    $this->trackUsage($providerKey);

                    return [
                        'success'   => true,
                        'response'  => $response,
                        'provider'  => $config['name'],
                    ];
                }
            } catch (\Exception $e) {
                Log::warning("AIRouter: {$providerKey} failed: " . $e->getMessage());
                // Continue to next provider
            }
        }

        // All providers failed — this should be extremely rare
        return [
            'success'  => false,
            'response' => 'The AI assistant is temporarily unavailable. Please try again in a moment.',
            'provider' => null,
        ];
    }

    // ─────────────────────────────────────────────────────────────
    // PROVIDER IMPLEMENTATIONS
    // ─────────────────────────────────────────────────────────────

    private function callGemini(array $messages, string $system): ?string
    {
        $key   = config('services.gemini.api_key');
        $model = config('services.gemini.model', 'gemini-1.5-flash');

        // Convert messages to Gemini format
        $contents = [];
        foreach ($messages as $msg) {
            $contents[] = [
                'role'  => $msg['role'] === 'assistant' ? 'model' : 'user',
                'parts' => [['text' => $msg['content']]],
            ];
        }

        $response = Http::timeout(30)->post(
            "https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent?key={$key}",
            [
                'system_instruction' => ['parts' => [['text' => $system]]],
                'contents'           => $contents,
                'generationConfig'   => [
                    'temperature'     => 0.7,
                    'maxOutputTokens' => 1024,
                ],
            ]
        );

        $data = $response->json();
        return $data['candidates'][0]['content']['parts'][0]['text'] ?? null;
    }

    private function callGroq(array $messages, string $system): ?string
    {
        $key   = config('services.groq.api_key');
        $model = config('services.groq.model', 'llama3-8b-8192');

        $response = Http::withToken($key)->timeout(30)->post(
            'https://api.groq.com/openai/v1/chat/completions',
            [
                'model'       => $model,
                'messages'    => array_merge(
                    [['role' => 'system', 'content' => $system]],
                    $messages
                ),
                'temperature' => 0.7,
                'max_tokens'  => 1024,
            ]
        );

        $data = $response->json();
        return $data['choices'][0]['message']['content'] ?? null;
    }

    private function callCohere(array $messages, string $system): ?string
    {
        $key   = config('services.cohere.api_key');
        $model = config('services.cohere.model', 'command-r');

        // Cohere uses preamble + chat history format
        $chatHistory = [];
        $lastMessage = '';

        foreach ($messages as $msg) {
            if ($msg['role'] === 'user') {
                $lastMessage = $msg['content'];
            } else {
                $chatHistory[] = [
                    'role'    => 'CHATBOT',
                    'message' => $msg['content'],
                ];
            }
        }

        $response = Http::withToken($key)->timeout(30)->post(
            'https://api.cohere.com/v1/chat',
            [
                'model'        => $model,
                'preamble'     => $system,
                'chat_history' => $chatHistory,
                'message'      => $lastMessage,
            ]
        );

        $data = $response->json();
        return $data['text'] ?? null;
    }

    private function callMistral(array $messages, string $system): ?string
    {
        $key   = config('services.mistral.api_key');
        $model = config('services.mistral.model', 'mistral-small-latest');

        $response = Http::withToken($key)->timeout(30)->post(
            'https://api.mistral.ai/v1/chat/completions',
            [
                'model'       => $model,
                'messages'    => array_merge(
                    [['role' => 'system', 'content' => $system]],
                    $messages
                ),
                'temperature' => 0.7,
                'max_tokens'  => 1024,
            ]
        );

        $data = $response->json();
        return $data['choices'][0]['message']['content'] ?? null;
    }

    private function callTogether(array $messages, string $system): ?string
    {
        $key   = config('services.together.api_key');
        $model = config('services.together.model', 'mistralai/Mistral-7B-Instruct-v0.2');

        $response = Http::withToken($key)->timeout(45)->post(
            'https://api.together.xyz/v1/chat/completions',
            [
                'model'       => $model,
                'messages'    => array_merge(
                    [['role' => 'system', 'content' => $system]],
                    $messages
                ),
                'temperature' => 0.7,
                'max_tokens'  => 1024,
            ]
        );

        $data = $response->json();
        return $data['choices'][0]['message']['content'] ?? null;
    }

    private function callHuggingFace(array $messages, string $system): ?string
    {
        $key   = config('services.huggingface.api_key');
        $model = config('services.huggingface.model', 'mistralai/Mistral-7B-Instruct-v0.2');

        // Build a single prompt for HuggingFace inference API
        $prompt = "<s>[INST] <<SYS>>\n{$system}\n<</SYS>>\n\n";
        foreach ($messages as $i => $msg) {
            if ($msg['role'] === 'user') {
                $prompt .= $msg['content'] . " [/INST] ";
            } else {
                $prompt .= $msg['content'] . " </s><s>[INST] ";
            }
        }

        $response = Http::withToken($key)->timeout(60)->post(
            "https://api-inference.huggingface.co/models/{$model}",
            [
                'inputs'     => $prompt,
                'parameters' => [
                    'max_new_tokens' => 512,
                    'temperature'    => 0.7,
                    'return_full_text' => false,
                ],
            ]
        );

        $data = $response->json();
        if (is_array($data) && isset($data[0]['generated_text'])) {
            return trim($data[0]['generated_text']);
        }

        return null;
    }

    // ─────────────────────────────────────────────────────────────
    // SPECIALIZED AI FUNCTIONS
    // ─────────────────────────────────────────────────────────────

    /**
     * Generate quiz questions from lesson content
     */
    public function generateQuiz(string $lessonContent, int $count = 10, string $type = 'mixed'): array
    {
        $prompt = "Generate {$count} quiz questions from the following lesson content.
Return ONLY valid JSON in this exact format:
{
  \"questions\": [
    {
      \"type\": \"multiple_choice\",
      \"question\": \"Question text here?\",
      \"options\": [\"A. Option 1\", \"B. Option 2\", \"C. Option 3\", \"D. Option 4\"],
      \"correct\": \"A\",
      \"explanation\": \"Why A is correct\"
    }
  ]
}

Types to include: multiple_choice, true_false, fill_blank.

LESSON CONTENT:
{$lessonContent}";

        $result = $this->ask($prompt, [
            'system' => 'You are an expert teacher who creates clear, educational quiz questions. Always return valid JSON only.',
        ]);

        if ($result['success']) {
            try {
                // Extract JSON from response
                $json = $result['response'];
                $json = preg_replace('/```json\s*|\s*```/', '', $json);
                $parsed = json_decode(trim($json), true);
                if ($parsed && isset($parsed['questions'])) {
                    return ['success' => true, 'questions' => $parsed['questions']];
                }
            } catch (\Exception $e) {
                // Return as text if JSON parsing fails
            }
        }

        return ['success' => false, 'questions' => []];
    }

    /**
     * Summarize a lesson for students
     */
    public function summarizeLesson(string $content, string $language = 'en'): array
    {
        $prompt = "Summarize this lesson in a clear, student-friendly way with:
- A brief overview (2-3 sentences)
- Key points (bullet list, max 8 points)
- Important terms to remember

LESSON: {$content}";

        return $this->ask($prompt, ['language' => $language]);
    }

    /**
     * Generate assignment from chapter
     */
    public function generateAssignment(string $topic, string $gradeLevel, int $questionCount = 5): array
    {
        $prompt = "Create a homework assignment for {$gradeLevel} students about: {$topic}

Include {$questionCount} questions of varying difficulty.
Format as clear numbered questions a student can answer in writing.
Include estimated completion time at the top.";

        return $this->ask($prompt, [
            'system' => 'You are a professional teacher creating educational assignments.',
        ]);
    }

    /**
     * Translate lesson content to Amharic
     */
    public function translateToAmharic(string $content): array
    {
        return $this->ask($content, [
            'system'   => 'You are a professional translator. Translate the following educational content to Amharic (አማርኛ). Keep technical terms in English where appropriate, but translate the explanations.',
            'language' => 'am',
        ]);
    }

    // ─────────────────────────────────────────────────────────────
    // USAGE TRACKING & LIMIT CHECKING
    // ─────────────────────────────────────────────────────────────

    private function isLimitReached(string $provider, int $limit): bool
    {
        $today = now()->toDateString();
        $cacheKey = "ai_usage_{$provider}_{$today}";
        $count = Cache::get($cacheKey, 0);
        return $count >= $limit;
    }

    private function trackUsage(string $provider): void
    {
        $today    = now()->toDateString();
        $cacheKey = "ai_usage_{$provider}_{$today}";

        // Increment in cache (fast)
        $count = Cache::increment($cacheKey);
        if ($count === 1) {
            // Set expiry to end of day + 1 hour buffer
            Cache::put($cacheKey, 1, now()->endOfDay()->addHour());
        }

        // Also save to DB asynchronously (for analytics)
        dispatch(function () use ($provider, $today) {
            AiUsage::updateOrCreate(
                ['provider' => $provider, 'date' => $today],
                ['request_count' => \DB::raw('request_count + 1')]
            );
        })->afterResponse();
    }

    private function isConfigured(string $provider): bool
    {
        $keyMap = [
            'gemini'      => 'services.gemini.api_key',
            'groq'        => 'services.groq.api_key',
            'cohere'      => 'services.cohere.api_key',
            'mistral'     => 'services.mistral.api_key',
            'together'    => 'services.together.api_key',
            'huggingface' => 'services.huggingface.api_key',
        ];

        $key = config($keyMap[$provider] ?? '');
        return !empty($key) && !str_starts_with($key, 'YOUR_');
    }

    /**
     * Get status of all providers (for admin panel)
     */
    public function getProviderStatus(): array
    {
        $today    = now()->toDateString();
        $statuses = [];

        foreach ($this->providers as $key => $config) {
            $cacheKey = "ai_usage_{$key}_{$today}";
            $used     = Cache::get($cacheKey, 0);

            $statuses[] = [
                'provider'    => $key,
                'name'        => $config['name'],
                'configured'  => $this->isConfigured($key),
                'used_today'  => $used,
                'daily_limit' => $config['daily_limit'],
                'available'   => !$this->isLimitReached($key, $config['daily_limit']),
                'percent_used' => $config['daily_limit'] > 0
                    ? round(($used / $config['daily_limit']) * 100, 1)
                    : 0,
            ];
        }

        return $statuses;
    }

    private function getDefaultSystemPrompt(): string
    {
        return "You are EduLink's AI Study Assistant — a helpful, encouraging, and knowledgeable tutor for school students. 

Your personality:
- Patient and encouraging
- Clear and easy to understand
- Use examples students can relate to
- Break complex topics into simple steps
- Celebrate student curiosity

Your capabilities:
- Explain any school subject (biology, chemistry, math, history, etc.)
- Summarize lessons and chapters
- Generate practice questions
- Help with homework (guide, don't just give answers)
- Translate content to Amharic if requested

Always be appropriate for school-age students. Keep responses focused and educational.";
    }
}
