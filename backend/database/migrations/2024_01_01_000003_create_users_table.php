<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->foreignId('school_id')->nullable()->constrained('schools')->nullOnDelete();
            $table->foreignId('role_id')->default(2)->constrained('roles');
            $table->string('first_name', 80);
            $table->string('last_name', 80);
            $table->string('username', 60)->unique()->nullable();
            $table->string('email', 180)->unique();
            $table->timestamp('email_verified_at')->nullable();
            $table->string('password');
            $table->string('google_id', 100)->nullable();
            $table->string('profile_photo', 500)->nullable();
            $table->string('cover_photo', 500)->nullable();
            $table->text('bio')->nullable();
            $table->string('grade', 30)->nullable();
            $table->string('phone', 30)->nullable();
            $table->date('date_of_birth')->nullable();
            $table->enum('gender', ['male', 'female', 'other'])->nullable();
            $table->boolean('is_active')->default(true);
            $table->boolean('is_online')->default(false);
            $table->timestamp('last_seen')->nullable();
            $table->rememberToken();

            // OTP + password reset - stored HASHED, never plain text
            $table->string('otp_code_hash')->nullable();
            $table->timestamp('otp_expires_at')->nullable();
            $table->timestamp('otp_last_sent_at')->nullable();
            $table->unsignedTinyInteger('otp_attempts')->default(0);
            $table->string('password_reset_token_hash')->nullable();
            $table->timestamp('password_reset_expires_at')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
    }
};
