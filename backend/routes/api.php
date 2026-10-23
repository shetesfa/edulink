<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\Auth\AuthController;
use App\Http\Controllers\Api\Auth\GoogleAuthController;
use App\Http\Controllers\Api\ClassController;
use App\Http\Controllers\Api\LessonController;
use App\Http\Controllers\Api\AssignmentController;
use App\Http\Controllers\Api\QuizController;
use App\Http\Controllers\Api\ChatController;
use App\Http\Controllers\Api\AnnouncementController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\ProgressController;
use App\Http\Controllers\Api\AiController;
use App\Http\Controllers\Api\MeetingController;
use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\BroadcastAuthController;
use App\Http\Controllers\Api\SearchController;
use App\Http\Controllers\Api\DeviceTokenController;
use App\Http\Controllers\Api\TextbookAiController;


// Health check endpoint
Route::get('/', function () {
    return response()->json([
        'status' => 'ok',
        'message' => 'EduLink API is running',
        'version' => '1.0.0'
    ]);
});

use App\Http\Controllers\Api\GradePackController;

// Public AI Routes (Textbook AI + General AI — accessible offline & online on all devices)
Route::prefix('ai/textbook')->group(function () {
    Route::post('/',                          [TextbookAiController::class, 'query']);
    Route::post('/query',                     [TextbookAiController::class, 'query']);
    Route::get('/search',                     [TextbookAiController::class, 'search']);
    Route::get('/chapters/{grade}/{subject}', [TextbookAiController::class, 'chapters']);
    Route::get('/status',                     [TextbookAiController::class, 'status']);
});
Route::get('/ai/textbook/page-image/{grade}/{subject}/{page}', [TextbookAiController::class, 'pageImage']);
Route::post('/ai/ask', [AiController::class, 'ask']);

// Grade Pack Offline Routes
Route::prefix('grade-packs')->group(function () {
    Route::post('/import',                       [GradePackController::class, 'import']);
    Route::get('/',                              [GradePackController::class, 'index']);
    Route::get('/search',                        [GradePackController::class, 'search']);
    Route::get('/{grade}/{subject}/units',       [GradePackController::class, 'subjectUnits']);
    Route::get('/{grade}/{subject}/unit/{unit}', [GradePackController::class, 'unitContent']);
    Route::delete('/{pack_id}',                  [GradePackController::class, 'destroy']);
});

/*
|--------------------------------------------------------------------------
| STAGE 1: Authentication routes
| More route groups (classes, lessons, assignments, quizzes, chat, ai...)
| will be added here in later stages.
|--------------------------------------------------------------------------
*/

Route::prefix('auth')->group(function () {
    // Public - rate limited to prevent brute force / spam
    Route::middleware('throttle:6,1')->group(function () {
        Route::post('/register', [AuthController::class, 'register']);
        Route::post('/resend-verification-otp', [AuthController::class, 'resendVerificationOtp']);
        Route::post('/verify-email', [AuthController::class, 'verifyEmail']);
        Route::post('/login', [AuthController::class, 'login']);
        Route::post('/send-login-otp', [AuthController::class, 'sendLoginOtp']);
        Route::post('/verify-login-otp', [AuthController::class, 'verifyLoginOtp']);
        Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);
        Route::post('/reset-password', [AuthController::class, 'resetPassword']);
    });

    Route::get('/google', [GoogleAuthController::class, 'redirect']);
    Route::get('/google/callback', [GoogleAuthController::class, 'callback']);
    Route::post('/google/mobile', [GoogleAuthController::class, 'mobileCallback']);

    // Authenticated
    Route::middleware(['auth:sanctum', 'active.user'])->group(function () {
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);
        Route::post('/profile', [AuthController::class, 'updateProfile']);
        // Backwards-compatible photo endpoint used by earlier app builds.
        // It shares the profile validation and storage flow above.
        Route::post('/profile-photo', [AuthController::class, 'updateProfile']);
        Route::post('/change-password', [AuthController::class, 'changePassword']);
        Route::post('/update-role', [AuthController::class, 'updateRole']);
    });
});

