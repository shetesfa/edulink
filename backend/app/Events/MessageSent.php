<?php

namespace App\Events;

use App\Models\Message;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MessageSent implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(public Message $message) {}

    public function broadcastOn(): array
    {
        if ($this->message->group_id) {
            return [new PrivateChannel("group.{$this->message->group_id}")];
        }

        // Private 1-to-1 chat: broadcast to both sender and receiver channels
        return [
            new PrivateChannel("chat.{$this->message->sender_id}"),
            new PrivateChannel("chat.{$this->message->receiver_id}"),
        ];
    }

    public function broadcastAs(): string
    {
        return 'message.sent';
    }

    public function broadcastWith(): array
    {
        return ['message' => $this->message->load('sender', 'replyTo', 'files')];
    }
}
