<?php

namespace App\Http\Requests\Lessons;

use Illuminate\Foundation\Http\FormRequest;

class CreateLessonRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // teacher-ownership of the class is checked in the controller
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'is_published' => $this->has('is_published') ? filter_var($this->is_published, FILTER_VALIDATE_BOOLEAN) : true,
            'allow_comments' => $this->has('allow_comments') ? filter_var($this->allow_comments, FILTER_VALIDATE_BOOLEAN) : true,
            'allow_downloads' => $this->has('allow_downloads') ? filter_var($this->allow_downloads, FILTER_VALIDATE_BOOLEAN) : true,
        ]);
    }

    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:300'],
            'chapter_name' => ['nullable', 'string', 'max:300'],
            'description' => ['nullable', 'string', 'max:2000'],
            'content' => ['nullable', 'string'],
            'order_index' => ['nullable', 'integer'],
            'is_published' => ['nullable', 'boolean'],
            'allow_comments' => ['nullable', 'boolean'],
            'allow_downloads' => ['nullable', 'boolean'],
            'attachments' => ['nullable', 'array'],
            'attachments.*' => ['file', 'max:51200'], // 50MB per file
        ];
    }
}
