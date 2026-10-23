<?php

namespace App\Policies;

use App\Models\User;
use App\Models\SchoolClass;

class SchoolClassPolicy
{
    public function manage(User $user, SchoolClass $class): bool
    {
        if (in_array($user->role->name, ['school_admin', 'super_admin'])) {
            return true;
        }

        return $user->id === $class->teacher_id;
    }

    public function view(User $user, SchoolClass $class): bool
    {
        if ($this->manage($user, $class)) {
            return true;
        }

        return $class->enrollments()->where('student_id', $user->id)->exists();
    }
}
