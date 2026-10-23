<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class EnsureUserIsActive
{
    public function handle(Request $request, Closure $next)
    {
        $user = $request->user();

        if (!$user || !$user->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'This account is inactive. Please contact your school admin.',
            ], 403);
        }

        return $next($request);
    }
}
