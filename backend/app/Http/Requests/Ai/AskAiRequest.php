<?php

namespace App\Http\Requests\Ai;

use Illuminate\Foundation\Http\FormRequest;

class AskAiRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'prompt' => ['required', 'string', 'max:10000'],
            'language' => ['nullable', 'string'],
            'provider' => ['nullable', 'string'],
            'context' => ['nullable', 'array'],
        ];
    }
}
