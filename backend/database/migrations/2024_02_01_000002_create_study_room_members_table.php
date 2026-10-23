<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('study_room_members', function (Blueprint $table) {
            $table->id();
            $table->foreignId('study_room_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->enum('role', ['member', 'moderator'])->default('member');
            $table->timestamps();
            $table->unique(['study_room_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('study_room_members');
    }
};
