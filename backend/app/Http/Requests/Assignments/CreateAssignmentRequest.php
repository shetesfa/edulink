<?php

namespace App\Http\Requests\Assignments;

use Illuminate\Foundation\Http\FormRequest;

class CreateAssignmentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:300'],
            'description' => ['required', 'string', 'max:5000'],
            'max_score' => ['nullable', 'numeric', 'min:1', 'max:1000'],
            'due_date' => ['nullable', 'date'],
            'allow_late' => ['nullable', 'boolean'],
            'is_published' => ['nullable', 'boolean'],
            'type' => ['nullable', 'in:individual,group'],
            'max_group_size' => ['nullable', 'integer', 'min:2', 'max:100'],
            'start_at' => ['nullable', 'date'],
            'attachments' => ['nullable', 'array'],
            'attachments.*' => ['file', 'max:51200'],
        ];
    }
}
