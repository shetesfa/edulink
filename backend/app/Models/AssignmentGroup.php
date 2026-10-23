<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AssignmentGroup extends Model
{
    use HasFactory;

    protected $fillable = [
        'assignment_id',
        'name',
        'created_by',
        'is_full',
    ];

    public function assignment()
    {
        return $this->belongsTo(Assignment::class);
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function members()
    {
        return $this->hasMany(AssignmentGroupMember::class);
    }
}
