import React, { useEffect, Suspense, lazy } from 'react';
import { BrowserRouter, Routes, Route, Navigate, Outlet } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
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
const Classes          = lazy(() => import('@/pages/classes/Classes'));
const ClassDetail      = lazy(() => import('@/pages/classes/ClassDetail'));
const LessonView       = lazy(() => import('@/pages/classes/LessonView'));
const AssignmentView   = lazy(() => import('@/pages/classes/AssignmentView'));
const AssignmentCreate = lazy(() => import('@/pages/classes/AssignmentCreate'));
const QuizCreate       = lazy(() => import('@/pages/classes/QuizCreate'));
const QuizTake         = lazy(() => import('@/pages/classes/QuizTake'));
const QuizResult       = lazy(() => import('@/pages/classes/QuizResult'));

const Chat             = lazy(() => import('@/pages/chat/Chat'));
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
  return children ? children : <Outlet />;
}

function GuestRoute({ children }) {
  const { isAuthenticated } = useAuthStore();
  if (isAuthenticated) return <Navigate to="/dashboard" replace />;
  return children;
}

function DashboardRedirect() {
  const { user } = useAuthStore();
  const routes = { student: '/student', teacher: '/teacher' };
  return <Navigate to={routes[user?.role] || '/student'} replace />;
}

const COLOR_PALETTES = {
  purple: {
    50: '#f5f3ff',
    100: '#ede9fe',
    200: '#ddd6fe',
    300: '#c4b5fd',
    400: '#a78bfa',
    500: '#8b5cf6',
    600: '#7c3aed',
    700: '#6d28d9',
    800: '#5b21b6',
    900: '#4c1d95',
    950: '#1E1B4B',
    gradient: 'linear-gradient(135deg, #7c3aed 0%, #a855f7 50%, #c084fc 100%)',
    gradientDark: 'linear-gradient(135deg, #5b21b6 0%, #7c3aed 50%, #a855f7 100%)',
    gradientLight: 'linear-gradient(135deg, #ede9fe 0%, #c4b5fd 50%, #a78bfa 100%)',
    glow: 'rgba(124, 58, 237, 0.5)',
  },
  blue: {
    50: '#eff6ff',
    100: '#dbeafe',
    200: '#bfdbfe',
    300: '#93c5fd',
    400: '#60a5fa',
    500: '#3b82f6',
    600: '#2563eb',
    700: '#1d4ed8',
    800: '#1e40af',
    900: '#1e3a8a',
    950: '#172554',
    gradient: 'linear-gradient(135deg, #2563eb 0%, #3b82f6 50%, #60a5fa 100%)',
    gradientDark: 'linear-gradient(135deg, #1e40af 0%, #2563eb 50%, #3b82f6 100%)',
    gradientLight: 'linear-gradient(135deg, #dbeafe 0%, #93c5fd 50%, #60a5fa 100%)',
    glow: 'rgba(37, 99, 235, 0.5)',
  },
  green: {
    50: '#f0fdf4',
    100: '#dcfce7',
    200: '#bbf7d0',
    300: '#86efac',
    400: '#4ade80',
    500: '#22c55e',
    600: '#16a34a',
    700: '#15803d',
    800: '#166534',
    900: '#14532d',
    950: '#052e16',
    gradient: 'linear-gradient(135deg, #16a34a 0%, #22c55e 50%, #4ade80 100%)',
    gradientDark: 'linear-gradient(135deg, #166534 0%, #16a34a 50%, #22c55e 100%)',
    gradientLight: 'linear-gradient(135deg, #dcfce7 0%, #86efac 50%, #4ade80 100%)',
    glow: 'rgba(22, 163, 74, 0.5)',
  },
  orange: {
    50: '#fff7ed',
    100: '#ffedd5',
    200: '#fed7aa',
    300: '#fdba74',
    400: '#fb923c',
    500: '#f97316',
    600: '#ea580c',
    700: '#c2410c',
    800: '#9a3412',
    900: '#7c2d12',
    950: '#431407',
    gradient: 'linear-gradient(135deg, #ea580c 0%, #f97316 50%, #fb923c 100%)',
    gradientDark: 'linear-gradient(135deg, #9a3412 0%, #ea580c 50%, #f97316 100%)',
    gradientLight: 'linear-gradient(135deg, #ffedd5 0%, #fdba74 50%, #fb923c 100%)',
    glow: 'rgba(234, 88, 12, 0.5)',
  },
  pink: {
    50: '#fdf2f8',
    100: '#fce7f3',
    200: '#fbcfe8',
    300: '#f9a8d4',
    400: '#f472b6',
    500: '#ec4899',
    600: '#db2777',
    700: '#be185d',
    800: '#9d174d',
    900: '#831843',
    950: '#500724',
    gradient: 'linear-gradient(135deg, #db2777 0%, #ec4899 50%, #f472b6 100%)',
    gradientDark: 'linear-gradient(135deg, #9d174d 0%, #db2777 50%, #ec4899 100%)',
    gradientLight: 'linear-gradient(135deg, #fce7f3 0%, #f9a8d4 50%, #f472b6 100%)',
    glow: 'rgba(219, 39, 119, 0.5)',
  },
};

// ─── App component ────────────────────────────────────────────
export default function App() {
  const { isAuthenticated, token, setAuth, connectSocket, user } = useAuthStore();

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

  // Reactively apply user settings (dark mode, theme, font size) globally
  useEffect(() => {
    // 1. Dark Mode
    const darkMode = user?.settings?.dark_mode ?? false;
    document.documentElement.classList.toggle('dark', darkMode);

    // 2. Theme Color
    const theme = user?.settings?.theme ?? 'purple';
    const palette = COLOR_PALETTES[theme] || COLOR_PALETTES.purple;
    Object.keys(palette).forEach(key => {
      document.documentElement.style.setProperty(`--brand-${key}`, palette[key]);
    });

    // 3. Font Size
    const size = user?.settings?.font_size ?? 'medium';
    const sizes = { small: '14px', medium: '16px', large: '18px' };
    const fontSize = sizes[size] || sizes.medium;
    document.documentElement.style.setProperty('--base-font-size', fontSize);
    document.documentElement.style.fontSize = fontSize;
  }, [user]);

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

            {/* Classes */}
            <Route path="/classes"                               element={<Classes />} />
            <Route path="/classes/:classId"                      element={<ClassDetail />} />
            <Route path="/classes/:classId/lessons/:lessonId"    element={<LessonView />} />
            <Route path="/classes/:classId/assignments/new"       element={<AssignmentCreate />} />
            <Route path="/classes/:classId/assignments/:id"       element={<AssignmentView />} />
            <Route path="/classes/:classId/quizzes/new"          element={<QuizCreate />} />
            <Route path="/classes/:classId/quizzes/:quizId/take" element={<QuizTake />} />
            <Route path="/classes/:classId/quizzes/:quizId/result" element={<QuizResult />} />

            {/* Chat */}
            <Route path="/chat"           element={<Chat />} />
            <Route path="/chat/:type/:id" element={<Chat />} />

            {/* AI */}
            <Route path="/ai" element={<AIAssistant />} />

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
