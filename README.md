# 🎓 EduLink - Modern Full-Stack LMS & Educational Platform

![Laravel](https://img.shields.io/badge/Laravel-FF2D20?style=for-the-badge&logo=laravel&logoColor=white)
![React](https://img.shields.io/badge/React-61DAFB?style=for-the-badge&logo=react&logoColor=black)
![Vite](https://img.shields.io/badge/Vite-646CFF?style=for-the-badge&logo=vite&logoColor=white)
![TailwindCSS](https://img.shields.io/badge/TailwindCSS-06B6D4?style=for-the-badge&logo=tailwindcss&logoColor=white)
![AI Enabled](https://img.shields.io/badge/AI-Assistant-brightgreen?style=for-the-badge)

A state-of-the-art Learning Management System (LMS) built with Laravel RESTful API backend, React + Vite frontend, interactive AI assistant, real-time messaging, and online video meetings.

## ✨ Highlights
- 🤖 **AI Learning Assistant**: Integrated AI tutor for instant academic questions & quiz generation (`AIAssistant.jsx`, `AIController.php`).
- 📹 **Live Video Meetings**: Video conference support for online classes and virtual office hours (`VideoMeeting.jsx`).
- 📝 **Assignments & Quizzes**: Interactive quiz builder, real-time grading, and file submissions (`QuizCreate.jsx`, `AssignmentView.jsx`).
- 💬 **Real-time Chat**: Group chat rooms and direct messaging using WebSocket service (`realtime/server.js`).
- 📱 **Mobile Native Ready**: Capacitor configuration for building Android & iOS apps (`mobile/capacitor.config.json`).

## 🛠️ Setup & Running
### Backend (Laravel)
```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate --seed
php artisan serve
```

### Frontend (React + Vite)
```bash
cd frontend
npm install
npm run dev
```

---
Developed by **[shetesfa](https://github.com/shetesfa)**
