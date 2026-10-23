<?php

namespace App\Services;

use App\Models\User;
use App\Models\AppNotification;
use App\Notifications\GenericAlertNotification;
use App\Events\NotificationCreated;
use Illuminate\Support\Collection;

class NotificationDispatchService
{
    public function __construct(private PushNotificationService $push) {}

    /**
     * Notify a single user: creates the in-app record, pushes it live over
     * Reverb for the notification bell/badge, and queues an email IF the
     * user has email notifications enabled in their settings.
     */
    public function notifyUser(User $user, array $data): AppNotification
    {
        $settings = $user->settings;

        if ($settings && !$settings->notifications_enabled) {
            // User turned off in-app notifications entirely - still return
            // a lightweight unsaved instance so callers don't need null checks,
            // but nothing is persisted or sent.
            return new AppNotification($data);
        }

        $notification = AppNotification::create([
            'user_id' => $user->id,
            'type' => $data['type'],
            'title' => $data['title'],
            'body' => $data['body'] ?? null,
            'icon' => $data['icon'] ?? 'bell',
            'related_type' => $data['related_type'] ?? null,
            'related_id' => $data['related_id'] ?? null,
            'action_url' => $data['action_url'] ?? null,
        ]);

        // Notifications are helpful, but they must never prevent the main
        // action (publishing a lesson, assignment, quiz or announcement) from
        // succeeding when Reverb is offline.
        try {
            broadcast(new NotificationCreated($notification))->toOthers();
        } catch (\Throwable $e) {
            \Log::warning('Realtime notification failed.', ['error' => $e->getMessage()]);
        }

        // This is the part that reaches a user even when the app is fully
        // closed - the in-app bell and Reverb badge above only work while
        // the app is open.
        try {
            $this->push->sendToUser($user, $data['title'], $data['body'] ?? '', [
                'type' => $data['type'],
                'related_type' => $data['related_type'] ?? '',
                'related_id' => (string) ($data['related_id'] ?? ''),
                'action_url' => $data['action_url'] ?? '',
            ]);
        } catch (\Throwable $e) {
            \Log::warning('Push notification failed.', ['error' => $e->getMessage()]);
        }

        if ((!$settings || $settings->email_notifications) && !empty($data['email_body'])) {
            // SMTP may take a long time to time out on a school network.
            // Deliver mail only after the API response has already reached
            // the teacher, so publishing never appears to be stuck.
            $userId = $user->id;
            $title = $data['title'];
            $emailBody = $data['email_body'];
            $actionUrl = $data['action_url'] ?? null;
            dispatch(function () use ($userId, $title, $emailBody, $actionUrl) {
                try {
                    $recipient = User::find($userId);
                    $recipient?->notify(new GenericAlertNotification($title, $emailBody, $actionUrl));
                } catch (\Throwable $e) {
                    \Log::warning('Email notification failed.', [
                        'user_id' => $userId,
                        'error' => $e->getMessage(),
                    ]);
                }
            })->afterResponse();
        }

        return $notification;
    }

    /**
     * Notify many users at once (e.g. every student enrolled in a class).
     */
    public function notifyMany(Collection $users, array $data): void
    {
        foreach ($users as $user) {
            $this->notifyUser($user, $data);
        }
    }
}
