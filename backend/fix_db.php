<?php

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;

function safelyAddColumn($table, $callback) {
    try {
        Schema::table($table, $callback);
        echo "Successfully updated table: $table\n";
    } catch (\Exception $e) {
        if (str_contains($e->getMessage(), 'Duplicate column name') || str_contains($e->getMessage(), 'Duplicate key name')) {
            echo "Columns already exist in table: $table\n";
        } else {
            echo "Error updating $table: " . $e->getMessage() . "\n";
        }
    }
}

// Assignments
safelyAddColumn('assignments', function (Blueprint $table) {
    if (!Schema::hasColumn('assignments', 'is_pinned')) {
        $table->boolean('is_pinned')->default(false)->after('allow_late');
        $table->dateTime('pinned_at')->nullable()->after('is_pinned');
        $table->unsignedBigInteger('pinned_by')->nullable()->after('pinned_at');
        $table->foreign('pinned_by')->references('id')->on('users')->nullOnDelete();
    }
    if (!Schema::hasColumn('assignments', 'due_date')) {
        $table->dateTime('due_date')->nullable();
    }
    if (!Schema::hasColumn('assignments', 'allow_late')) {
        $table->boolean('allow_late')->default(false);
    }
});

// Quizzes
safelyAddColumn('quizzes', function (Blueprint $table) {
    if (!Schema::hasColumn('quizzes', 'is_pinned')) {
        $table->boolean('is_pinned')->default(false);
        $table->dateTime('pinned_at')->nullable();
        $table->unsignedBigInteger('pinned_by')->nullable();
        $table->foreign('pinned_by')->references('id')->on('users')->nullOnDelete();
    }
});

// Quiz Attempts
safelyAddColumn('quiz_attempts', function (Blueprint $table) {
    if (!Schema::hasColumn('quiz_attempts', 'submitted_at')) $table->dateTime('submitted_at')->nullable();
    if (!Schema::hasColumn('quiz_attempts', 'time_taken_seconds')) $table->unsignedInteger('time_taken_seconds')->default(0);
    if (!Schema::hasColumn('quiz_attempts', 'passed')) $table->boolean('passed')->default(false);
    if (!Schema::hasColumn('quiz_attempts', 'percentage')) $table->decimal('percentage', 5, 2)->default(0);
    if (!Schema::hasColumn('quiz_attempts', 'max_score')) $table->unsignedInteger('max_score')->default(0);
});

// Assignment Submissions
safelyAddColumn('assignment_submissions', function (Blueprint $table) {
    if (!Schema::hasColumn('assignment_submissions', 'submitted_at')) $table->dateTime('submitted_at')->nullable();
    if (!Schema::hasColumn('assignment_submissions', 'graded_at')) $table->dateTime('graded_at')->nullable();
    if (!Schema::hasColumn('assignment_submissions', 'status')) {
        // use raw for enum
        DB::statement("ALTER TABLE `assignment_submissions` ADD COLUMN `status` ENUM('submitted','late','graded') NOT NULL DEFAULT 'submitted'");
    }
});

echo "Done fixing DB schema.\n";
