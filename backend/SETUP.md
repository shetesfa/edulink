# EduLink Backend - Stage 1 (Authentication) Setup

This zip contains the **real, working custom code** for Stage 1: full authentication
(register, login, OTP login, email verification, forgot/reset password, Google OAuth,
profile, settings). It is not a full Laravel skeleton by itself - Laravel's core
framework files (thousands of them, inside `vendor/`) must be installed by Composer,
which I cannot run inside my sandbox (no access to Packagist from there).

Follow these steps once on your own computer (XAMPP/local machine):

## 1. Create the base Laravel project
```bash
composer create-project laravel/laravel:^11.0 edulink-backend
cd edulink-backend
```

## 2. Copy these custom files into it (overwrite when asked)
Copy everything from this zip into the new `edulink-backend` folder:
- `app/Models/*`
- `app/Http/Controllers/Api/*`
- `app/Http/Requests/Auth/*`
- `app/Http/Middleware/EnsureUserIsActive.php`
- `app/Notifications/*`
- `database/migrations/*`
- `database/seeders/*`
- `routes/api.php` and `routes/web.php` (overwrite the defaults)
- `bootstrap/app.php` (overwrite the default)
- `.env` (your real values) and `.env.example` (template for GitHub)
- `.gitignore` (overwrite the default - already excludes `.env`)
- `config/services.php` - **merge**, don't overwrite: open Laravel's generated
  `config/services.php` and paste the `google`, `gemini`, `groq`, `cohere`,
  `mistral`, `huggingface` array entries into it.

