<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

// Named AppNotification (table "notifications") to avoid any confusion with
// Illuminate's own Notification base class used for Mailables in Stage 1.
class AppNotification extends Model
{
    protected $table = 'notifications';

    protected $fillable = [
        'user_id', 'type', 'title', 'body', 'icon', 'related_type',
        'related_id', 'action_url', 'is_read',
    ];

    protected $casts = [
        'is_read' => 'boolean',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
