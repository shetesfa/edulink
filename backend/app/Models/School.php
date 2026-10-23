<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class School extends Model
{
    protected $fillable = [
        'name', 'slug', 'description', 'logo', 'cover_photo', 'address',
        'city', 'country', 'phone', 'email', 'website', 'is_active',
        'max_students', 'plan',
    ];

    protected $casts = [
        'is_active' => 'boolean',
    ];

    public function users()
    {
        return $this->hasMany(User::class);
    }
}
