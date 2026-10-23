<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('schools', function (Blueprint $table) {
            $table->id();
            $table->string('name', 200);
            $table->string('slug', 200)->unique();
            $table->text('description')->nullable();
            $table->string('logo', 500)->nullable();
            $table->string('cover_photo', 500)->nullable();
            $table->text('address')->nullable();
            $table->string('city', 100)->nullable();
            $table->string('country', 100)->default('Ethiopia');
            $table->string('phone', 30)->nullable();
            $table->string('email', 150)->nullable();
            $table->string('website', 300)->nullable();
            $table->boolean('is_active')->default(true);
            $table->integer('max_students')->default(1000);
            $table->string('plan', 30)->default('free');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('schools');
    }
};
