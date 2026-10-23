<?php

namespace App\Services;

use App\Models\User;
use App\Models\DeviceToken;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class PushNotificationService
{
    /**
     * Sends a real push notification to every device a user is logged in
     * on. Uses FCM's legacy HTTP API (simplest to set up - just one server
     * key, no service-account JSON needed). If you later want the newer
     * FCM v1 API, swap the endpoint/auth here; nothing else changes.
     */
    public function sendToUser(User $user, string $title, string $body, array $data = []): void
    {
        $serverKey = config('services.fcm.server_key');
        if (empty($serverKey)) {
            return; // push not configured yet - silently skip, in-app/email notifications still work
        }

        $tokens = DeviceToken::where('user_id', $user->id)->pluck('token');
        if ($tokens->isEmpty()) {
            return;
        }

        try {
            Http::withHeaders([
                'Authorization' => "key={$serverKey}",
                'Content-Type' => 'application/json',
            ])->timeout(10)->post('https://fcm.googleapis.com/fcm/send', [
                'registration_ids' => $tokens->values()->all(),
                'notification' => [
                    'title' => $title,
                    'body' => $body,
                    'sound' => 'default',
                ],
                'data' => $data,
                'priority' => 'high',
            ]);
        } catch (\Exception $e) {
            Log::warning('Push notification failed: ' . $e->getMessage());
        }
    }
}
