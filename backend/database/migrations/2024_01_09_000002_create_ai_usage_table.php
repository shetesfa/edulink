<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ai_usage', function (Blueprint $table) {
            $table->id();
            $table->string('provider', 50);
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->unsignedInteger('tokens_used')->default(0);
            $table->unsignedInteger('request_count')->default(0);
            $table->date('date');
            $table->timestamps();

            $table->unique(['provider', 'date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ai_usage');
    }
};
