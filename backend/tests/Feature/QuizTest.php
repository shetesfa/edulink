<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use App\Models\SchoolClass;
use App\Models\Quiz;
use App\Models\QuizQuestion;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class QuizTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Role::insert([
            ['id' => 1, 'name' => 'guest'], ['id' => 2, 'name' => 'student'],
            ['id' => 3, 'name' => 'teacher'], ['id' => 4, 'name' => 'school_admin'],
            ['id' => 5, 'name' => 'super_admin'],
        ]);
    }

    public function test_quiz_auto_grades_multiple_choice_correctly(): void
    {
        $teacher = User::factory()->create(['role_id' => 3, 'email_verified_at' => now()]);
        $class = SchoolClass::create(['teacher_id' => $teacher->id, 'name' => 'Test Class', 'join_code' => 'QZ0001']);
        $student = User::factory()->create(['role_id' => 2, 'email_verified_at' => now()]);
        $class->students()->attach($student->id, ['joined_at' => now()]);

        $quiz = Quiz::create([
            'class_id' => $class->id, 'teacher_id' => $teacher->id,
            'title' => 'Geography Quiz', 'is_published' => true, 'pass_score' => 50,
        ]);

        $q1 = QuizQuestion::create([
            'quiz_id' => $quiz->id, 'question_type' => 'multiple_choice',
            'question_text' => 'Capital of France?', 'options' => ['Paris', 'London', 'Rome'],
            'correct_answer' => 'Paris', 'points' => 1,
        ]);
        $q2 = QuizQuestion::create([
            'quiz_id' => $quiz->id, 'question_type' => 'true_false',
            'question_text' => 'The earth is flat.', 'options' => ['True', 'False'],
            'correct_answer' => 'False', 'points' => 1,
        ]);

        $response = $this->actingAs($student, 'sanctum')->postJson("/api/quizzes/{$quiz->id}/submit", [
            'answers' => [$q1->id => 'Paris', $q2->id => 'True'], // one right, one wrong
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('quiz_attempts', [
            'quiz_id' => $quiz->id, 'student_id' => $student->id,
            'score' => 1, 'max_score' => 2, 'percentage' => 50,
        ]);
    }

    public function test_essay_questions_are_flagged_for_manual_grading(): void
    {
        $teacher = User::factory()->create(['role_id' => 3, 'email_verified_at' => now()]);
        $class = SchoolClass::create(['teacher_id' => $teacher->id, 'name' => 'Test Class', 'join_code' => 'QZ0002']);
        $student = User::factory()->create(['role_id' => 2, 'email_verified_at' => now()]);
        $class->students()->attach($student->id, ['joined_at' => now()]);

        $quiz = Quiz::create(['class_id' => $class->id, 'teacher_id' => $teacher->id, 'title' => 'Essay Quiz', 'is_published' => true]);
        $q1 = QuizQuestion::create([
            'quiz_id' => $quiz->id, 'question_type' => 'essay',
            'question_text' => 'Explain photosynthesis.', 'points' => 5,
        ]);

        $this->actingAs($student, 'sanctum')->postJson("/api/quizzes/{$quiz->id}/submit", [
            'answers' => [$q1->id => 'Plants use sunlight...'],
        ]);

        $this->assertDatabaseHas('quiz_attempts', [
            'quiz_id' => $quiz->id, 'needs_manual_grading' => true, 'score' => 0,
        ]);
    }

    public function test_student_cannot_exceed_max_attempts(): void
    {
        $teacher = User::factory()->create(['role_id' => 3, 'email_verified_at' => now()]);
        $class = SchoolClass::create(['teacher_id' => $teacher->id, 'name' => 'Test Class', 'join_code' => 'QZ0003']);
        $student = User::factory()->create(['role_id' => 2, 'email_verified_at' => now()]);
        $class->students()->attach($student->id, ['joined_at' => now()]);

        $quiz = Quiz::create([
            'class_id' => $class->id, 'teacher_id' => $teacher->id,
            'title' => 'One Try Quiz', 'is_published' => true, 'max_attempts' => 1,
        ]);
        QuizQuestion::create(['quiz_id' => $quiz->id, 'question_type' => 'true_false', 'question_text' => 'Q', 'correct_answer' => 'True', 'points' => 1]);

        $this->actingAs($student, 'sanctum')->postJson("/api/quizzes/{$quiz->id}/submit", ['answers' => []]);
        $response = $this->actingAs($student, 'sanctum')->postJson("/api/quizzes/{$quiz->id}/submit", ['answers' => []]);

        $response->assertStatus(422);
    }
}
