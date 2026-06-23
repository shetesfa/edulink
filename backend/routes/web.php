<?php

use Illuminate\Support\Facades\Route;

// Health check
Route::get('/', fn() => response()->json(['status' => 'ok', 'app' => 'EduLink API', 'version' => '1.0']));

// Google OAuth callback redirect
Route::get('/api/auth/google/callback', [\App\Http\Controllers\Auth\AuthController::class, 'googleCallback']);
