<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AiProvider extends Model
{
    protected $fillable = [
        'name', 'display_name', 'model_name', 'daily_limit', 'is_active', 'priority',
    ];

    protected $casts = ['is_active' => 'boolean'];
}
