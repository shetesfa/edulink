<?php

namespace App\Http\Requests\Assignments;

use Illuminate\Foundation\Http\FormRequest;

class SubmitAssignmentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'text_answer' => ['nullable', 'string'],
            'attachments' => ['nullable'],
        ];
    }
}
