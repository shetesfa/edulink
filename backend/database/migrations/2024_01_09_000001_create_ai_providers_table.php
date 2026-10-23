<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ai_providers', function (Blueprint $table) {
            $table->tinyIncrements('id');
            $table->string('name', 50)->unique(); // gemini, groq, cohere, mistral, huggingface
            $table->string('display_name', 100)->nullable();
            $table->string('model_name', 100)->nullable();
            $table->integer('daily_limit')->default(1000);
            $table->boolean('is_active')->default(true);
            $table->tinyInteger('priority')->default(1); // lower = tried first
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ai_providers');
    }
};
