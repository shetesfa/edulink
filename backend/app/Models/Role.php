<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Role extends Model
{
    public $timestamps = true;
    protected $fillable = ['name'];

    public function users()
    {
        return $this->hasMany(User::class);
    }

    // Convenience constants matching the seeded role IDs
    const GUEST = 1;
    const STUDENT = 2;
    const TEACHER = 3;
    const SCHOOL_ADMIN = 4;
    const SUPER_ADMIN = 5;
}
