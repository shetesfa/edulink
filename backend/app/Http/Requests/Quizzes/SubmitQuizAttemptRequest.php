<?php

namespace App\Http\Requests\Quizzes;

use Illuminate\Foundation\Http\FormRequest;

class SubmitQuizAttemptRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'answers' => ['required', 'array'], // { question_id: "answer" }
            'time_taken_seconds' => ['nullable', 'integer', 'min:0'],
        ];
    }
}
