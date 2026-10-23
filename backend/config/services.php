<?php

// NOTE: This file only lists the EduLink-specific additions.
// When you scaffold the base Laravel project (see README.md), merge these
// entries into the `services.php` that Laravel generates for you - don't
// just overwrite it, since Laravel's default file has entries (postmark,
// resend, slack) you'll likely want to keep too.

return [

    'google' => [
        'client_id' => env('GOOGLE_CLIENT_ID'),
        'client_secret' => env('GOOGLE_CLIENT_SECRET'),
        'redirect' => env('GOOGLE_REDIRECT_URI'),
    ],

    // Added in a later stage (AI assistant) - listed now so .env is ready
    'gemini' => [
        'api_key' => env('GEMINI_API_KEY'),
        'model' => env('GEMINI_MODEL', 'gemini-1.5-flash'),
    ],
    'groq' => [
        'api_key' => env('GROQ_API_KEY'),
        'model' => env('GROQ_MODEL', 'llama-3.1-8b-instant'),
    ],
    'cohere' => [
        'api_key' => env('COHERE_API_KEY'),
        'model' => env('COHERE_MODEL', 'command-r'),
    ],
    'mistral' => [
        'api_key' => env('MISTRAL_API_KEY'),
        'model' => env('MISTRAL_MODEL', 'mistral-small-latest'),
    ],
    'huggingface' => [
        'api_key' => env('HUGGINGFACE_API_KEY'),
        'model' => env('HUGGINGFACE_MODEL', 'mistralai/Mistral-7B-Instruct-v0.2'),
    ],

    // Added in the Meetings stage. Default (meet.jit.si) needs no JWT/secret -
    // only fill app_id/app_secret if you switch to a self-hosted, JWT-secured
    // Jitsi instance.
    'jitsi' => [
        'domain' => env('JITSI_DOMAIN', 'meet.jit.si'),
        'app_id' => env('JITSI_APP_ID'),
        'app_secret' => env('JITSI_APP_SECRET'),
    ],

    // Real push notifications (reaches a closed app) - get this key from
    // Firebase Console > Project Settings > Cloud Messaging > Server key
    'fcm' => [
        'server_key' => env('FCM_SERVER_KEY'),
    ],

];
