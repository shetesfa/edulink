<?php

namespace App\Events;

use App\Models\Message;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MessageUpdated implements ShouldBroadcast
{
    use Dispatchable, SerializesModels;

    public function __construct(public Message $message) {}

    public function broadcastOn(): array
    {
        if ($this->message->group_id) {
            return [new PrivateChannel("group.{$this->message->group_id}")];
        }

        return [
            new PrivateChannel("chat.{$this->message->sender_id}"),
            new PrivateChannel("chat.{$this->message->receiver_id}"),
        ];
    }

    public function broadcastAs(): string
    {
        return 'message.updated';
    }

    public function broadcastWith(): array
    {
        return ['message' => $this->message];
    }
}
