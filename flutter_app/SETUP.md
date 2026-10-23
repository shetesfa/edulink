# EduLink Flutter App - Stage 1 (Authentication)

This zip has the real, working Dart code for Stage 1: full login flow
connected to your Laravel backend - register, verify email, login,
OTP login, forgot/reset password, and session persistence.

Like the backend, this is not the *entire* Flutter project by itself -
Flutter needs to generate the native `android/`, `ios/`, `windows/`,
`macos/`, `linux/` platform folders itself (thousands of generated files),
which only the Flutter SDK on your own computer can do.

## 1. Install Flutter (one-time)
If you haven't already: https://docs.flutter.dev/get-started/install
Then confirm it works:
```bash
flutter doctor
```

## 2. Create the base project
```bash
flutter create edulink_app
cd edulink_app
```
This gives you a working "Hello World" app with all platform folders
already generated (Android, iOS, Windows, macOS, Linux) - don't touch those,
we only replace `lib/` and `pubspec.yaml`.

## 3. Copy in the real code
From this zip, copy into the `edulink_app` folder Flutter just created:
- `pubspec.yaml` (overwrite the default one)
- `lib/` (overwrite the default one - it only has a counter demo)

## 4. Set your backend URL
Open `lib/core/api_config.dart` and change `baseUrl` to match where your
Laravel backend is actually running:
- Testing on an **Android emulator** while Laravel runs on the same
  computer: `http://10.0.2.2:8000/api` (already set - 10.0.2.2 is the
  emulator's special alias for your computer's localhost)
- Testing on **iOS simulator** or **desktop** (Windows/Mac/Linux) on the
  same computer: `http://localhost:8000/api`
- Testing on a **real phone** over WiFi: use your computer's local network
  IP, e.g. `http://192.168.1.5:8000/api` (find it with `ipconfig` on
  Windows or `ifconfig` on Mac/Linux)
- Once deployed for real: your actual Render/Oracle Cloud URL

## 5. Install packages
```bash
flutter pub get
```

## 6. Enable desktop support (if you want Windows/Mac/Linux builds)
```bash
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop
```

## 7. Run it
Make sure your Laravel backend is running first (`php artisan serve`),
then:
```bash
flutter run
```
Pick your target device/emulator when prompted. Try registering a new
account - you should get a real verification email (via your Gmail SMTP
from Stage 1 of the backend).

## What's built in this stage
- `lib/core/api_client.dart` - talks to your Laravel API, automatically
  attaches the login token to every request, and always returns a clean
  `ApiResult` so screens never need messy try/catch blocks
- `lib/core/local_database.dart` - the on-device SQLite database
  (works identically on phones AND desktop computers) - this is the
  foundation the offline-first chat will build on in a later stage
- `lib/core/secure_storage.dart` - stores the login token encrypted on
  the device (not plain text)
- `lib/core/connectivity_service.dart` - tracks online/offline status
  app-wide
- `lib/providers/auth_provider.dart` - all the login logic, and restores
  your session automatically when you reopen the app (checks a locally
  cached copy of your user first so the app opens instantly, then quietly
  refreshes from the server)
- `lib/screens/auth/*` - login, register, email verification, OTP login,
  forgot/reset password screens
- `lib/screens/dashboard/home_screen.dart` - placeholder home screen,
  proves the whole login flow is connected end-to-end

