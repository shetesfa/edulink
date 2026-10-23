<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;
use Illuminate\Notifications\Messages\MailMessage;

class OtpNotification extends Notification
{
    use Queueable;

    public function __construct(
        protected string $otp,
        protected string $purpose = 'login' // login | verify_email
    ) {}

    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        $title = $this->purpose === 'verify_email'
            ? 'Verify your EduLink email'
            : 'Your EduLink login code';

        return (new MailMessage)
            ->subject($title)
            ->greeting("Hello {$notifiable->first_name},")
            ->line($this->purpose === 'verify_email'
                ? 'Use the code below to verify your email address.'
                : 'Use the code below to log in to EduLink.')
            ->line("Your code: {$this->otp}")
            ->line('This code expires in 10 minutes.')
            ->line('If you did not request this, you can safely ignore this email.');
    }
}
