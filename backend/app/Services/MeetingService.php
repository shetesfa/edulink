<?php

namespace App\Services;

use App\Models\User;
use App\Models\VideoMeeting;
use Firebase\JWT\JWT;

class MeetingService
{
    /**
     * Build everything the Flutter app needs to open a Jitsi call: the
     * room URL, and (only if a self-hosted secured Jitsi is configured) a
     * short-lived JWT proving who the user is. The free public meet.jit.si
     * needs neither a token nor an API key - it just works with a room name.
     */
    public function buildJoinInfo(VideoMeeting $meeting, User $user): array
    {
        $domain = config('services.jitsi.domain');
        $appId = config('services.jitsi.app_id');
        $appSecret = config('services.jitsi.app_secret');

        $info = [
            'domain' => $domain,
            'room' => $meeting->room_id,
            'meeting_url' => "https://{$domain}/{$meeting->room_id}",
            'is_moderator' => $user->id === $meeting->host_id,
            'display_name' => $user->fullName(),
        ];

        if ($appId && $appSecret && class_exists(JWT::class)) {
            $info['token'] = $this->generateJwt($meeting, $user, $appId, $appSecret);
        }

        return $info;
    }

    private function generateJwt(VideoMeeting $meeting, User $user, string $appId, string $appSecret): string
    {
        $now = time();

        $payload = [
            'iss' => $appId,
            'aud' => $appId,
            'sub' => config('services.jitsi.domain'),
            'room' => $meeting->room_id,
            'iat' => $now,
            'exp' => $now + 3600 * 4, // 4 hour token
            'context' => [
                'user' => [
                    'name' => $user->fullName(),
                    'email' => $user->email,
                    'avatar' => $user->profile_photo,
                    'moderator' => $user->id === $meeting->host_id,
                ],
            ],
        ];

        return JWT::encode($payload, $appSecret, 'HS256');
    }
}
