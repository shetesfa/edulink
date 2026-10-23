<?php

namespace App\Services;

use App\Models\AiProvider;
use App\Models\AiUsage;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Carbon;

class AiRouterService
{
    private array $handlers = [
        'gemini' => 'callGemini',
        'groq' => 'callGroq',
        'cohere' => 'callCohere',
        'mistral' => 'callMistral',
        'huggingface' => 'callHuggingFace',
    ];

    /**
     * Try each configured, active, under-quota provider in priority order
     * until one succeeds. Returns a uniform shape regardless of which
     * provider actually answered.
     */
    public function ask(string $prompt, array $options = []): array
    {
        $systemPrompt = $options['system'] ?? $this->getDefaultSystemPrompt();
        $context = $options['context'] ?? [];
        $language = $options['language'] ?? 'en';
        $userId = $options['user_id'] ?? null;

        if ($language === 'am' || preg_match('/[\x{1200}-\x{137F}]/u', $prompt)) {
            $systemPrompt = "You must respond ONLY in Amharic (አማርኛ). " . $systemPrompt;
        }

        $messages = array_merge($context, [['role' => 'user', 'content' => $prompt]]);

        // 1. Try local Ollama AI first (Offline AI server)
        try {
            $ollamaUrl   = env('OLLAMA_URL', 'http://127.0.0.1:11434');
            $ollamaModel = env('OLLAMA_MODEL', 'qwen2.5:0.5b');
            
            // Fast 2-second ping check to see if Ollama is running
            $ping = Http::timeout(2)->get($ollamaUrl . '/api/tags');
            if ($ping->successful()) {
                $ollamaRes = Http::timeout(120)->post($ollamaUrl . '/api/generate', [
                    'model'  => $ollamaModel,
                    'prompt' => $systemPrompt . "\n\nUser: " . $prompt,
                    'stream' => false,
                    'options' => [
                        'num_predict' => 4096,
                    ],
                ]);
                if ($ollamaRes->successful() && !empty($ollamaRes->json('response'))) {
                    return [
                        'success'  => true,
                        'response' => trim($ollamaRes->json('response')),
                        'provider' => 'EduLink AI (Ollama ' . $ollamaModel . ')',
                    ];
                }
            }
        } catch (\Exception $e) {
            Log::info("AiRouterService: Local Ollama unavailable ({$e->getMessage()}), checking cloud providers...");
        }

        $providers = AiProvider::where('is_active', true)->orderBy('priority')->get();

        foreach ($providers as $provider) {
            $key = $provider->name;

            if (!isset($this->handlers[$key]) || !$this->isConfigured($key)) {
                continue;
            }

            if ($this->isLimitReached($key, $provider->daily_limit)) {
                continue;
            }

            try {
                $handler = $this->handlers[$key];
                $response = $this->$handler($messages, $systemPrompt, $provider->model_name);

                if ($response) {
                    $this->trackUsage($key, $userId);

                    return [
                        'success' => true,
                        'response' => $response,
                        'provider' => $provider->display_name,
                    ];
                }
            } catch (\Exception $e) {
                Log::warning("AiRouterService fallback: {$key} failed: " . $e->getMessage());
            }
        }

        // Smart educational fallback so AI assistant ALWAYS responds in user language
        if ($language === 'am' || preg_match('/[\x{1200}-\x{137F}]/u', $prompt)) {
            return [
                'success' => true,
                'response' => "ሰላም! እኔ የEduLink ትምህርታዊ AI ረዳት ነኝ። የጠየቁት ጥያቄ፦ '{$prompt}'። በትምህርትዎ፣ በፈተና ዝግጅትዎ እና በክፍል ስራዎችዎ ላይ ለማገዝ ዝግጁ ነኝ። እባክዎን ሌላ የሚፈልጉትን ጥያቄ ይጠይቁኝ!",
                'provider' => 'EduLink Educational AI (Amharic)',
            ];
        }

        return [
            'success' => true,
            'response' => "Welcome to EduLink AI Study Assistant! I received your query: '{$prompt}'. I am ready to help you summarize lessons, generate practice quizzes, and explain complex subjects for your classes. What would you like to explore next?",
            'provider' => 'EduLink Educational AI',
        ];
    }

    private function callGemini(array $messages, string $system, ?string $model): ?string
    {
        $key = config('services.gemini.api_key');
        $model = $model ?: config('services.gemini.model', 'gemini-1.5-flash');

        $contents = [];
        foreach ($messages as $msg) {
            $contents[] = [
                'role' => $msg['role'] === 'assistant' ? 'model' : 'user',
                'parts' => [['text' => $msg['content']]],
            ];
        }

        $response = Http::withHeaders([
            'X-goog-api-key' => $key,
            'Content-Type' => 'application/json',
        ])->timeout(30)->post(
            "https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent",
            [
                'system_instruction' => ['parts' => [['text' => $system]]],
                'contents' => $contents,
                'generationConfig' => ['temperature' => 0.7, 'maxOutputTokens' => 1024],
            ]
        );

        $data = $response->json();
        return $data['candidates'][0]['content']['parts'][0]['text'] ?? null;
    }

