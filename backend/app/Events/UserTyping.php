<?php

namespace App\Events;

use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;

class UserTyping implements ShouldBroadcast
{
    use Dispatchable;

    public function __construct(
        public int $userId,
        public string $userName,
        public ?int $receiverId = null,
        public ?int $groupId = null,
    ) {}

    public function broadcastOn(): array
    {
        if ($this->groupId) {
            return [new PrivateChannel("group.{$this->groupId}")];
        }

        return [new PrivateChannel("chat.{$this->receiverId}")];
    }

    public function broadcastAs(): string
    {
        return 'user.typing';
    }

    public function broadcastWith(): array
    {
        return ['user_id' => $this->userId, 'user_name' => $this->userName];
    }
}