Route::middleware(['auth:sanctum', 'active.user'])->group(function () {
    Route::put('/settings', [AuthController::class, 'updateSettings']);
    Route::post('/broadcasting/auth', [BroadcastAuthController::class, 'authenticate']);

    // STAGE 2: Classes & Schools
    Route::post('/classes/join', [ClassController::class, 'join']); // must be before {class} routes
    Route::get('/classes', [ClassController::class, 'index']);
    Route::post('/classes', [ClassController::class, 'store']);
    Route::get('/classes/{class}', [ClassController::class, 'show']);
    Route::put('/classes/{class}', [ClassController::class, 'update']);
    Route::delete('/classes/{class}', [ClassController::class, 'destroy']);
    Route::post('/classes/{class}/leave', [ClassController::class, 'leave']);
    Route::get('/classes/{class}/students', [ClassController::class, 'students']);
    Route::delete('/classes/{class}/students/{studentId}', [ClassController::class, 'removeStudent']);
    Route::post('/classes/{class}/students/{studentId}/promote', [ClassController::class, 'promoteStudent']);
    Route::post('/classes/{class}/regenerate-code', [ClassController::class, 'regenerateCode']);

    // STAGE 3: Lessons & Files
    Route::get('/classes/{class}/lessons', [LessonController::class, 'index']);
    Route::post('/classes/{class}/lessons', [LessonController::class, 'store']);
    Route::get('/lessons/{lesson}', [LessonController::class, 'show']);
    Route::put('/lessons/{lesson}', [LessonController::class, 'update']);
    Route::delete('/lessons/{lesson}', [LessonController::class, 'destroy']);
    Route::post('/lessons/{lesson}/attachments', [LessonController::class, 'uploadAttachments']);
    Route::post('/lessons/{lesson}/bookmark', [LessonController::class, 'toggleBookmark']);
    Route::get('/lessons/{lesson}/comments', [LessonController::class, 'comments']);
    Route::post('/lessons/{lesson}/comments', [LessonController::class, 'addComment']);
    Route::delete('/lessons/comments/{comment}', [LessonController::class, 'deleteComment']);
    Route::get('/files/{file}/download', [LessonController::class, 'downloadFile']);

    // STAGE 4: Assignments
    Route::get('/classes/{class}/assignments', [AssignmentController::class, 'index']);
    Route::post('/classes/{class}/assignments', [AssignmentController::class, 'store']);
    Route::get('/assignments/{assignment}', [AssignmentController::class, 'show']);
    Route::put('/assignments/{assignment}', [AssignmentController::class, 'update']);
    Route::delete('/assignments/{assignment}', [AssignmentController::class, 'destroy']);
    Route::post('/assignments/{assignment}/submit', [AssignmentController::class, 'submit']);
    Route::post('/submissions/{submission}/grade', [AssignmentController::class, 'grade']);

    // STAGE 5: Quizzes
    Route::get('/classes/{class}/quizzes', [QuizController::class, 'index']);
    Route::post('/classes/{class}/quizzes', [QuizController::class, 'store']);
    Route::get('/quizzes/{quiz}', [QuizController::class, 'show']);
    Route::put('/quizzes/{quiz}', [QuizController::class, 'update']);
    Route::delete('/quizzes/{quiz}', [QuizController::class, 'destroy']);
    Route::post('/quizzes/{quiz}/questions', [QuizController::class, 'addQuestion']);
    Route::delete('/quizzes/questions/{question}', [QuizController::class, 'deleteQuestion']);
    Route::get('/quizzes/{quiz}/take', [QuizController::class, 'take']);
    Route::post('/quizzes/{quiz}/submit', [QuizController::class, 'submit']);
    Route::get('/quizzes/{quiz}/analytics', [QuizController::class, 'analytics']);
    Route::get('/quizzes/{quiz}/attempts', [QuizController::class, 'myAttempts']);

    // STAGE 6: Chat & realtime
    Route::get('/chat/conversations', [ChatController::class, 'conversations']);
    Route::get('/chat/search', [ChatController::class, 'search']);
    Route::post('/chat/typing', [ChatController::class, 'typing']);

    Route::get('/chat/private/{userId}', [ChatController::class, 'privateHistory']);
    Route::post('/chat/private/{userId}', [ChatController::class, 'sendPrivate']);
    Route::post('/chat/private/{userId}/read', [ChatController::class, 'markPrivateRead']);

    Route::post('/chat/groups', [ChatController::class, 'createGroup']);
    Route::post('/chat/groups/join', [ChatController::class, 'joinGroup']);
    Route::post('/chat/groups/{group}/leave', [ChatController::class, 'leaveGroup']);
    Route::get('/chat/groups/{group}/messages', [ChatController::class, 'groupHistory']);
    Route::post('/chat/groups/{group}/messages', [ChatController::class, 'sendGroupMessage']);
    Route::post('/chat/groups/{group}/read', [ChatController::class, 'markGroupRead']);

    Route::put('/chat/messages/{message}', [ChatController::class, 'editMessage']);
    Route::delete('/chat/messages/{message}', [ChatController::class, 'deleteMessage']);
    Route::post('/chat/messages/{message}/pin', [ChatController::class, 'togglePin']);
    Route::post('/chat/messages/{message}/react', [ChatController::class, 'react']);
    Route::post('/chat/messages/{message}/forward', [ChatController::class, 'forward']);
    Route::get('/chat/groups/{group}/members', [ChatController::class, 'groupMembers']);
    Route::post('/chat/groups/{group}/members', [ChatController::class, 'addGroupMember']);
    Route::delete('/chat/groups/{group}/members/{userId}', [ChatController::class, 'removeGroupMember']);

    // Global search
    Route::get('/search', [SearchController::class, 'index']);

    // Push notification device registration
    Route::post('/device-tokens', [DeviceTokenController::class, 'store']);
    Route::delete('/device-tokens', [DeviceTokenController::class, 'destroy']);

    // STAGE 7: Announcements & Notifications
    Route::get('/classes/{class}/announcements', [AnnouncementController::class, 'index']);
    Route::post('/classes/{class}/announcements', [AnnouncementController::class, 'store']);
    Route::put('/announcements/{announcement}', [AnnouncementController::class, 'update']);
    Route::delete('/announcements/{announcement}', [AnnouncementController::class, 'destroy']);

    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::get('/notifications/unread-count', [NotificationController::class, 'unreadCount']);
    Route::post('/notifications/{notification}/read', [NotificationController::class, 'markRead']);
    Route::post('/notifications/read-all', [NotificationController::class, 'markAllRead']);
    Route::delete('/notifications/{notification}', [NotificationController::class, 'destroy']);

    // STAGE 8: Progress & Dashboards
    Route::get('/dashboard', [DashboardController::class, 'index']);
    Route::get('/classes/{class}/progress/me', [ProgressController::class, 'mine']);
    Route::get('/classes/{class}/progress', [ProgressController::class, 'classProgress']);

    // STAGE 9: AI Assistant
    Route::middleware('throttle:20,1')->group(function () {
        Route::post('/ai/ask', [AiController::class, 'ask']);
        Route::post('/ai/summarize', [AiController::class, 'summarize']);
        Route::post('/ai/translate', [AiController::class, 'translate']);
        Route::post('/ai/quiz', [AiController::class, 'generateQuiz']);
        Route::post('/ai/assignment', [AiController::class, 'generateAssignment']);
    });

    Route::middleware('role:school_admin,super_admin')->group(function () {
        Route::get('/ai/providers', [AiController::class, 'providerStatus']);
        Route::get('/ai/usage', [AiController::class, 'usageStats']);
    });

    // STAGE 10: Meetings
    Route::get('/meetings', [MeetingController::class, 'index']);
    Route::post('/meetings', [MeetingController::class, 'store']);
    Route::get('/meetings/{meeting}', [MeetingController::class, 'show']);
    Route::post('/meetings/{meeting}/start', [MeetingController::class, 'start']);
    Route::post('/meetings/{meeting}/end', [MeetingController::class, 'end']);
    Route::get('/meetings/{meeting}/token', [MeetingController::class, 'token']);
    Route::delete('/meetings/{meeting}', [MeetingController::class, 'destroy']);

    // STAGE 11: Admin Tools
    Route::prefix('admin')->middleware('role:school_admin,super_admin')->group(function () {
        Route::get('/users', [AdminController::class, 'users']);
        Route::post('/users/{user}/toggle-active', [AdminController::class, 'toggleActive']);
        Route::put('/users/{user}/role', [AdminController::class, 'changeRole']);
        Route::delete('/users/{user}', [AdminController::class, 'deleteUser']);
        Route::get('/classes', [AdminController::class, 'classes']);
        Route::post('/classes/{class}/toggle-active', [AdminController::class, 'toggleClassActive']);
        Route::get('/audit-logs', [AdminController::class, 'auditLogs']);
    });
    // Study Rooms
    Route::prefix('study-rooms')->group(function () {
        Route::get('/', [\App\Http\Controllers\Api\StudyRoomController::class, 'index']);
        Route::post('/', [\App\Http\Controllers\Api\StudyRoomController::class, 'store']);
        Route::get('/{id}', [\App\Http\Controllers\Api\StudyRoomController::class, 'show']);
        Route::post('/join', [\App\Http\Controllers\Api\StudyRoomController::class, 'join']);
        Route::post('/{id}/leave', [\App\Http\Controllers\Api\StudyRoomController::class, 'leave']);
        Route::get('/{id}/messages', [\App\Http\Controllers\Api\StudyRoomController::class, 'messages']);
        Route::post('/{id}/messages', [\App\Http\Controllers\Api\StudyRoomController::class, 'sendMessage']);
    });

    // Group Assignments
    Route::get('/assignments/{id}/groups', [\App\Http\Controllers\Api\AssignmentController::class, 'groups']);
    Route::post('/assignments/{id}/groups', [\App\Http\Controllers\Api\AssignmentController::class, 'createGroup']);
    Route::post('/assignments/{id}/groups/{groupId}/join', [\App\Http\Controllers\Api\AssignmentController::class, 'joinGroup']);
    Route::post('/assignments/groups/{groupId}/score', [\App\Http\Controllers\Api\AssignmentController::class, 'scoreGroup']);

    // Teacher Analytics API
    Route::get('/analytics/class/{classId}', [\App\Http\Controllers\Api\AnalyticsController::class, 'classPerformance']);

    // Portfolio API
    Route::get('/portfolio', [\App\Http\Controllers\Api\PortfolioController::class, 'myPortfolio']);
    Route::get('/portfolio/{userId}/public', [\App\Http\Controllers\Api\PortfolioController::class, 'publicProfile']);

});
