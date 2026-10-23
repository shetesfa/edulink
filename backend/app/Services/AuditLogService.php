<?php

namespace App\Services;

use App\Models\User;
use App\Models\AuditLog;
use Illuminate\Http\Request;

class AuditLogService
{
    public function log(User $actor, string $action, ?string $targetType = null, ?int $targetId = null, array $details = [], ?Request $request = null): AuditLog
    {
        return AuditLog::create([
            'user_id' => $actor->id,
            'action' => $action,
            'target_type' => $targetType,
            'target_id' => $targetId,
            'details' => $details,
            'ip_address' => $request?->ip(),
        ]);
    }
}
