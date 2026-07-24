<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Auth\AuthController;
use App\Http\Controllers\ClassController;
use App\Http\Controllers\AnnouncementController;
use App\Http\Controllers\LessonController;
use App\Http\Controllers\AssignmentController;
use App\Http\Controllers\QuizController;
use App\Http\Controllers\ChatController;
use App\Http\Controllers\VideoMeetingController;
use App\Http\Controllers\NotificationController;
use App\Http\Controllers\ProgressController;
use App\Http\Controllers\SearchController;
use App\Http\Controllers\AI\AIController;
use App\Http\Controllers\FileController;
use App\Http\Controllers\Admin\AdminController;

// ═══════════════════════════════════════════════════════════════
// PUBLIC AUTH ROUTES  (no token required)
// ═══════════════════════════════════════════════════════════════
Route::prefix('auth')->group(function () {

    // ── OTP-based Login (2-step) ──────────────────────────────
    Route::post('/send-login-otp',   [AuthController::class, 'sendLoginOtp']);
    Route::post('/verify-login-otp', [AuthController::class, 'verifyLoginOtp']);
    
    // ── Password-based Login ──────────────────────────────────
    Route::post('/login',            [AuthController::class, 'login']);

    // ── Registration + Email Verification ────────────────────
    Route::post('/register',          [AuthController::class, 'register']);
    Route::post('/verify-email',      [AuthController::class, 'verifyEmail']);
    Route::post('/resend-email-otp',  [AuthController::class, 'resendEmailOtp']);

    // ── Password Reset (OTP flow) ─────────────────────────────
    Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);
    Route::post('/verify-otp',      [AuthController::class, 'verifyOtp']);
    Route::post('/reset-password',  [AuthController::class, 'resetPassword']);

    // ── Google OAuth ──────────────────────────────────────────
    Route::get('/google',          [AuthController::class, 'googleRedirect']);
    Route::get('/google/callback', [AuthController::class, 'googleCallback']);
});

