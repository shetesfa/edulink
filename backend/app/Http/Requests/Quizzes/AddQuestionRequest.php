<?php

namespace App\Http\Requests\Quizzes;

use Illuminate\Foundation\Http\FormRequest;

class AddQuestionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'question_type' => ['required', 'in:multiple_choice,true_false,fill_blank,short_answer,essay'],
            'question_text' => ['required', 'string'],
            'options' => ['nullable', 'array'],
            'correct_answer' => ['nullable', 'string'],
            'points' => ['nullable', 'numeric', 'min:0.5'],
            'order_index' => ['nullable', 'integer'],
            'explanation' => ['nullable', 'string'],
        ];
    }
}
