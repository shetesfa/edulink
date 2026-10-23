<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('quizzes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('class_id')->constrained('classes')->cascadeOnDelete();
            $table->foreignId('teacher_id')->constrained('users')->cascadeOnDelete();
            $table->string('title', 300);
            $table->text('description')->nullable();
            $table->integer('time_limit_minutes')->nullable();
            $table->unsignedTinyInteger('max_attempts')->default(1);
            $table->boolean('shuffle_questions')->default(false);
            $table->boolean('show_answers_after')->default(true);
            $table->decimal('pass_score', 5, 2)->default(50.00);
            $table->boolean('is_published')->default(false);
            $table->timestamp('opens_at')->nullable();
            $table->timestamp('closes_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('quizzes');
    }
};
