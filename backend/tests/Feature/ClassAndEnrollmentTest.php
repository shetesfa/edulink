<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use App\Models\SchoolClass;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ClassAndEnrollmentTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Role::insert([
            ['id' => 1, 'name' => 'guest'],
            ['id' => 2, 'name' => 'student'],
            ['id' => 3, 'name' => 'teacher'],
            ['id' => 4, 'name' => 'school_admin'],
            ['id' => 5, 'name' => 'super_admin'],
        ]);
    }

    public function test_teacher_can_create_a_class_with_a_unique_join_code(): void
    {
        $teacher = User::factory()->create(['role_id' => 3, 'email_verified_at' => now()]);

        $response = $this->actingAs($teacher, 'sanctum')->postJson('/api/classes', [
            'name' => 'Grade 10 Mathematics',
            'subject' => 'Mathematics',
        ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('classes', ['name' => 'Grade 10 Mathematics', 'teacher_id' => $teacher->id]);
        $this->assertNotEmpty($response->json('data.class.join_code'));
    }

    public function test_student_can_join_a_class_with_a_valid_code(): void
    {
        $teacher = User::factory()->create(['role_id' => 3, 'email_verified_at' => now()]);
        $class = SchoolClass::create([
            'teacher_id' => $teacher->id,
            'name' => 'Grade 9 Physics',
            'join_code' => 'PHYS01',
        ]);
        $student = User::factory()->create(['role_id' => 2, 'email_verified_at' => now()]);

        $response = $this->actingAs($student, 'sanctum')->postJson('/api/classes/join', [
            'join_code' => 'PHYS01',
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('enrollments', ['class_id' => $class->id, 'student_id' => $student->id]);
    }

    public function test_student_cannot_join_the_same_class_twice(): void
    {
        $teacher = User::factory()->create(['role_id' => 3, 'email_verified_at' => now()]);
        $class = SchoolClass::create(['teacher_id' => $teacher->id, 'name' => 'Grade 9 Physics', 'join_code' => 'PHYS02']);
        $student = User::factory()->create(['role_id' => 2, 'email_verified_at' => now()]);

        $this->actingAs($student, 'sanctum')->postJson('/api/classes/join', ['join_code' => 'PHYS02']);
        $response = $this->actingAs($student, 'sanctum')->postJson('/api/classes/join', ['join_code' => 'PHYS02']);

        $response->assertStatus(422);
    }

    public function test_student_cannot_manage_a_class_they_do_not_teach(): void
    {
        $teacher = User::factory()->create(['role_id' => 3, 'email_verified_at' => now()]);
        $class = SchoolClass::create(['teacher_id' => $teacher->id, 'name' => 'Grade 9 Physics', 'join_code' => 'PHYS03']);
        $student = User::factory()->create(['role_id' => 2, 'email_verified_at' => now()]);

        $response = $this->actingAs($student, 'sanctum')->putJson("/api/classes/{$class->id}", ['name' => 'Hacked name']);

        $response->assertStatus(403);
    }
}
