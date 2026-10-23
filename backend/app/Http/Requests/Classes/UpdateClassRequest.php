<?php

namespace App\Http\Requests\Classes;

use Illuminate\Foundation\Http\FormRequest;

class UpdateClassRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // fine-grained ownership check happens in the controller/policy
    }

    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'string', 'max:200'],
            'subject' => ['sometimes', 'nullable', 'string', 'max:100'],
            'description' => ['sometimes', 'nullable', 'string', 'max:2000'],
            'grade_id' => ['sometimes', 'nullable', 'exists:grades,id'],
            'color' => ['sometimes', 'string', 'max:20'],
            'is_active' => ['sometimes', 'boolean'],
            'max_students' => ['sometimes', 'integer', 'min:1', 'max:1000'],
            'allow_student_chat' => ['sometimes', 'boolean'],
        ];
    }
}
