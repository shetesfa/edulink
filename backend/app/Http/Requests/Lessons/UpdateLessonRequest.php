<?php

namespace App\Http\Requests\Lessons;

use Illuminate\Foundation\Http\FormRequest;

class UpdateLessonRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title' => ['sometimes', 'string', 'max:300'],
            'description' => ['sometimes', 'nullable', 'string', 'max:2000'],
            'content' => ['sometimes', 'nullable', 'string'],
            'order_index' => ['sometimes', 'integer'],
            'is_published' => ['sometimes', 'boolean'],
            'allow_comments' => ['sometimes', 'boolean'],
            'allow_downloads' => ['sometimes', 'boolean'],
        ];
    }
}
