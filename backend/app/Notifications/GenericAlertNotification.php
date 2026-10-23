<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;
use Illuminate\Notifications\Messages\MailMessage;

class GenericAlertNotification extends Notification
{
    use Queueable;

    public function __construct(
        protected string $emailTitle,
        protected string $emailBody,
        protected ?string $actionUrl = null,
        protected ?string $actionText = null,
    ) {}

    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        $mail = (new MailMessage)
            ->subject($this->emailTitle)
            ->greeting("Hello {$notifiable->first_name},")
            ->line($this->emailBody);

        if ($this->actionUrl) {
            $mail->action($this->actionText ?? 'View in EduLink', $this->actionUrl);
        }

        return $mail;
    }
}
