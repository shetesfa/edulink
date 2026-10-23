<?php

namespace App\Http\Requests\Meetings;

use Illuminate\Foundation\Http\FormRequest;

class CreateMeetingRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:300'],
            'class_id' => ['nullable', 'exists:classes,id'],
            'scheduled_at' => ['nullable', 'date'],
        ];
    }
}
