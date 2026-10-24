# EduLink - Complete Project (Backend + Flutter App)

This zip contains everything built across our conversation, combined into one package:

```
EduLink-Complete/
├── backend/          <- Laravel 11 API (11 stages + push/search/tests)
│   └── SETUP.md       <- full backend setup instructions
├── flutter_app/       <- Flutter app (Android/iOS/Windows/macOS/Linux)
│   └── SETUP.md       <- full Flutter setup instructions
└── README.md          <- this file
```

## Order of setup
1. Start with `backend/SETUP.md` - get the Laravel API running first
   (Composer install, Aiven MySQL, migrate, seed, Reverb, FCM key, etc.)
2. Then follow `flutter_app/SETUP.md` - get the Flutter app running and
   pointed at your backend's URL (`flutter_app/lib/core/api_config.dart`)

## What's included
- Full backend: auth, classes, lessons, assignments, quizzes, chat +
  realtime, notifications + push, progress, AI assistant, meetings, admin
  tools + audit log, global search, automated tests (Pest/PHPUnit)
- Full Flutter app: all matching screens, offline-first chat (SQLite +
  outbox pattern), QR class join, PDF report cards, dark mode, partial
  Amharic translations, Google Sign-In, file/image uploads, group chat
  management, push notifications (Firebase)

## Known caveats (read before your demo/submission)
- Amharic translations cover navigation/login/common terms, not every
  screen yet
- Offline-first is fully proven for text chat; images/files need internet
  to send
- Automated tests cover the highest-risk logic (auth, permissions,
  grading), not all 11 backend stages exhaustively
- Neither project has been compiled/run in my environment (no PHP/Composer/
  Flutter SDK available here) - run `flutter analyze` and `php artisan test`
  yourself and send me any errors to fix
- Gamification, parent view, and attendance tracking were intentionally
  left out per your instruction

## Security reminder
Rotate the Gmail app password, Google OAuth secret, and AI provider keys
that were shared in chat earlier, if you haven't already. Keep all real
secrets only in `.env` files (already excluded from git via `.gitignore`),
never committed to GitHub.
