<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('video_meetings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('class_id')->nullable()->constrained('classes')->nullOnDelete();
            $table->foreignId('host_id')->constrained('users')->cascadeOnDelete();
            $table->string('title', 300);
            $table->string('room_id', 100)->unique();
            $table->timestamp('scheduled_at')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('ended_at')->nullable();
            $table->enum('status', ['scheduled', 'live', 'ended'])->default('scheduled');
            $table->boolean('is_recorded')->default(false);
            $table->string('recording_url', 500)->nullable();
            $table->integer('participant_count')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('video_meetings');
    }
};