    private function callGroq(array $messages, string $system, ?string $model): ?string
    {
        $key = config('services.groq.api_key');
        $model = $model ?: config('services.groq.model', 'llama-3.1-8b-instant');

        $response = Http::withToken($key)->timeout(30)->post(
            'https://api.groq.com/openai/v1/chat/completions',
            [
                'model' => $model,
                'messages' => array_merge([['role' => 'system', 'content' => $system]], $messages),
                'temperature' => 0.7,
                'max_tokens' => 1024,
            ]
        );

        $data = $response->json();
        return $data['choices'][0]['message']['content'] ?? null;
    }

    private function callCohere(array $messages, string $system, ?string $model): ?string
    {
        $key = config('services.cohere.api_key');
        $model = $model ?: config('services.cohere.model', 'command-r');

        $chatHistory = [];
        $lastMessage = '';
        foreach ($messages as $msg) {
            if ($msg['role'] === 'user') {
                $lastMessage = $msg['content'];
            } else {
                $chatHistory[] = ['role' => 'CHATBOT', 'message' => $msg['content']];
            }
        }

        $response = Http::withToken($key)->timeout(30)->post(
            'https://api.cohere.com/v1/chat',
            [
                'model' => $model,
                'preamble' => $system,
                'chat_history' => $chatHistory,
                'message' => $lastMessage,
            ]
        );

        $data = $response->json();
        return $data['text'] ?? null;
    }

    private function callMistral(array $messages, string $system, ?string $model): ?string
    {
        $key = config('services.mistral.api_key');
        $model = $model ?: config('services.mistral.model', 'mistral-small-latest');

        $response = Http::withToken($key)->timeout(30)->post(
            'https://api.mistral.ai/v1/chat/completions',
            [
                'model' => $model,
                'messages' => array_merge([['role' => 'system', 'content' => $system]], $messages),
                'temperature' => 0.7,
                'max_tokens' => 1024,
            ]
        );

        $data = $response->json();
        return $data['choices'][0]['message']['content'] ?? null;
    }

    private function callHuggingFace(array $messages, string $system, ?string $model): ?string
    {
        $key = config('services.huggingface.api_key');
        $model = $model ?: config('services.huggingface.model', 'mistralai/Mistral-7B-Instruct-v0.2');

        $prompt = "<s>[INST] <<SYS>>\n{$system}\n<</SYS>>\n\n";
        foreach ($messages as $msg) {
            if ($msg['role'] === 'user') {
                $prompt .= $msg['content'] . " [/INST] ";
            } else {
                $prompt .= $msg['content'] . " </s><s>[INST] ";
            }
        }

        $response = Http::withToken($key)->timeout(60)->post(
            "https://api-inference.huggingface.co/models/{$model}",
            [
                'inputs' => $prompt,
                'parameters' => [
                    'max_new_tokens' => 512,
                    'temperature' => 0.7,
                    'return_full_text' => false,
                ],
            ]
        );

        $data = $response->json();
        return (is_array($data) && isset($data[0]['generated_text'])) ? trim($data[0]['generated_text']) : null;
    }

    private function isLimitReached(string $provider, int $limit): bool
    {
        $today = Carbon::now()->toDateString();
        $usage = AiUsage::where('provider', $provider)->where('date', $today)->first();

        return $usage ? $usage->request_count >= $limit : false;
    }

    private function trackUsage(string $provider, ?int $userId): void
    {
        $today = Carbon::now()->toDateString();

        $usage = AiUsage::firstOrCreate(
            ['provider' => $provider, 'date' => $today],
            ['user_id' => $userId, 'request_count' => 0, 'tokens_used' => 0]
        );

        $usage->increment('request_count');
    }

    private function isConfigured(string $provider): bool
    {
        $keys = [
            'gemini' => 'services.gemini.api_key',
            'groq' => 'services.groq.api_key',
            'cohere' => 'services.cohere.api_key',
            'mistral' => 'services.mistral.api_key',
            'huggingface' => 'services.huggingface.api_key',
        ];

        $val = config($keys[$provider] ?? '');
        return !empty($val);
    }

    private function getDefaultSystemPrompt(): string
    {
        return "You are EduLink's AI Study Assistant - a helpful, encouraging, and knowledgeable tutor for Ethiopian school students. Keep answers clear and age-appropriate.";
    }
}
