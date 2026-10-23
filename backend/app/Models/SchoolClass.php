<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

// Named SchoolClass (not "Class") because `class` is a reserved word in PHP.
// The actual database table is still "classes".
class SchoolClass extends Model
{
    protected $table = 'classes';

    protected $fillable = [
        'school_id', 'grade_id', 'teacher_id', 'name', 'subject',
        'description', 'cover_photo', 'color', 'join_code', 'invite_link',
        'is_active', 'max_students', 'allow_student_chat',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'allow_student_chat' => 'boolean',
    ];

    public function school()
    {
        return $this->belongsTo(School::class);
    }

    public function grade()
    {
        return $this->belongsTo(Grade::class);
    }

    public function teacher()
    {
        return $this->belongsTo(User::class, 'teacher_id');
    }

    public function enrollments()
    {
        return $this->hasMany(Enrollment::class, 'class_id');
    }

    public function lessons()
    {
        return $this->hasMany(Lesson::class, 'class_id');
    }

    public function assignments()
    {
        return $this->hasMany(Assignment::class, 'class_id');
    }

    public function quizzes()
    {
        return $this->hasMany(Quiz::class, 'class_id');
    }

    public function announcements()
    {
        return $this->hasMany(Announcement::class, 'class_id');
    }

    public function students()
    {
        return $this->belongsToMany(User::class, 'enrollments', 'class_id', 'student_id')
            ->withPivot(['is_class_leader', 'is_banned', 'progress_percent', 'joined_at'])
            ->withTimestamps();
    }

    public static function generateUniqueJoinCode(): string
    {
        do {
            $code = strtoupper(Str::random(6));
        } while (self::where('join_code', $code)->exists());

        return $code;
    }
}
