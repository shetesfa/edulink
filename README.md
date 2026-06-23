# EduLink — Learn, Teach & Connect

A complete, production-ready school communication and learning platform inspired by Telegram, Discord, Google Classroom, and Microsoft Teams.

---

## ✨ Features

| Feature | Description |
|---|---|
| 💬 **Real-time Chat** | Telegram-style private & group chat with reactions, replies, edit/delete, file sharing, typing indicators |
| 📚 **Lesson Library** | Upload PDFs, videos, notes. Students bookmark, comment, download |
| ✏️ **Assignments** | Create, submit, grade with file attachments. Automatic late detection |
| 🧠 **Smart Quizzes** | MCQ, True/False, Fill-in-blank, Essay. Auto-graded with analytics |
| 🎥 **Video Meetings** | Jitsi-powered HD video with screen share, raise hand, chat, recording |
| 🤖 **AI Assistant** | 6-provider failover — always free, never stops. Amharic + English |
| 📊 **Progress Tracking** | Per-student, per-class dashboards with charts |
| 🔔 **Notifications** | Real-time push, email, browser notifications |
| 🔍 **Global Search** | Search students, classes, lessons, assignments, quizzes |
| 📱 **Mobile App** | PWA installs on phone + Capacitor builds real Android APK & iOS |
| 🌙 **Dark Mode** | Full dark/light theme with 5 color options |
| 🇪🇹 **Amharic Support** | Full Amharic language support throughout the platform |

---

## 🏗️ Architecture

```
Browser / Android APK / iOS App
           ↓ HTTPS
    Nginx (port 443)
     ├── /api        → Laravel PHP-FPM (REST API)
     ├── /socket.io  → Node.js Socket.io (real-time)
     ├── /storage    → Uploaded files
     └── /*          → React SPA (PWA)

Laravel ←→ MySQL   (all data)
Laravel ←→ Redis   (cache, sessions, queues)
Node.js ←→ Redis   (online presence, pub/sub)
Laravel  →  Firebase (push notifications)
Laravel  →  AI Pool  (Gemini → Groq → Cohere → Mistral → Together → HuggingFace)
```

---

## 🤖 AI Failover System

The AI never stops working for students. 6 free providers in a pool:

| Priority | Provider | Free Daily Limit | Speed |
|---|---|---|---|
| 1 | Google Gemini | 1,500 requests | Fast |
| 2 | Groq (Llama 3) | 14,400 requests | Ultra fast |
| 3 | Cohere | 1,000 requests | Fast |
| 4 | Mistral AI | 1,000 requests | Fast |
| 5 | Together AI | 1,000 requests | Medium |
| 6 | HuggingFace | Unlimited | Slower |

**Total daily capacity: ~20,000+ requests** — all free.

---

## 📁 Project Structure

```
edulink/
├── backend/                    Laravel PHP API
│   ├── app/
│   │   ├── Http/Controllers/   60+ API endpoints
│   │   ├── Models/             All Eloquent models
│   │   └── Services/
│   │       └── AIRouterService.php  ← AI failover engine
│   ├── database/
│   │   └── migrations/
│   │       └── 001_create_all_tables.sql  ← 26 tables
│   └── routes/api.php
│
├── realtime/                   Node.js Socket.io server
│   └── server.js
│
├── frontend/                   React PWA
│   └── src/
│       ├── pages/
│       │   ├── auth/           Login, Register, ForgotPassword, ResetPassword
│       │   ├── student/        Dashboard
│       │   ├── teacher/        Dashboard
│       │   ├── admin/          Dashboard + user management + AI status
│       │   ├── classes/        Classes, ClassDetail, LessonView, AssignmentView, QuizTake, QuizResult
│       │   ├── chat/           Full Telegram-style chat
│       │   ├── meeting/        Jitsi video meeting
│       │   ├── ai/             AI Assistant
│       │   ├── Profile.jsx
│       │   ├── Settings.jsx
│       │   └── Search.jsx
│       ├── components/shared/  AppLayout, AuthLayout, Avatar, NotificationPanel
│       ├── store/              Zustand (auth, chat, notifications, UI)
│       └── utils/api.js        All API calls
│
├── mobile/
│   └── capacitor.config.json   Android/iOS app config
│
├── docs/
│   ├── DEPLOYMENT.md           Full deployment guide
│   └── nginx.conf              Production Nginx config
│
├── ecosystem.config.js         PM2 process manager
└── setup.sh                    One-command server setup
```

---

## 🚀 Quick Start

### Development

```bash
# 1. Clone and set up backend
cd backend
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate  # or import 001_create_all_tables.sql
php artisan serve

# 2. Start real-time server
cd realtime
npm install
node server.js

# 3. Start frontend
cd frontend
npm install
npm run dev
# Visit http://localhost:3000
```

### Production (one command)

```bash
# Upload project to /var/www/edulink on your Ubuntu server
chmod +x setup.sh
sudo ./setup.sh
# Then edit backend/.env with your API keys
pm2 restart all
```

---

## 🔑 Required API Keys (all free)

Edit `backend/.env` after setup:

```env
# AI Providers (get all 6 for maximum uptime)
GEMINI_API_KEY=      # makersuite.google.com
GROQ_API_KEY=        # console.groq.com
COHERE_API_KEY=      # dashboard.cohere.com
MISTRAL_API_KEY=     # console.mistral.ai
TOGETHER_API_KEY=    # api.together.xyz
HUGGINGFACE_API_KEY= # huggingface.co/settings/tokens

# Google OAuth
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=

# Firebase (push notifications)
FIREBASE_PROJECT_ID=
```

---

## 📱 Mobile App Build

```bash
cd frontend

# PWA (works immediately — users can "Add to Home Screen")
npm run build

# Android APK
npm install @capacitor/core @capacitor/cli @capacitor/android
npx cap add android
npx cap sync android
cd android && ./gradlew assembleRelease
# APK: android/app/build/outputs/apk/release/app-release.apk

# iOS (Mac + Xcode required)
npx cap add ios
npx cap sync ios
npx cap open ios  # Build and sign in Xcode
```

---

## 👥 User Roles

| Role | Can do |
|---|---|
| **Student** | Join classes, view lessons, submit assignments, take quizzes, chat, video meetings, AI assistant |
| **Teacher** | Create classes, upload lessons, create assignments & quizzes, grade, post announcements, start meetings |
| **School Admin** | Manage all users and classes, view reports, monitor AI usage |

---

## 🛡️ Security Features

- JWT tokens with configurable expiry
- Google OAuth 2.0
- bcrypt password hashing
- CSRF protection
- Rate limiting (120 req/min API, 100 req/hr AI)
- Input sanitization
- XSS/SQL injection prevention
- HTTPS enforced
- Security headers (CSP, HSTS, X-Frame-Options)

---

## 📞 Support

Built for Ethiopian educational institutions. Supports **Amharic** and **English** throughout.

---

*EduLink © 2026 — Made with ❤️ for Ethiopian education*
