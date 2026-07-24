<?php

use Illuminate\Support\Facades\Route;

// Health check
Route::get('/', fn() => response()->json(['status' => 'ok', 'app' => 'EduLink API', 'version' => '1.0']));

