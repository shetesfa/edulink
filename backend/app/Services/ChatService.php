<?php

namespace App\Services;

use App\Models\Message;
use App\Events\MessageSent;
use Illuminate\Http\Request;

class ChatService
{
    public function __construct(private FileUploadService $fileUploadService) {}

    /**
     * Create a message, but if a message with this client_message_id already
     * exists (e.g. the Flutter app retried sending after regaining internet),
     * return the ORIGINAL instead of creating a duplicate. This makes sending
     * safe to retry blindly, which is exactly what an offline-first client needs.
     */
    public function send(Request $request, int $senderId, ?int $receiverId, ?int $groupId): Message
    {
        $existing = Message::where('client_message_id', $request->client_message_id)->first();
        if ($existing) {
            return $existing;
        }

        $message = Message::create([
            'sender_id' => $senderId,
            'receiver_id' => $receiverId,
            'group_id' => $groupId,
            'reply_to_id' => $request->reply_to_id,
            'message_type' => $request->message_type ?? 'text',
            'body' => $request->body,
            'client_message_id' => $request->client_message_id,
        ]);

        if ($request->hasFile('attachments')) {
            $files = is_array($request->file('attachments')) ? $request->file('attachments') : [$request->file('attachments')];
            foreach ($files as $file) {
                if ($file) {
                    try {
                        $this->fileUploadService->store($file, $senderId, 'message', $message->id, false);
                    } catch (\Throwable $e) {
                        \Log::warning("Chat attachment upload failed: " . $e->getMessage());
                    }
                }
            }
        }

        broadcast(new MessageSent($message))->toOthers();

        return $message->fresh(['sender', 'replyTo', 'files']);
    }
}