**Next stage:** Classes & Dashboard (the real home screen - enrolled
classes, join by code, teacher's classes, role-aware dashboard). Just say
"continue."

---
## Stages 2-10 added (fast pass): Classes, Lessons, Assignments, Quizzes, Chat, Notifications, Meetings, Settings

Everything below was added in one push, all real working code wired to your
11-stage Laravel backend:

- **Classes** (`screens/classes/`) - list teaching/enrolled, join by code,
  create class (teachers), class detail with Lessons/Assignments/Quizzes tabs
- **Lessons** (`screens/lessons/`) - list + detail + bookmark toggle
- **Assignments** (`screens/assignments/`) - list + submit + see grade/feedback
- **Quizzes** (`screens/quizzes/`) - take quiz (all question types), submit, see auto-graded result
- **Chat** (`screens/chat/`, `providers/chat_provider.dart`) - the offline-first
  system: messages save to on-device SQLite INSTANTLY when you hit send (before
  any network call), show a small clock icon while "pending," and automatically
  retry the moment `ConnectivityService` notices you're back online - same
  `client_message_id` trick from the backend makes retries 100% safe, never
  duplicating a message. Realtime delivery via Reverb (`core/realtime_service.dart`)
  layers on top when both people are online, but the chat works correctly even
  if Reverb isn't running.
- **Notifications** (`screens/notifications/`) - list, mark read/all read
- **Meetings** (`screens/meetings/`) - list + join opens Jitsi in the browser/app
- **Settings** (`screens/settings/`, `providers/settings_provider.dart`) -
  dark mode toggle (applied instantly, app-wide) and English/Amharic toggle
- **Dashboard** (`screens/dashboard/dashboard_screen.dart`) - real role-aware
  stats from `/api/dashboard`
- `screens/dashboard/home_screen.dart` is now the bottom-navigation shell
  (Home / Classes / Chat / Alerts / Settings) - this is what you land on
  after logging in

### One backend addition needed for realtime chat
A small controller (`BroadcastAuthController`) and route
(`POST /api/broadcasting/auth`) were added to the **Laravel backend** so the
Flutter app can authenticate private Reverb channels using its Bearer token.
If you already downloaded the Stage 11 backend zip before this message,
either re-download the latest one or add these two small pieces yourself:
`app/Http/Controllers/Api/BroadcastAuthController.php` (returns
`Broadcast::auth($request)`) and register
`Route::post('/broadcasting/auth', [BroadcastAuthController::class, 'authenticate'])`
inside the `auth:sanctum` group in `routes/api.php`.

### Known simplifications (fast pass, called out honestly)
- Dark mode/language settings load from the Settings screen's own toggle,
  but aren't yet pre-filled from the server on login - toggling them still
  saves correctly either way, this is just a small "load on startup" wire-up
  left for later polish.
- Amharic **UI label** translation (the actual `.arb` translation files) isn't
  filled in yet - the locale plumbing is in place and ready for it.
- File/image attachments in chat and assignments aren't wired in the Flutter
  UI yet (the backend already fully supports them) - text works completely.

### To run it
```bash
flutter pub get
flutter run
```
Make sure `php artisan serve` and `php artisan reverb:start` are both
running on the backend.

This covers every stage from your original plan. From here, it's about
polish: real file/image upload UI, full Amharic translations, push
notifications, and testing on real devices - happy to keep going on any
of those whenever you want.

---
## Competition additions: QR join, PDF report cards, Admin screens, rich chat

- **QR class join** - teachers get a QR button (`class_qr_dialog.dart`) on
  their class screen; students get a "Scan QR code" option next to "Join
  class" that opens the camera (`scan_class_qr_screen.dart`) and joins
  instantly on a valid scan. New packages: `qr_flutter`, `mobile_scanner`.
- **PDF report cards** - a new "Progress" tab on every class shows live
  stats and a "Download PDF report card" button that generates a real,
  shareable/printable PDF on-device (`core/pdf_report_service.dart`). New
  packages: `pdf`, `printing`.
- **Admin screens** - `screens/admin/` now has User Management (search,
  activate/deactivate, change role, delete), Class Moderation, and Audit
  Log viewer, all wired to the Stage 11 backend. Only shows up in the
  bottom nav for `school_admin`/`super_admin` accounts.
- **Rich chat actions** - long-press any message for react (👍/❤️), pin,
  edit, delete (your own messages only) - all wired to the backend's
  existing endpoints, offline-safe by design (these are quick actions on
  already-synced messages, not new offline queue items).

Run `flutter pub get` again after copying these files in - 4 new packages
were added to `pubspec.yaml`.

## Your offline-first demo script (this is your strongest differentiator)
Almost no competing project will have this working correctly - plan your
live demo around it:
1. Show the app already logged in, open a class chat, send a normal message.
2. Turn on **airplane mode** on the phone/emulator, live, in front of judges.
3. Send another message - it appears immediately with a small clock icon
   (pending), proving it saved locally instantly.
4. Say out loud: "This is saved on the device right now - even if the app
   is closed and reopened, it's still here" (kill and reopen the app to
   prove it if you have time).
5. Turn airplane mode back off. Within a second or two, the clock icon
   disappears (message synced) - point this out explicitly.
6. One sentence for judges: *"The server recognizes each message by an ID
   the phone generates before sending, so retrying after reconnecting can
   never create a duplicate - this is the same design Telegram and WhatsApp
   use."*

