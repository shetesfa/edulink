<?php

return [
    // ── Google OAuth ──────────────────────────────────────────
    'google' => [
        'client_id'     => env('GOOGLE_CLIENT_ID'),
        'client_secret' => env('GOOGLE_CLIENT_SECRET'),
        'redirect'      => env('GOOGLE_REDIRECT_URI', '/api/auth/google/callback'),
    ],

    // ── AI Providers ──────────────────────────────────────────
    'gemini' => [
        'api_key' => env('GEMINI_API_KEY'),
        'model'   => env('GEMINI_MODEL', 'gemini-1.5-flash'),
    ],
    'groq' => [
        'api_key' => env('GROQ_API_KEY'),
        'model'   => env('GROQ_MODEL', 'llama3-8b-8192'),
    ],
    'cohere' => [
        'api_key' => env('COHERE_API_KEY'),
        'model'   => env('COHERE_MODEL', 'command-r'),
    ],
    'mistral' => [
        'api_key' => env('MISTRAL_API_KEY'),
        'model'   => env('MISTRAL_MODEL', 'mistral-small-latest'),
    ],
    'together' => [
        'api_key' => env('TOGETHER_API_KEY'),
        'model'   => env('TOGETHER_MODEL', 'mistralai/Mistral-7B-Instruct-v0.2'),
    ],
    'huggingface' => [
        'api_key' => env('HUGGINGFACE_API_KEY'),
        'model'   => env('HUGGINGFACE_MODEL', 'mistralai/Mistral-7B-Instruct-v0.2'),
    ],

    // ── Jitsi Video ───────────────────────────────────────────
    'jitsi' => [
        'app_id'     => env('JITSI_APP_ID'),
        'app_secret' => env('JITSI_APP_SECRET'),
        'domain'     => env('JITSI_DOMAIN', 'meet.jit.si'),
    ],

    // ── Firebase ──────────────────────────────────────────────
    'firebase' => [
        'credentials'  => env('FIREBASE_CREDENTIALS', storage_path('app/firebase-credentials.json')),
        'project_id'   => env('FIREBASE_PROJECT_ID'),
    ],

    // ── Mail ──────────────────────────────────────────────────
    'mailgun'  => ['domain' => env('MAILGUN_DOMAIN'), 'secret' => env('MAILGUN_SECRET'), 'endpoint' => env('MAILGUN_ENDPOINT', 'api.mailgun.net')],
    'postmark' => ['token' => env('POSTMARK_TOKEN')],
    'ses'      => ['key' => env('AWS_ACCESS_KEY_ID'), 'secret' => env('AWS_SECRET_ACCESS_KEY'), 'region' => env('AWS_DEFAULT_REGION', 'us-east-1')],
];
