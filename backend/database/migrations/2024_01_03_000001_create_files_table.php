<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('files', function (Blueprint $table) {
            $table->id();
            $table->foreignId('uploader_id')->constrained('users')->cascadeOnDelete();
            $table->string('related_type', 50)->nullable(); // lesson, assignment, message, submission
            $table->unsignedBigInteger('related_id')->nullable();
            $table->string('original_name', 300);
            $table->string('stored_name', 300);
            $table->string('file_path', 500);
            $table->string('file_type', 100)->nullable();
            $table->unsignedBigInteger('file_size')->nullable();
            $table->boolean('is_public')->default(false);
            $table->unsignedInteger('download_count')->default(0);
            $table->timestamps();

            $table->index(['related_type', 'related_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('files');
    }
};
