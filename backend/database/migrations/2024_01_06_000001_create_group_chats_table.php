<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('group_chats', function (Blueprint $table) {
            $table->id();
            $table->string('name', 200);
            $table->text('description')->nullable();
            $table->string('avatar', 500)->nullable();
            $table->enum('type', ['class', 'custom', 'private'])->default('custom');
            $table->foreignId('class_id')->nullable()->constrained('classes')->cascadeOnDelete();
            $table->foreignId('created_by')->constrained('users')->cascadeOnDelete();
            $table->string('invite_link', 100)->unique()->nullable();
            $table->string('join_code', 12)->unique()->nullable();
            $table->boolean('is_public')->default(false);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('group_chats');
    }
};
