<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Lesson extends Model
{
    protected $fillable = [
        'class_id', 'teacher_id', 'title', 'chapter_name', 'description', 'content',
        'order_index', 'is_published', 'allow_comments', 'allow_downloads',
    ];

    protected $casts = [
        'is_published' => 'boolean',
        'allow_comments' => 'boolean',
        'allow_downloads' => 'boolean',
    ];

    public function schoolClass()
    {
        return $this->belongsTo(SchoolClass::class, 'class_id');
    }

    public function teacher()
    {
        return $this->belongsTo(User::class, 'teacher_id');
    }

    public function files()
    {
        return $this->hasMany(FileUpload::class, 'related_id')->where('related_type', 'lesson');
    }

    public function bookmarks()
    {
        return $this->hasMany(LessonBookmark::class);
    }

    public function comments()
    {
        return $this->hasMany(LessonComment::class)->whereNull('parent_id')->with('replies', 'user');
    }

    public function isBookmarkedBy(int $userId): bool
    {
        return $this->bookmarks()->where('user_id', $userId)->exists();
    }
}
