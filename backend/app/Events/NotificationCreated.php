<?php

namespace App\Events;

use App\Models\AppNotification;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;

class NotificationCreated implements ShouldBroadcast
{
    use Dispatchable;

    public function __construct(public AppNotification $notification) {}

    public function broadcastOn(): array
    {
        return [new PrivateChannel("notifications.{$this->notification->user_id}")];
    }

    public function broadcastAs(): string
    {
        return 'notification.created';
    }

    public function broadcastWith(): array
    {
        return ['notification' => $this->notification];
    }
}
