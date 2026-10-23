<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $userId = $this->user()->id;

        return [
            'first_name' => ['sometimes', 'string', 'max:80'],
            'last_name' => ['sometimes', 'string', 'max:80'],
            'username' => ['nullable', 'string', 'max:60', Rule::unique('users', 'username')->ignore($userId)],
            'email' => ['sometimes', 'email', 'max:180', Rule::unique('users', 'email')->ignore($userId)],
            'bio' => ['nullable', 'string', 'max:1000'],
            'phone' => ['nullable', 'string', 'max:30'],
            'gender' => ['nullable', 'in:male,female,other'],
            'date_of_birth' => ['nullable', 'date', 'before:today'],
            'profile_photo' => ['nullable', 'image', 'max:4096'],
        ];
    }
}
