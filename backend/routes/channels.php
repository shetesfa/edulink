<?php

use Illuminate\Support\Facades\Broadcast;
use App\Models\GroupChat;

/*
|--------------------------------------------------------------------------
| Broadcast Channels
|--------------------------------------------------------------------------
| These control who is allowed to LISTEN to realtime events over Reverb.
| Without this, anyone could eavesdrop on any chat channel.
*/

// A user may only listen on their own private chat channel
Broadcast::channel('chat.{userId}', function ($user, $userId) {
    return (int) $user->id === (int) $userId;
});

// A user may only listen on a group channel if they are a member of that group
Broadcast::channel('group.{groupId}', function ($user, $groupId) {
    return GroupChat::find($groupId)?->members()->where('users.id', $user->id)->exists() ?? false;
});

// A user may only listen to their own notification badge updates
Broadcast::channel('notifications.{userId}', function ($user, $userId) {
    return (int) $user->id === (int) $userId;
});
