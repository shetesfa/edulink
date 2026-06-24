import React, { useEffect, Suspense, lazy } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { Analytics } from '@vercel/analytics/react';
import { useAuthStore } from '@/store';
import { authAPI } from '@/utils/api';
import AppLayout from '@/components/shared/AppLayout';
import AuthLayout from '@/components/shared/AuthLayout';
import LoadingScreen from '@/components/shared/LoadingScreen';

// ─── Lazy-loaded pages ────────────────────────────────────────
const Landing          = lazy(() => import('@/pages/Landing'));
const Login            = lazy(() => import('@/pages/auth/Login'));
const Register         = lazy(() => import('@/pages/auth/Register'));
const ForgotPassword   = lazy(() => import('@/pages/auth/ForgotPassword'));
const ResetPassword    = lazy(() => import('@/pages/auth/ResetPassword'));

const StudentDashboard = lazy(() => import('@/pages/student/Dashboard'));
const TeacherDashboard = lazy(() => import('@/pages/teacher/Dashboard'));
const AdminDashboard   = lazy(() => import('@/pages/admin/Dashboard'));

const Classes          = lazy(() => import('@/pages/classes/Classes'));
const ClassDetail      = lazy(() => import('@/pages/classes/ClassDetail'));
const LessonView       = lazy(() => import('@/pages/classes/LessonView'));
const AssignmentView   = lazy(() => import('@/pages/classes/AssignmentView'));
const QuizTake         = lazy(() => import('@/pages/classes/QuizTake'));
const QuizResult       = lazy(() => import('@/pages/classes/QuizResult'));

const Chat             = lazy(() => import('@/pages/chat/Chat'));
const VideoMeeting     = lazy(() => import('@/pages/meeting/VideoMeeting'));
const Meetings         = lazy(() => import('@/pages/meeting/Meetings'));
const AIAssistant      = lazy(() => import('@/pages/ai/AIAssistant'));

const Profile          = lazy(() => import('@/pages/Profile'));
const Settings         = lazy(() => import('@/pages/Settings'));
const Search           = lazy(() => import('@/pages/Search'));
const NotFound         = lazy(() => import('@/pages/NotFound'));

// ─── Route guards ─────────────────────────────────────────────
function ProtectedRoute({ children, roles }) {
  const { isAuthenticated, user } = useAuthStore();
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  if (roles && !roles.includes(user?.role)) return <Navigate to="/dashboard" replace />;
  return children;
}

function GuestRoute({ children }) {
  const { isAuthenticated } = useAuthStore();
  if (isAuthenticated) return <Navigate to="/dashboard" replace />;
  return children;
}

function DashboardRedirect() {
  const { user } = useAuthStore();
  const routes = { student: '/student', teacher: '/teacher', school_admin: '/admin' };
  return <Navigate to={routes[user?.role] || '/student'} replace />;
}

// ─── App component ────────────────────────────────────────────
export default function App() {
  const { isAuthenticated, token, setAuth, connectSocket } = useAuthStore();

  // Restore session on page load
  useEffect(() => {
    if (token && isAuthenticated) {
      authAPI.me()
        .then(({ data }) => {
          setAuth(data.user, token);
          connectSocket();
        })
        .catch(() => useAuthStore.getState().logout());
    }
  }, []);

  // Apply dark mode class
  useEffect(() => {
    const { user } = useAuthStore.getState();
    if (user?.settings?.dark_mode) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, []);

  return (
    <BrowserRouter>
      <Toaster
        position="top-right"
        toastOptions={{
          duration: 4000,
          style: { fontFamily: 'Inter, sans-serif', fontSize: '14px' },
          success: { iconTheme: { primary: '#10B981', secondary: '#fff' } },
          error:   { iconTheme: { primary: '#EF4444', secondary: '#fff' } },
        }}
      />
      <Analytics />

      <Suspense fallback={<LoadingScreen />}>
        <Routes>
          {/* ── Public ──────────────────────────────────────── */}
          <Route path="/" element={<Landing />} />

          <Route element={<AuthLayout />}>
            <Route path="/login"    element={<GuestRoute><Login /></GuestRoute>} />
            <Route path="/register" element={<GuestRoute><Register /></GuestRoute>} />
            <Route path="/forgot-password" element={<GuestRoute><ForgotPassword /></GuestRoute>} />
            <Route path="/reset-password"  element={<GuestRoute><ResetPassword /></GuestRoute>} />
          </Route>

          {/* ── App (authenticated) ─────────────────────────── */}
          <Route element={<ProtectedRoute><AppLayout /></ProtectedRoute>}>
            <Route path="/dashboard" element={<DashboardRedirect />} />

            {/* Student */}
            <Route path="/student" element={<ProtectedRoute roles={['student']}><StudentDashboard /></ProtectedRoute>} />

            {/* Teacher */}
            <Route path="/teacher" element={<ProtectedRoute roles={['teacher']}><TeacherDashboard /></ProtectedRoute>} />

            {/* Admin */}
            <Route path="/admin"   element={<ProtectedRoute roles={['school_admin']}><AdminDashboard /></ProtectedRoute>} />

            {/* Classes */}
            <Route path="/classes"                               element={<Classes />} />
            <Route path="/classes/:classId"                      element={<ClassDetail />} />
            <Route path="/classes/:classId/lessons/:lessonId"    element={<LessonView />} />
            <Route path="/classes/:classId/assignments/:id"      element={<AssignmentView />} />
            <Route path="/classes/:classId/quizzes/:quizId/take" element={<QuizTake />} />
            <Route path="/classes/:classId/quizzes/:quizId/result" element={<QuizResult />} />

            {/* Chat */}
            <Route path="/chat"           element={<Chat />} />
            <Route path="/chat/:type/:id" element={<Chat />} />

            {/* AI */}
            <Route path="/ai" element={<AIAssistant />} />

            {/* Video */}
            <Route path="/meetings" element={<Meetings />} />
            <Route path="/meetings/:id" element={<VideoMeeting />} />

            {/* Profile & Settings */}
            <Route path="/profile"          element={<Profile />} />
            <Route path="/profile/:username" element={<Profile />} />
            <Route path="/settings"         element={<Settings />} />
            <Route path="/search"           element={<Search />} />
          </Route>

          <Route path="*" element={<NotFound />} />
        </Routes>
      </Suspense>
    </BrowserRouter>
  );
}
