<?php

return [
    // ── Google OAuth ──────────────────────────────────────────
    'google' => [
        'client_id'     => env('GOOGLE_CLIENT_ID', '264019535722-fg4ic8fo6b15uj6na9s5ijtcrgais7t4.apps.googleusercontent.com'),
        'client_secret' => env('GOOGLE_CLIENT_SECRET', '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'),
        'redirect'      => env('GOOGLE_REDIRECT_URI', 'https://edulink-backend-jxd2.onrender.com/api/auth/google/callback'),
    ],

    // ── AI Providers ──────────────────────────────────────────
    'gemini' => [
        'api_key' => env('GEMINI_API_KEY'),
        'model'   => env('GEMINI_MODEL', 'gemini-flash-latest'),
    ],
    'groq' => [
        'api_key' => env('GROQ_API_KEY'),
        'model'   => env('GROQ_MODEL', 'llama-3.1-8b-instant'),
    ],
    'cohere' => [
        'api_key' => env('COHERE_API_KEY'),
        'model'   => env('COHERE_MODEL', 'command-a-03-2025'),
    ],
    'mistral' => [
        'api_key' => env('MISTRAL_API_KEY'),
        'model'   => env('MISTRAL_MODEL', 'open-mistral-7b'),
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
