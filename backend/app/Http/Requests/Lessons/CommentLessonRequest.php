<?php

namespace App\Http\Requests\Lessons;

use Illuminate\Foundation\Http\FormRequest;

class CommentLessonRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'body' => ['required', 'string', 'max:2000'],
            'parent_id' => ['nullable', 'exists:lesson_comments,id'],
        ];
    }
}
