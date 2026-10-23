<?php

namespace App\Http\Requests\Classes;

use Illuminate\Foundation\Http\FormRequest;

class CreateClassRequest extends FormRequest
{
    public function authorize(): bool
    {
        // Only teachers, school admins, or super admins may create a class
        $user = $this->user();
        return $user && in_array($user->role->name, ['teacher', 'school_admin', 'super_admin']);
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:200'],
            'subject' => ['nullable', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:2000'],
            'grade_id' => ['nullable', 'exists:grades,id'],
            'color' => ['nullable', 'string', 'max:20'],
            'max_students' => ['nullable', 'integer', 'min:1', 'max:1000'],
            'allow_student_chat' => ['nullable', 'boolean'],
        ];
    }
}
