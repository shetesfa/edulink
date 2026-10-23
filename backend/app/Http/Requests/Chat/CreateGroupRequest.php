<?php

namespace App\Http\Requests\Chat;

use Illuminate\Foundation\Http\FormRequest;

class CreateGroupRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:200'],
            'description' => ['nullable', 'string', 'max:1000'],
            'is_public' => ['nullable', 'boolean'],
            'member_ids' => ['nullable', 'array'],
            'member_ids.*' => ['exists:users,id'],
        ];
    }
}
