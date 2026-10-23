<?php

namespace App\Http\Requests\Quizzes;

use Illuminate\Foundation\Http\FormRequest;

class CreateQuizRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:300'],
            'description' => ['nullable', 'string', 'max:2000'],
            'time_limit_minutes' => ['nullable', 'integer', 'min:1'],
            'max_attempts' => ['nullable', 'integer', 'min:1', 'max:10'],
            'shuffle_questions' => ['nullable', 'boolean'],
            'show_answers_after' => ['nullable', 'boolean'],
            'pass_score' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'is_published' => ['nullable', 'boolean'],
            'opens_at' => ['nullable', 'date'],
            'closes_at' => ['nullable', 'date', 'after:opens_at'],

            // Questions can be created together with the quiz
            'questions' => ['nullable', 'array'],
            'questions.*.question_type' => ['required_with:questions', 'in:multiple_choice,true_false,fill_blank,essay'],
            'questions.*.question_text' => ['required_with:questions', 'string'],
            'questions.*.options' => ['nullable', 'array'],
            'questions.*.correct_answer' => ['nullable', 'string'],
            'questions.*.points' => ['nullable', 'numeric', 'min:0.5'],
            'questions.*.explanation' => ['nullable', 'string'],
        ];
    }
}
