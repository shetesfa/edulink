<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Auth\AuthController;
use App\Http\Controllers\ClassController;
use App\Http\Controllers\LessonController;
use App\Http\Controllers\AssignmentController;
use App\Http\Controllers\QuizController;
use App\Http\Controllers\ChatController;
use App\Http\Controllers\NotificationController;
use App\Http\Controllers\VideoMeetingController;
use App\Http\Controllers\AI\AIController;
use App\Http\Controllers\Admin\AdminController;
use App\Http\Controllers\SearchController;
use App\Http\Controllers\AnnouncementController;
use App\Http\Controllers\ProgressController;
use App\Http\Controllers\FileController;

// ─── Public routes ────────────────────────────────────────────
Route::prefix('auth')->group(function () {
    Route::post('register',         [AuthController::class, 'register']);
    Route::post('login',            [AuthController::class, 'login']);
    Route::post('forgot-password',  [AuthController::class, 'forgotPassword']);
    Route::post('reset-password',   [AuthController::class, 'resetPassword']);
    Route::post('verify-otp',       [AuthController::class, 'verifyOtp']);
    Route::get('google',            [AuthController::class, 'googleRedirect']);
    Route::get('google/callback',   [AuthController::class, 'googleCallback']);
});

// Public class join via invite link
Route::get('classes/invite/{link}', [ClassController::class, 'joinByLink']);

