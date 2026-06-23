<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class CheckRole
{
    public function handle(Request $request, Closure $next, string ...$roles): mixed
    {
        $user = $request->user();

        if (!$user) {
            return response()->json(['success' => false, 'message' => 'Unauthenticated.'], 401);
        }

        $userRole = $user->role?->name ?? '';

        if (!in_array($userRole, $roles)) {
            return response()->json(['success' => false, 'message' => 'Forbidden. Insufficient permissions.'], 403);
        }

        return $next($request);
    }
}
