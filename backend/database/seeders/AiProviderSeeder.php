<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\AiProvider;

class AiProviderSeeder extends Seeder
{
    public function run(): void
    {
        $providers = [
            ['name' => 'gemini', 'display_name' => 'Google Gemini', 'model_name' => 'gemini-1.5-flash', 'daily_limit' => 1500, 'priority' => 1],
            ['name' => 'groq', 'display_name' => 'Groq (Llama 3)', 'model_name' => 'llama-3.1-8b-instant', 'daily_limit' => 14400, 'priority' => 2],
            ['name' => 'cohere', 'display_name' => 'Cohere', 'model_name' => 'command-r', 'daily_limit' => 1000, 'priority' => 3],
            ['name' => 'mistral', 'display_name' => 'Mistral AI', 'model_name' => 'mistral-small-latest', 'daily_limit' => 1000, 'priority' => 4],
            ['name' => 'huggingface', 'display_name' => 'HuggingFace', 'model_name' => 'mistralai/Mistral-7B-Instruct-v0.2', 'daily_limit' => 999999, 'priority' => 5],
        ];

        foreach ($providers as $provider) {
            AiProvider::updateOrCreate(['name' => $provider['name']], $provider);
        }
    }
}
