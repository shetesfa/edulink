<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use App\Models\SchoolClass;
use App\Models\Assignment;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AssignmentTest extends TestCase
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

    private function makeClassWithStudent(): array
    {
        $teacher = User::factory()->create(['role_id' => 3, 'email_verified_at' => now()]);
        $class = SchoolClass::create(['teacher_id' => $teacher->id, 'name' => 'Test Class', 'join_code' => 'ABC123']);
        $student = User::factory()->create(['role_id' => 2, 'email_verified_at' => now()]);
        $class->students()->attach($student->id, ['joined_at' => now()]);

        return [$teacher, $class, $student];
    }

    public function test_student_can_submit_an_assignment_before_the_due_date(): void
    {
        [$teacher, $class, $student] = $this->makeClassWithStudent();

        $assignment = Assignment::create([
            'class_id' => $class->id,
            'teacher_id' => $teacher->id,
            'title' => 'Essay 1',
            'description' => 'Write about photosynthesis.',
            'due_date' => now()->addDays(3),
        ]);

        $response = $this->actingAs($student, 'sanctum')->postJson("/api/assignments/{$assignment->id}/submit", [
            'text_answer' => 'My essay text.',
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('assignment_submissions', [
            'assignment_id' => $assignment->id,
            'student_id' => $student->id,
            'status' => 'submitted',
        ]);
    }

    public function test_late_submission_is_rejected_when_not_allowed(): void
    {
        [$teacher, $class, $student] = $this->makeClassWithStudent();

        $assignment = Assignment::create([
            'class_id' => $class->id,
            'teacher_id' => $teacher->id,
            'title' => 'Essay 2',
            'description' => 'Past due test.',
            'due_date' => now()->subDay(),
            'allow_late' => false,
        ]);

        $response = $this->actingAs($student, 'sanctum')->postJson("/api/assignments/{$assignment->id}/submit", [
            'text_answer' => 'Too late.',
        ]);

        $response->assertStatus(422);
    }

    public function test_teacher_can_grade_a_submission_within_max_score(): void
    {
        [$teacher, $class, $student] = $this->makeClassWithStudent();

        $assignment = Assignment::create([
            'class_id' => $class->id, 'teacher_id' => $teacher->id,
            'title' => 'Essay 3', 'description' => 'Grading test.', 'max_score' => 100,
        ]);

        $this->actingAs($student, 'sanctum')->postJson("/api/assignments/{$assignment->id}/submit", ['text_answer' => 'Answer']);
        $submission = $assignment->submissions()->first();

        $response = $this->actingAs($teacher, 'sanctum')->postJson("/api/submissions/{$submission->id}/grade", [
            'score' => 95,
            'feedback' => 'Great work!',
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('assignment_submissions', ['id' => $submission->id, 'score' => 95, 'status' => 'graded']);
    }

    public function test_grade_cannot_exceed_max_score(): void
    {
        [$teacher, $class, $student] = $this->makeClassWithStudent();

        $assignment = Assignment::create([
            'class_id' => $class->id, 'teacher_id' => $teacher->id,
            'title' => 'Essay 4', 'description' => 'Over-score test.', 'max_score' => 50,
        ]);

        $this->actingAs($student, 'sanctum')->postJson("/api/assignments/{$assignment->id}/submit", ['text_answer' => 'Answer']);
        $submission = $assignment->submissions()->first();

        $response = $this->actingAs($teacher, 'sanctum')->postJson("/api/submissions/{$submission->id}/grade", ['score' => 999]);

        $response->assertStatus(422);
    }
}
