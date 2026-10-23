<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('study_rooms', function (Blueprint $table) {
            $table->id();
            $table->foreignId('creator_id')->constrained('users')->cascadeOnDelete();
            $table->string('name', 200);
            $table->string('subject', 100)->nullable();
            $table->text('description')->nullable();
            $table->string('join_code', 10)->unique();
            $table->boolean('is_public')->default(true);
            $table->boolean('is_active')->default(true);
            $table->foreignId('linked_lesson_id')->nullable()->constrained('lessons')->nullOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('study_rooms');
    }
};
