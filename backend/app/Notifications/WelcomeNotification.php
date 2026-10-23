<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;
use Illuminate\Notifications\Messages\MailMessage;

class WelcomeNotification extends Notification
{
    use Queueable;

    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        return (new MailMessage)
            ->subject('Welcome to EduLink!')
            ->greeting("Welcome, {$notifiable->first_name}!")
            ->line('Your EduLink account has been created successfully.')
            ->line('Please check your inbox for a verification code to activate your account.');
    }
}
