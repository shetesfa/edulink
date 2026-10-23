<?php

namespace App\Http\Requests\Chat;

use Illuminate\Foundation\Http\FormRequest;

class SendMessageRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'client_message_id' => ['required', 'string', 'max:64'],
            'body' => ['required_without:attachments', 'nullable', 'string', 'max:5000'],
            'message_type' => ['nullable', 'in:text,image,video,audio,file,voice'],
            'reply_to_id' => ['nullable', 'exists:messages,id'],
            'attachments' => ['nullable'],
        ];
    }
}