// ═══════════════════════════════════════════════════════════════
// AUTHENTICATED ROUTES
// ═══════════════════════════════════════════════════════════════
Route::middleware(['auth:sanctum', 'active.user'])->group(function () {

    // ── Auth / Profile ────────────────────────────────────────
    Route::prefix('auth')->group(function () {
        Route::post('/logout',          [AuthController::class, 'logout']);
        Route::get('/me',               [AuthController::class, 'me']);
        Route::post('/profile',         [AuthController::class, 'updateProfile']);
        Route::post('/change-password', [AuthController::class, 'changePassword']);
    });
    Route::put('/settings', [AuthController::class, 'updateSettings']);

    // ── Dashboard ─────────────────────────────────────────────
    Route::get('/dashboard', [ProgressController::class, 'dashboard']);

    // ── Classes ───────────────────────────────────────────────
    Route::get('/classes',              [ClassController::class, 'index']);
    Route::post('/classes',             [ClassController::class, 'store']);
    Route::post('/classes/join',        [ClassController::class, 'join']);

    Route::prefix('classes/{classId}')->group(function () {
        Route::get('/',                       [ClassController::class, 'show']);
        Route::put('/',                       [ClassController::class, 'update']);
        Route::delete('/',                    [ClassController::class, 'destroy']);
        Route::delete('/leave',               [ClassController::class, 'leave']);
        Route::get('/students',               [ClassController::class, 'students']);
        Route::delete('/students/{studentId}',[ClassController::class, 'removeStudent']);
        Route::post('/students/{studentId}/promote', [ClassController::class, 'promoteLeader']);
        Route::post('/regenerate-code',       [ClassController::class, 'regenerateCode']);
        Route::post('/assign-teacher',        [ClassController::class, 'assignTeacher']); // admin only
        Route::get('/progress',               [ProgressController::class, 'classProgress']);
        Route::get('/progress/{studentId}',   [ProgressController::class, 'studentProgress']);
        // ── Announcements ─────────────────────────────────────
        Route::get('/announcements',          [AnnouncementController::class, 'index']);
        Route::post('/announcements',         [AnnouncementController::class, 'store']);
        Route::put('/announcements/{id}',     [AnnouncementController::class, 'update']);
        Route::delete('/announcements/{id}',  [AnnouncementController::class, 'destroy']);

        // ── Lessons ───────────────────────────────────────────
        Route::get('/lessons',                [LessonController::class, 'index']);
        Route::post('/lessons',               [LessonController::class, 'store']);
        Route::get('/lessons/{id}',           [LessonController::class, 'show']);
        Route::put('/lessons/{id}',           [LessonController::class, 'update']);
        Route::delete('/lessons/{id}',        [LessonController::class, 'destroy']);
        Route::post('/lessons/{id}/bookmark', [LessonController::class, 'toggleBookmark']);
        Route::get('/lessons/{id}/comments',  [LessonController::class, 'getComments']);
        Route::post('/lessons/{id}/comments', [LessonController::class, 'addComment']);

        // ── Assignments ───────────────────────────────────────
        Route::get('/assignments',                            [AssignmentController::class, 'index']);
        Route::post('/assignments',                           [AssignmentController::class, 'store']);
        Route::get('/assignments/{id}',                       [AssignmentController::class, 'show']);
        Route::put('/assignments/{id}',                       [AssignmentController::class, 'update']);
        Route::delete('/assignments/{id}',                    [AssignmentController::class, 'destroy']);
        Route::post('/assignments/{id}/submit',               [AssignmentController::class, 'submit']);
        Route::get('/assignments/{id}/submissions',           [AssignmentController::class, 'submissions']);
        Route::post('/assignments/{id}/grade/{submissionId}', [AssignmentController::class, 'grade']);
        // ── PIN  ──────────────────────────────────────────────
        Route::post('/assignments/{id}/pin',                  [AssignmentController::class, 'togglePin']);

        // ── Quizzes ───────────────────────────────────────────
        Route::get('/quizzes',              [QuizController::class, 'index']);
        Route::post('/quizzes',             [QuizController::class, 'store']);
        Route::get('/quizzes/{quizId}',     [QuizController::class, 'show']);
        Route::put('/quizzes/{quizId}',     [QuizController::class, 'update']);
        Route::delete('/quizzes/{quizId}',  [QuizController::class, 'destroy']);
        Route::get('/quizzes/{quizId}/take',      [QuizController::class, 'take']);
        Route::post('/quizzes/{quizId}/submit',   [QuizController::class, 'submit']);
        Route::get('/quizzes/{quizId}/analytics', [QuizController::class, 'analytics']);
        Route::get('/quizzes/{quizId}/attempts',  [QuizController::class, 'attempts']);
        // ── PIN ───────────────────────────────────────────────
        Route::post('/quizzes/{quizId}/pin',      [QuizController::class, 'togglePin']);
    });

    // ── Chat ──────────────────────────────────────────────────
    Route::prefix('chat')->group(function () {
        Route::get('/conversations',              [ChatController::class, 'conversations']);
        Route::get('/private/{userId}',           [ChatController::class, 'privateMessages']);
        Route::post('/private/{userId}',          [ChatController::class, 'sendPrivate']);
        Route::get('/groups',                     [ChatController::class, 'groups']);
        Route::post('/groups',                    [ChatController::class, 'createGroup']);
        Route::post('/groups/join',               [ChatController::class, 'joinGroup']);
        Route::get('/groups/{groupId}',           [ChatController::class, 'groupMessages']);
        Route::post('/groups/{groupId}',          [ChatController::class, 'sendGroupMessage']);
        Route::put('/groups/{groupId}',           [ChatController::class, 'updateGroup']);
        Route::delete('/groups/{groupId}/leave',  [ChatController::class, 'leaveGroup']);
        Route::post('/groups/{groupId}/members',  [ChatController::class, 'addMember']);
        Route::delete('/groups/{groupId}/members/{userId}', [ChatController::class, 'removeMember']);
        Route::get('/search',                     [ChatController::class, 'searchMessages']);
        Route::post('/messages/{id}/pin',         [ChatController::class, 'pinMessage']);
        Route::post('/messages/{id}/forward',     [ChatController::class, 'forwardMessage']);
        Route::delete('/messages/{id}',           [ChatController::class, 'deleteMessage']);
        Route::put('/messages/{id}',              [ChatController::class, 'editMessage']);
    });

    // ── Meetings ──────────────────────────────────────────────
    Route::prefix('meetings')->group(function () {
        Route::get('/',         [VideoMeetingController::class, 'index']);
        Route::post('/',        [VideoMeetingController::class, 'create']);
        Route::get('/{id}',     [VideoMeetingController::class, 'show']);
        Route::post('/{id}/start', [VideoMeetingController::class, 'start']);
        Route::post('/{id}/end',   [VideoMeetingController::class, 'end']);
        Route::get('/{id}/token',  [VideoMeetingController::class, 'getJitsiToken']);
    });

    // ── Notifications ─────────────────────────────────────────
    Route::prefix('notifications')->group(function () {
        Route::get('/',                [NotificationController::class, 'index']);
        Route::get('/unread-count',    [NotificationController::class, 'unreadCount']);
        Route::post('/{id}/read',      [NotificationController::class, 'markRead']);
        Route::post('/read-all',       [NotificationController::class, 'markAllRead']);
        Route::delete('/{id}',         [NotificationController::class, 'destroy']);
    });

    // ── Search ────────────────────────────────────────────────
    Route::get('/search', [SearchController::class, 'search']);

    // ── Progress ──────────────────────────────────────────────
    Route::get('/progress/my', [ProgressController::class, 'myProgress']);

    // ── AI ────────────────────────────────────────────────────
    Route::prefix('ai')->group(function () {
        Route::post('/ask',        [AIController::class, 'ask']);
        Route::post('/quiz',       [AIController::class, 'generateQuiz']);
        Route::post('/summarize',  [AIController::class, 'summarize']);
        Route::post('/translate',  [AIController::class, 'translate']);
        Route::post('/assignment', [AIController::class, 'generateAssignment']);
        Route::post('/explain',    [AIController::class, 'explain']);
        Route::get('/providers',   [AIController::class, 'providerStatus']);
    });

    // ── Files ─────────────────────────────────────────────────
    Route::prefix('files')->group(function () {
        Route::post('/upload',      [FileController::class, 'upload']);
        Route::get('/{id}/download',[FileController::class, 'download']);
        Route::delete('/{id}',      [FileController::class, 'destroy']);
    });

    // ── Admin ─────────────────────────────────────────────────
    Route::middleware('role:school_admin,super_admin')->prefix('admin')->group(function () {
        Route::get('/stats',                                   [AdminController::class, 'stats']);
        Route::get('/users',                                   [AdminController::class, 'users']);
        Route::post('/users/{id}/toggle',                      [AdminController::class, 'toggleUser']);
        Route::delete('/users/{id}',                           [AdminController::class, 'deleteUser']);
        Route::get('/classes',                                 [AdminController::class, 'classes']);
        Route::post('/classes',                                [AdminController::class, 'createClass']);
        Route::post('/classes/{classId}/assign-teacher',       [AdminController::class, 'assignTeacher']);
        Route::get('/teachers',                                [AdminController::class, 'teachers']);
        Route::get('/reports',                                 [AdminController::class, 'reports']);
        Route::get('/ai-usage',                                [AdminController::class, 'aiUsage']);
    });
});
