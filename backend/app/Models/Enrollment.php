<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Enrollment extends Model
{
    protected $fillable = [
        'class_id', 'student_id', 'joined_at', 'is_class_leader',
        'is_banned', 'progress_percent',
    ];

    protected $casts = [
        'joined_at' => 'datetime',
        'is_class_leader' => 'boolean',
        'is_banned' => 'boolean',
    ];

    public function schoolClass()
    {
        return $this->belongsTo(SchoolClass::class, 'class_id');
    }

    public function student()
    {
        return $this->belongsTo(User::class, 'student_id');
    }
}
