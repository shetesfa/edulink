<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('assignments', function (Blueprint $table) {
            $table->enum('type', ['individual', 'group'])->default('individual');
            $table->integer('max_group_size')->default(4);
            $table->timestamp('start_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('assignments', function (Blueprint $table) {
            $table->dropColumn(['type', 'max_group_size', 'start_at']);
        });
    }
};
