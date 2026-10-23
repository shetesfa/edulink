<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('classes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('school_id')->nullable()->constrained('schools')->cascadeOnDelete();
            $table->foreignId('grade_id')->nullable()->constrained('grades')->nullOnDelete();
            $table->foreignId('teacher_id')->constrained('users')->cascadeOnDelete();
            $table->string('name', 200);
            $table->string('subject', 100)->nullable();
            $table->text('description')->nullable();
            $table->string('cover_photo', 500)->nullable();
            $table->string('color', 20)->default('#7C3AED');
            $table->string('join_code', 12)->unique();
            $table->string('invite_link', 100)->unique()->nullable();
            $table->boolean('is_active')->default(true);
            $table->integer('max_students')->default(200);
            $table->boolean('allow_student_chat')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('classes');
    }
};
