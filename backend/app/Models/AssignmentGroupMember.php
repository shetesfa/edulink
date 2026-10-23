<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AssignmentGroupMember extends Model
{
    use HasFactory;

    protected $fillable = [
        'assignment_group_id',
        'user_id',
    ];

    public function group()
    {
        return $this->belongsTo(AssignmentGroup::class, 'assignment_group_id');
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