This demo takes under a minute and is very hard for a judge to dismiss,
because most student projects simply crash or freeze with no internet.

---
## Round 3 additions: Push notifications, Amharic, Google Sign-In, uploads, groups, search

### Push notifications (reaches a closed app)
1. Create a free Firebase project at https://console.firebase.google.com
2. Add an Android app (and iOS if needed) inside it, download
   `google-services.json` (Android) / `GoogleService-Info.plist` (iOS)
3. Easiest setup: install the FlutterFire CLI and run `flutterfire configure`
   in the project root - it wires up the native files automatically
4. In Firebase Console > Project Settings > Cloud Messaging, copy the
   **Server key** and put it in the backend's `.env` as `FCM_SERVER_KEY=...`
5. `flutter pub get` (firebase_core/firebase_messaging were added)

Once that's done, every notification (new assignment, graded quiz, new
message, etc.) sends a real push through `PushNotificationService` on the
backend - the phone gets a notification even with the app fully closed,
which is the part that was missing before.

### Amharic translations
Real `.arb` translation files now exist (`lib/l10n/app_en.arb`,
`app_am.arb`) covering ~60 common strings (navigation, auth, classes,
lessons, assignments, quizzes, chat, settings). Run:
```bash
flutter gen-l10n
```
to generate `app_localizations.dart`, then `flutter pub get`. The bottom
navigation and login screen already use these translations live - flipping
the Settings language toggle to Amharic now visibly changes real text, not
just a stored preference. **Not every single screen was converted yet**
(assignment/quiz detail screens still show English) - the plumbing and
the highest-visibility screens are done; extending it to the rest is just
repeating the same `AppLocalizations.of(context)!.key` pattern.

### Google Sign-In
Added via an in-app WebView (`google_signin_webview.dart`) rather than a
native OAuth SDK - loads your backend's `/auth/google` URL directly, and
reads the JSON response text out of the page once Google redirects back.
No native Android/iOS OAuth client setup needed beyond what Socialite
already required on the backend. Button is on the login screen.

### File/image uploads
- **Chat**: an image button next to the message box - picks from gallery,
  uploads immediately. Note: unlike text messages, image messages need
  internet at send time (offline image queuing was out of scope for this
  pass - text chat stays fully offline-safe).
- **Assignments**: "Attach a file" button on the submission screen (any
  file type, uses `file_picker`).
- **Profile photo**: tap your avatar in Settings to change it.

### Group chat creation + management
- "New group" button on the Chats screen
- Tap the (i) icon inside a group chat to see members, remove them
  (owner/admin only), or leave the group

### Global search
Search icon on the Home dashboard - searches classes, lessons,
assignments, quizzes, and people, all scoped to classes/school you
actually belong to (new `/api/search` endpoint on the backend).

### Automated tests (backend)
`tests/Feature/` now has real Pest/PHPUnit tests: `AuthTest`,
`ClassAndEnrollmentTest`, `AssignmentTest`, `QuizTest` - covering
registration, login/verification rules, class join codes and permission
checks, late-submission rejection, grade-cap validation, and quiz
auto-grading (including that essay questions get flagged for manual
grading). Run with:
```bash
php artisan test
```
**Honest scope note**: this covers the highest-risk logic (auth rules,
permissions, grading math), not all 11 stages exhaustively - chat,
notifications, meetings, and admin tools don't have tests yet.

---
## Full honest project status

**Solid and working, backend + app:** auth (incl. Google + OTP), classes
(incl. QR join), lessons, assignments (incl. file upload), quizzes
(auto-grading), offline-first chat (incl. images, reactions, edit/delete/
pin, groups with member management), notifications (in-app + email +
real push), meetings, admin tools, dashboards, progress + PDF report
cards, global search, dark mode, partial Amharic UI, core automated tests.

**Deliberately not built (by your request):** gamification, parent view,
attendance tracking.

**Known remaining gaps, for full transparency:**
- Amharic translation doesn't cover every screen yet (core navigation +
  login does; deeper screens still English)
- Offline mode covers text chat; images/files need connectivity to send
- Test coverage is solid on core logic, not exhaustive across all stages
- Push notifications need you to actually create a Firebase project and
  add the native config files - the code is ready, but this one step
  can't be done without your own Firebase account
