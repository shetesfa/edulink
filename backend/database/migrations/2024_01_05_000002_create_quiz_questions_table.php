<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('quiz_questions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('quiz_id')->constrained('quizzes')->cascadeOnDelete();
            $table->string('question_type')->default('multiple_choice');
            $table->text('question_text');
            $table->json('options')->nullable(); // e.g. ["Paris","London","Rome"]
            $table->text('correct_answer')->nullable(); // null for essay (manual grading)
            $table->decimal('points', 5, 2)->default(1);
            $table->integer('order_index')->default(0);
            $table->text('explanation')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('quiz_questions');
    }
};
