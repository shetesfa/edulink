<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_settings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->boolean('dark_mode')->default(false);
            $table->string('language', 10)->default('en'); // en, am
            $table->boolean('notifications_enabled')->default(true);
            $table->boolean('email_notifications')->default(true);
            $table->boolean('sound_enabled')->default(true);
            $table->boolean('show_online_status')->default(true);
            $table->enum('allow_messages_from', ['everyone', 'classmates', 'nobody'])->default('everyone');
            $table->string('theme', 20)->default('purple');
            $table->enum('font_size', ['small', 'medium', 'large'])->default('medium');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_settings');
    }
};
