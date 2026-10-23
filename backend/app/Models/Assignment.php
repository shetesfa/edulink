<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

class Assignment extends Model
{
    protected $fillable = [
        'class_id', 'teacher_id', 'title', 'description', 'max_score',
        'due_date', 'allow_late', 'is_published', 'type', 'max_group_size', 'start_at'
    ];

    protected $casts = [
        'due_date' => 'datetime',
        'allow_late' => 'boolean',
        'is_published' => 'boolean',
        'max_score' => 'decimal:2',
    ];

    public function schoolClass()
    {
        return $this->belongsTo(SchoolClass::class, 'class_id');
    }

    public function teacher()
    {
        return $this->belongsTo(User::class, 'teacher_id');
    }

    public function submissions()
    {
        return $this->hasMany(AssignmentSubmission::class);
    }

    public function files()
    {
        return $this->hasMany(FileUpload::class, 'related_id')->where('related_type', 'assignment');
    }

    public function isPastDue(): bool
    {
        return $this->due_date && Carbon::now()->greaterThan($this->due_date);
    }
}
