<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;
use Illuminate\Notifications\Messages\MailMessage;

class PasswordResetNotification extends Notification
{
    use Queueable;

    public function __construct(protected string $token) {}

    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        return (new MailMessage)
            ->subject('Reset your EduLink password')
            ->greeting("Hello {$notifiable->first_name},")
            ->line('Use the code below to reset your password.')
            ->line("Your reset code: {$this->token}")
            ->line('This code expires in 30 minutes.')
            ->line('If you did not request a password reset, no action is needed.');
    }
}
