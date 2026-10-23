<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('student_progress', function (Blueprint $table) {
            $table->id();
            $table->foreignId('student_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('class_id')->constrained('classes')->cascadeOnDelete();
            $table->unsignedInteger('lessons_viewed')->default(0);
            $table->unsignedInteger('lessons_total')->default(0);
            $table->unsignedInteger('assignments_submitted')->default(0);
            $table->unsignedInteger('assignments_total')->default(0);
            $table->decimal('avg_quiz_score', 5, 2)->default(0);
            $table->unsignedInteger('quizzes_taken')->default(0);
            $table->timestamp('last_activity')->nullable();
            $table->timestamps();

            $table->unique(['student_id', 'class_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('student_progress');
    }
};