// ─── Authenticated routes ─────────────────────────────────────
Route::middleware('auth:sanctum')->group(function () {

    // Auth
    Route::prefix('auth')->group(function () {
        Route::get('me',                [AuthController::class, 'me']);
        Route::post('logout',           [AuthController::class, 'logout']);
        Route::post('profile',          [AuthController::class, 'updateProfile']);
        Route::post('change-password',  [AuthController::class, 'changePassword']);
    });

    // ─── Classes ──────────────────────────────────────────────────
    Route::prefix('classes')->group(function () {
        Route::get('/',                                     [ClassController::class, 'index']);
        Route::post('/',                                    [ClassController::class, 'store']);
        Route::post('join',                                 [ClassController::class, 'join']);
        Route::get('{id}',                                  [ClassController::class, 'show']);
        Route::put('{id}',                                  [ClassController::class, 'update']);
        Route::delete('{id}/leave',                         [ClassController::class, 'leave']);
        Route::get('{id}/students',                         [ClassController::class, 'students']);
        Route::delete('{classId}/students/{studentId}',     [ClassController::class, 'removeStudent']);
        Route::post('{classId}/students/{studentId}/promote',[ClassController::class, 'promoteLeader']);
        Route::post('{id}/regenerate-code',                 [ClassController::class, 'regenerateCode']);

        // Lessons
        Route::get('{classId}/lessons',                     [LessonController::class, 'index']);
        Route::post('{classId}/lessons',                    [LessonController::class, 'store']);
        Route::get('{classId}/lessons/{id}',                [LessonController::class, 'show']);
        Route::put('{classId}/lessons/{id}',                [LessonController::class, 'update']);
        Route::delete('{classId}/lessons/{id}',             [LessonController::class, 'destroy']);
        Route::post('{classId}/lessons/{id}/bookmark',      [LessonController::class, 'toggleBookmark']);
        Route::post('{classId}/lessons/{id}/comments',      [LessonController::class, 'addComment']);
        Route::get('{classId}/lessons/{id}/comments',       [LessonController::class, 'getComments']);

        // Assignments
        Route::get('{classId}/assignments',                 [AssignmentController::class, 'index']);
        Route::post('{classId}/assignments',                [AssignmentController::class, 'store']);
        Route::get('{classId}/assignments/{id}',            [AssignmentController::class, 'show']);
        Route::put('{classId}/assignments/{id}',            [AssignmentController::class, 'update']);
        Route::delete('{classId}/assignments/{id}',         [AssignmentController::class, 'destroy']);
        Route::post('{classId}/assignments/{id}/submit',    [AssignmentController::class, 'submit']);
        Route::get('{classId}/assignments/{id}/submissions',[AssignmentController::class, 'submissions']);
        Route::post('{classId}/assignments/{id}/grade/{studentId}', [AssignmentController::class, 'grade']);

        // Quizzes
        Route::get('{classId}/quizzes',                     [QuizController::class, 'index']);
        Route::post('{classId}/quizzes',                    [QuizController::class, 'store']);
        Route::get('{classId}/quizzes/{quizId}/take',       [QuizController::class, 'take']);
        Route::post('{classId}/quizzes/{quizId}/submit',    [QuizController::class, 'submit']);
        Route::get('{classId}/quizzes/{quizId}/analytics',  [QuizController::class, 'analytics']);
        Route::delete('{classId}/quizzes/{quizId}',         [QuizController::class, 'destroy']);

        // Announcements
        Route::get('{classId}/announcements',               [AnnouncementController::class, 'index']);
        Route::post('{classId}/announcements',              [AnnouncementController::class, 'store']);
        Route::put('{classId}/announcements/{id}',          [AnnouncementController::class, 'update']);
        Route::delete('{classId}/announcements/{id}',       [AnnouncementController::class, 'destroy']);

        // Progress
        Route::get('{classId}/progress',                    [ProgressController::class, 'classProgress']);
        Route::get('{classId}/progress/{studentId}',        [ProgressController::class, 'studentProgress']);
    });

    // ─── Chat ─────────────────────────────────────────────────────
    Route::prefix('chat')->group(function () {
        // Private messages
        Route::get('conversations',                         [ChatController::class, 'conversations']);
        Route::get('private/{userId}',                      [ChatController::class, 'privateMessages']);
        Route::post('private/{userId}',                     [ChatController::class, 'sendPrivate']);

        // Group chats
        Route::get('groups',                                [ChatController::class, 'groups']);
        Route::post('groups',                               [ChatController::class, 'createGroup']);
        Route::post('groups/join',                          [ChatController::class, 'joinGroup']);
        Route::get('groups/{groupId}',                      [ChatController::class, 'groupMessages']);
        Route::post('groups/{groupId}',                     [ChatController::class, 'sendGroup']);
        Route::put('groups/{groupId}',                      [ChatController::class, 'updateGroup']);
        Route::delete('groups/{groupId}/leave',             [ChatController::class, 'leaveGroup']);
        Route::post('groups/{groupId}/members',             [ChatController::class, 'addMember']);
        Route::delete('groups/{groupId}/members/{userId}',  [ChatController::class, 'removeMember']);

        // Message actions
        Route::put('messages/{id}',                         [ChatController::class, 'editMessage']);
        Route::delete('messages/{id}',                      [ChatController::class, 'deleteMessage']);
        Route::post('messages/{id}/react',                  [ChatController::class, 'reactToMessage']);
        Route::post('messages/{id}/pin',                    [ChatController::class, 'pinMessage']);
        Route::post('messages/{id}/forward',                [ChatController::class, 'forwardMessage']);
        Route::post('messages/{id}/read',                   [ChatController::class, 'markRead']);

        // Search messages
        Route::get('search',                                [ChatController::class, 'searchMessages']);
    });

    // ─── Video Meetings ───────────────────────────────────────────
    Route::prefix('meetings')->group(function () {
        Route::get('/',                                     [VideoMeetingController::class, 'index']);
        Route::post('/',                                    [VideoMeetingController::class, 'create']);
        Route::get('{id}',                                  [VideoMeetingController::class, 'show']);
        Route::post('{id}/start',                           [VideoMeetingController::class, 'start']);
        Route::post('{id}/end',                             [VideoMeetingController::class, 'end']);
        Route::get('{id}/token',                            [VideoMeetingController::class, 'getJitsiToken']);
    });

    // ─── AI Assistant ─────────────────────────────────────────────
    Route::prefix('ai')->middleware('throttle:100,60')->group(function () {
        Route::post('ask',                  [AIController::class, 'ask']);
        Route::post('quiz',                 [AIController::class, 'generateQuiz']);
        Route::post('summarize',            [AIController::class, 'summarize']);
        Route::post('translate',            [AIController::class, 'translate']);
        Route::post('assignment',           [AIController::class, 'generateAssignment']);
        Route::post('explain',              [AIController::class, 'explain']);
        Route::get('providers',             [AIController::class, 'providerStatus']);
    });

    // ─── Notifications ────────────────────────────────────────────
    Route::prefix('notifications')->group(function () {
        Route::get('/',                     [NotificationController::class, 'index']);
        Route::post('{id}/read',            [NotificationController::class, 'markRead']);
        Route::post('read-all',             [NotificationController::class, 'markAllRead']);
        Route::delete('{id}',              [NotificationController::class, 'destroy']);
        Route::get('unread-count',          [NotificationController::class, 'unreadCount']);
    });

    // ─── Files ────────────────────────────────────────────────────
    Route::prefix('files')->group(function () {
        Route::post('upload',               [FileController::class, 'upload']);
        Route::get('{id}/download',         [FileController::class, 'download']);
        Route::delete('{id}',              [FileController::class, 'destroy']);
    });

    // ─── Search ───────────────────────────────────────────────────
    Route::get('search',                    [SearchController::class, 'search']);

    // ─── Progress / Dashboard ─────────────────────────────────────
    Route::get('dashboard',                 [ProgressController::class, 'dashboard']);
    Route::get('progress/my',               [ProgressController::class, 'myProgress']);

    // ─── Admin ────────────────────────────────────────────────────
    Route::prefix('admin')->middleware('role:school_admin')->group(function () {
        Route::get('stats',                 [AdminController::class, 'stats']);
        Route::get('users',                 [AdminController::class, 'users']);
        Route::post('users/{id}/toggle',    [AdminController::class, 'toggleUser']);
        Route::delete('users/{id}',         [AdminController::class, 'deleteUser']);
        Route::get('classes',               [AdminController::class, 'classes']);
        Route::get('reports',               [AdminController::class, 'reports']);
        Route::get('ai-usage',              [AdminController::class, 'aiUsage']);
    });

    // User offline (called by socket)
    Route::post('auth/offline',             [AuthController::class, 'offline']);

    // User settings
    Route::put('settings',                  [AuthController::class, 'updateSettings']);

    // User profile (public)
    Route::get('users/{username}',          [AuthController::class, 'publicProfile']);
    Route::get('profile/{username}',        [AuthController::class, 'publicProfile']);
});