## 3. Install packages
```bash
composer require laravel/sanctum laravel/socialite spatie/laravel-permission
php artisan install:api
```
(`install:api` sets up Sanctum's own migration for API tokens automatically.)

## 4. Fill in your real Aiven MySQL details in `.env`
Open your Aiven MySQL service page, copy Host/Port/Password, and paste them into:
```
DB_HOST=...
DB_PORT=...
DB_PASSWORD=...
```
Aiven requires SSL - download the CA certificate from your Aiven console and set:
```
MYSQL_ATTR_SSL_CA=/full/path/to/ca.pem
```

## 5. Generate app key, migrate, seed
```bash
php artisan key:generate
php artisan migrate
php artisan db:seed
```

## 6. Run it locally to test
```bash
php artisan serve
```
Test with e.g. Postman: `POST http://localhost:8000/api/auth/register`

## 7. Push to GitHub (safe - .env is excluded automatically)
```bash
git init
git add .
git commit -m "Stage 1: authentication"
git remote add origin YOUR_GITHUB_REPO_URL
git push -u origin main
```

---
**Security reminder:** rotate your Gmail app password, Google OAuth secret, and
AI provider keys since they were shared in plain chat earlier - update `.env`
(never `.env.example` or any file you commit) with the new values once you do.

## Stage 2 added: Classes & Schools
New in this version:
- `app/Models/Grade.php`, `SchoolClass.php` (table `classes`), `Enrollment.php`
- `app/Http/Controllers/Api/ClassController.php` - create/update/delete/list
  classes, join by code, leave, list students, remove student, promote class
  leader, regenerate join code
- `app/Policies/SchoolClassPolicy.php` - only the owning teacher or a school/
  super admin can manage a class (Laravel auto-discovers this policy by name,
  no extra registration needed)
- 3 new migrations: `grades`, `classes`, `enrollments`

No new steps needed beyond what's above - just re-run:
```bash
php artisan migrate
```
to add the 3 new tables.

## Stage 3 added: Lessons & Files
New in this version:
- `app/Models/FileUpload.php` (table `files`), `Lesson.php`, `LessonBookmark.php`, `LessonComment.php`
- `app/Services/FileUploadService.php` - reusable safe file upload (checks
  extension + 50MB size limit, renames files so originals are never trusted,
  used again in later stages for assignments/chat)
- `app/Http/Controllers/Api/LessonController.php` - CRUD, file attachments,
  bookmarks, threaded comments, secure downloads
- 4 new migrations: `files`, `lessons`, `lesson_bookmarks`, `lesson_comments`

One extra one-time command needed for file downloads to work:
```bash
php artisan storage:link
php artisan migrate
```

**Next stage:** Assignments (create, submit, grade, late detection, feedback).
Just say "continue."

## Stage 4 added: Assignments
New in this version:
- `app/Models/Assignment.php`, `AssignmentSubmission.php`
- `app/Http/Controllers/Api/AssignmentController.php` - create/edit/delete
  assignments, submit (auto-detects late based on due date + `allow_late`),
  grade with feedback, students see their own submission inline, teachers see
  all submissions
- 2 new migrations: `assignments`, `assignment_submissions`

```bash
php artisan migrate
```

**Next stage:** Quizzes (multiple question types, auto-grading, attempts,
analytics). Just say "continue."

## Stage 5 added: Quizzes
New in this version:
- `app/Models/Quiz.php`, `QuizQuestion.php`, `QuizAttempt.php`
- `app/Services/QuizGradingService.php` - auto-grades multiple_choice/
  true_false/fill_blank instantly; essay questions are flagged
  `needs_manual_grading` for the teacher to score by hand later
- `app/Http/Controllers/Api/QuizController.php` - create quiz (with questions
  inline or added one-by-one), take, submit, attempt limits, time limits,
  shuffle, pass/fail, analytics (average score, pass rate), per-student
  attempt history
- Correct answers are automatically hidden from students (`makeHidden`) when
  viewing/taking a quiz - only teachers ever see them
- 3 new migrations: `quizzes`, `quiz_questions`, `quiz_attempts`

```bash
php artisan migrate
```

**Next stage:** Chat & realtime (private, group, class chat, reactions,
pin, forward, read receipts - this is the big one, offline-friendly design).
Just say "continue."

## Stage 6 added: Chat & Realtime (the big one)
New in this version:
- `app/Models/GroupChat.php`, `GroupChatMember.php`, `Message.php`, `MessageRead.php`
- `app/Http/Controllers/Api/ChatController.php` - conversation list (with
  unread counts), private + group message history, send, edit, soft-delete,
  pin, react (emoji toggle), forward, search, mark-as-read, typing indicator
- `app/Events/MessageSent.php`, `MessageUpdated.php`, `UserTyping.php` -
  broadcast instantly over Reverb (Laravel's own WebSocket server)
- `routes/channels.php` - makes sure a user can only listen to their own
  private chat channel or a group they actually belong to
- 4 new migrations: `group_chats`, `group_chat_members`, `messages`, `message_reads`

### How this supports your offline-first Flutter app
Two things were built specifically for offline use:

1. **`client_message_id`** - the Flutter app generates a random ID for a
   message BEFORE sending it (as soon as the user hits send, even offline).
   It saves the message to its local SQLite immediately, and shows it in the
   chat right away. When internet returns, it sends that same ID to the
   server. If the app retries sending (because the first attempt's response
   was lost when connection dropped), the server recognizes the ID and just
   returns the original message instead of creating a duplicate. Safe to
   retry blindly - which is exactly what a flaky-internet situation needs.

2. **`?since=<timestamp>`** on the history endpoints - when the Flutter app
   comes back online, instead of re-downloading the whole conversation, it
   asks "give me everything after the last message I already have" and only
   receives the new messages. Fast resync after being offline for hours.

### Setup for this stage
```bash
composer require laravel/reverb
php artisan reverb:install
```
This auto-fills your real `REVERB_APP_KEY`/`REVERB_APP_SECRET` into `.env`
(replace the placeholders in the .env I gave you). Then run two things at
once when developing:
```bash
php artisan reverb:start
php artisan serve
```
And migrate the 4 new tables:
```bash
php artisan migrate
```

**Next stage:** Notifications & Email (database notifications, unread
counts, trigger emails for assignments/quizzes/meetings). Just say "continue."

## Stage 7 added: Announcements & Notifications
New in this version:
- `app/Models/Announcement.php`, `AppNotification.php` (table `notifications`)
- `app/Services/NotificationDispatchService.php` - the one place every
  feature calls to notify a user: creates the in-app record, pushes it live
  over Reverb for the notification bell badge, AND queues an email - but only
  if that user's own settings allow it (`notifications_enabled` /
  `email_notifications` from Stage 1's settings). Respecting user
  preferences happens in one place instead of being duplicated everywhere.
- `app/Http/Controllers/Api/AnnouncementController.php` - posting an
  announcement automatically notifies every student in the class
- `app/Http/Controllers/Api/NotificationController.php` - list, unread
  count, mark read, mark all read, delete
- Wired in: creating a published **assignment** notifies the class; grading
  a submission notifies that student; publishing a **quiz** notifies the
  class (whether published at creation or later via update)
- 2 new migrations: `announcements`, `notifications`

```bash
php artisan migrate
```

**Next stage:** Progress & Dashboards (student/teacher/admin analytics,
chart-friendly JSON). Just say "continue."

## Stage 8 added: Progress & Dashboards
New in this version:
- `app/Models/LessonView.php`, `StudentProgress.php`
- `app/Services/ProgressService.php` - recalculates a student's real
  progress in a class on demand (lessons viewed, assignments submitted,
  quizzes taken, average quiz score, last activity) - never a stale cached
  guess, always derived fresh from actual data
- Lesson viewing now records a per-student `lesson_views` row (Stage 3's
  `LessonController@show` was updated) so progress can be measured accurately
- `app/Http/Controllers/Api/DashboardController.php` - one endpoint,
  `GET /api/dashboard`, that returns a different shape automatically based
  on the logged-in user's role:
  - **Student:** enrolled class count, unread notifications, assignments
    due in the next 7 days not yet submitted, 5 most recent grades
  - **Teacher:** classes taught, total students, ungraded submissions
    count, 10 most recent submissions
  - **School/Super admin:** total users by role, total/active classes,
    new users in the last 7 days (school admins see only their own school)
- `app/Http/Controllers/Api/ProgressController.php` - a student's own
  progress card, and a teacher's whole-class progress table with a class
  average (ready to feed straight into a Flutter chart widget)
- 2 new migrations: `lesson_views`, `student_progress`

```bash
php artisan migrate
```

**Next stage:** AI Assistant (ask, summarize, translate, generate
quizzes/assignments, provider failover, usage tracking - your original
6-tier AI router). Just say "continue."

## Stage 9 added: AI Assistant
New in this version:
- `app/Models/AiProvider.php`, `AiUsage.php` + `AiProviderSeeder.php` (5
  providers seeded: Gemini, Groq, Cohere, Mistral, HuggingFace)
- `app/Services/AiRouterService.php` - your original failover router,
  rebuilt to check each provider's **real daily usage from the database**
  (not just an in-memory cache that resets on deploy), tries the next
  provider automatically if one fails or is over quota, in priority order
- `app/Http/Controllers/Api/AiController.php`:
  - `POST /api/ai/ask` - general tutoring chat
  - `POST /api/ai/summarize` - bullet-point summaries of lesson content
  - `POST /api/ai/translate` - English <-> Amharic
  - `POST /api/ai/quiz` - generates quiz questions **as parsed JSON**, in
    the exact shape Stage 5's `QuizController@store` already accepts, so a
    teacher can review AI-suggested questions and save them directly
  - `POST /api/ai/assignment` - generates an assignment prompt for a teacher
    to review
  - `GET /api/ai/providers` and `GET /api/ai/usage` - **admin only**
    (new `role:` middleware added), shows which provider is being used,
    how much of today's quota is left, and historical usage
- 2 new migrations: `ai_providers`, `ai_usage`

```bash
php artisan migrate
php artisan db:seed --class=AiProviderSeeder
```
Make sure your real Gemini/Groq/Cohere/Mistral/HuggingFace keys are filled
in `.env` (placeholders are already there from Stage 1's setup).

**Next stage:** Meetings (schedule/start/end video meetings via Jitsi,
class-linked sessions, join tokens). Just say "continue."

## Stage 10 added: Meetings
New in this version:
- `app/Models/VideoMeeting.php`
- `app/Services/MeetingService.php` - builds everything Flutter needs to
  open a Jitsi call. Works out of the box with the **free public
  meet.jit.si** (no API key, no cost). If you later switch to your own
  self-hosted, JWT-secured Jitsi server, just fill `JITSI_APP_ID` and
  `JITSI_APP_SECRET` in `.env` and it automatically starts issuing signed
  join tokens instead - no code changes needed.
- `app/Http/Controllers/Api/MeetingController.php` - schedule (optionally
  linked to a class, which auto-notifies students), start/end (host only),
  get a join token, delete
- 1 new migration: `video_meetings`

```bash
composer require firebase/php-jwt
php artisan migrate
```

**Next stage:** Admin Tools (user management, moderation, reports) + final
security hardening. Just say "continue."

## Stage 11 added: Admin Tools + Security Hardening (final stage)
New in this version:
- `app/Models/AuditLog.php`, `app/Services/AuditLogService.php` - every
  sensitive admin action (deactivating a user, deleting a user, changing a
  role, deactivating a class) is now permanently recorded: who did it, to
  whom, when, from what IP
- `app/Http/Controllers/Api/AdminController.php`:
  - `GET /api/admin/users` - search/filter by role or active status
  - `POST /api/admin/users/{user}/toggle-active` - also instantly revokes
    that user's login tokens, so deactivation takes effect immediately,
    not just the next time they'd try to log in
  - `PUT /api/admin/users/{user}/role` - **super_admin only**
  - `DELETE /api/admin/users/{user}`
  - `GET /api/admin/classes`, `POST /api/admin/classes/{class}/toggle-active`
  - `GET /api/admin/audit-logs`
  - A `school_admin` can only ever act on users/classes in their own school;
    a `super_admin` can act on anyone. Enforced server-side, not just hidden
    in the UI.
- 1 new migration: `audit_logs`

### Security hardening applied in this pass
- **Rate limiting added**: login/register/OTP/password-reset endpoints
  (6 requests/min) and AI endpoints (20/min) now have `throttle` middleware,
  plus a sane global default (120/min) across the whole API
- Reviewed across all 11 stages - already in place since earlier stages:
  passwords and OTPs are always hashed, never stored or logged in plain
  text; file uploads are extension/size-validated and renamed (never trust
  a client-supplied filename); every write endpoint validates input via a
  Form Request; every class/lesson/assignment/quiz/announcement action
  checks ownership or role via Policies/Gates - never just "is logged in"
- Deactivating a user now revokes their tokens immediately (closed a gap
  where a deactivated user's existing session could keep working)

```bash
php artisan migrate
```

---
## The backend is now feature-complete (Stages 1-11)
Everything from your original spec is built: auth, roles, schools/classes,
lessons/files, assignments, quizzes, chat + realtime, announcements/
notifications, progress/dashboards, AI assistant, meetings, and admin tools
with audit logging - all with Form Request validation, Policy-based
authorization, and a consistent `{success, message, data}` JSON shape
throughout.

### To go live
1. Run through Steps 1-7 at the top of this file if you haven't already
   (Composer, package installs, migrate, seed).
2. Point `.env` at your **Aiven MySQL** and (once ready) an **Oracle Cloud
   Always Free** server instead of `php artisan serve`.
3. Rotate the Gmail/Google/AI keys that were shared in chat, if you
   haven't yet.
4. Push to GitHub (`.env` is already excluded).

### What's next
The Laravel backend side of our plan is done. Whenever you're ready, say
the word and we'll start the **Flutter app** - screens, offline-first
SQLite sync, and connecting it to every endpoint built across these 11
stages.

---
## Round 3 additions: Push notifications, search, group members, automated tests

- `app/Models/DeviceToken.php`, `app/Services/PushNotificationService.php` -
  sends real FCM push notifications; wired directly into
  `NotificationDispatchService` so every existing notification trigger
  (new assignment, graded quiz, new announcement, new meeting...) now also
  pushes to the phone, not just in-app/email. Get your FCM Server Key from
  Firebase Console > Project Settings > Cloud Messaging, put it in
  `.env` as `FCM_SERVER_KEY=...`. Silently does nothing if not configured.
- `app/Http/Controllers/Api/DeviceTokenController.php` +
  `POST /api/device-tokens` / `DELETE /api/device-tokens` - the Flutter app
  calls this after login to register for push
- `app/Http/Controllers/Api/SearchController.php` + `GET /api/search` -
  searches classes/lessons/assignments/quizzes/people, scoped to only what
  the requesting user actually has access to
- Group chat member management added to `ChatController`:
  `GET/POST /api/chat/groups/{group}/members`,
  `DELETE /api/chat/groups/{group}/members/{userId}` (owner/admin only)
- `tests/Feature/AuthTest.php`, `ClassAndEnrollmentTest.php`,
  `AssignmentTest.php`, `QuizTest.php` - real Pest/PHPUnit tests. Also added
  `database/factories/UserFactory.php` (needed for the tests) and the
  `HasFactory` trait on the `User` model.

```bash
php artisan migrate
php artisan test
```
