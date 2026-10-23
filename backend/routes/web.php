<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->json(['app' => 'EduLink API', 'status' => 'running']);
});
