<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

class AuthTest extends TestCase
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

    public function test_user_can_register_and_receives_an_otp(): void
    {
        Notification::fake();

        $response = $this->postJson('/api/auth/register', [
            'first_name' => 'Beka',
            'last_name' => 'Tesfaye',
            'email' => 'beka@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertStatus(201)->assertJson(['success' => true]);
        $this->assertDatabaseHas('users', ['email' => 'beka@example.com']);
    }

    public function test_user_cannot_login_before_verifying_email(): void
    {
        $user = User::factory()->create(['role_id' => 2, 'email_verified_at' => null]);

        $response = $this->postJson('/api/auth/login', [
            'email' => $user->email,
            'password' => 'password',
        ]);

        $response->assertStatus(403)->assertJsonPath('data.requires_verification', true);
    }

    public function test_verified_user_can_login_with_correct_password(): void
    {
        $user = User::factory()->create([
            'role_id' => 2,
            'password' => Hash::make('password123'),
            'email_verified_at' => now(),
        ]);

        $response = $this->postJson('/api/auth/login', [
            'email' => $user->email,
            'password' => 'password123',
        ]);

        $response->assertStatus(200)->assertJsonStructure(['data' => ['user', 'token']]);
    }

    public function test_login_fails_with_wrong_password(): void
    {
        $user = User::factory()->create(['role_id' => 2, 'email_verified_at' => now()]);

        $response = $this->postJson('/api/auth/login', [
            'email' => $user->email,
            'password' => 'wrong-password',
        ]);

        $response->assertStatus(401)->assertJson(['success' => false]);
    }

    public function test_deactivated_user_cannot_login(): void
    {
        $user = User::factory()->create([
            'role_id' => 2,
            'password' => Hash::make('password123'),
            'email_verified_at' => now(),
            'is_active' => false,
        ]);

        $response = $this->postJson('/api/auth/login', [
            'email' => $user->email,
            'password' => 'password123',
        ]);

        $response->assertStatus(403);
    }
}
