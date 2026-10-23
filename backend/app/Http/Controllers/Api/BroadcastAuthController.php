<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Broadcast;

class BroadcastAuthController extends Controller
{
    /**
     * Token-based (Sanctum) equivalent of Laravel's default broadcasting
     * auth route, which normally only works with cookie/session auth.
     * The Flutter app calls this (with its Bearer token) before it's
     * allowed to listen on a private Reverb channel.
     */
    public function authenticate(Request $request)
    {
        return Broadcast::auth($request);
    }
}
