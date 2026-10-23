<?php

namespace App\Http\Requests\Announcements;

use Illuminate\Foundation\Http\FormRequest;

class AnnouncementRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:300'],
            'body' => ['nullable', 'string', 'max:5000'],
            'content' => ['nullable', 'string', 'max:5000'],
            'is_pinned' => ['nullable', 'boolean'],
        ];
    }

    protected function prepareForValidation(): void
    {
        // Accept 'content' as alias for 'body'
        if ($this->has('content') && !$this->has('body')) {
            $this->merge(['body' => $this->content]);
        }
    }
}
