// ─── LOGIN PAGE ───────────────────────────────────────────────
import React, { useState, useEffect } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Eye, EyeOff, Mail, Lock, Loader2 } from 'lucide-react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { authAPI } from '@/utils/api';
import { useAuthStore } from '@/store';
import toast from 'react-hot-toast';
import clsx from 'clsx';

const loginSchema = z.object({
  email:       z.string().email('Enter a valid email'),
  password:    z.string().min(1, 'Password is required'),
  remember_me: z.boolean().optional(),
});

// Google SVG icon reused across Login and Register
function GoogleIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24">
      <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
      <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
      <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
      <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
    </svg>
  );
}

export function Login() {
  const navigate               = useNavigate();
  const [searchParams]         = useSearchParams();
  const { setAuth, connectSocket } = useAuthStore();
  const [showPwd, setShowPwd]  = useState(false);
  const [googleLoading, setGoogleLoading] = useState(false);

  // ── Handle Google OAuth redirect (backend sends ?token=XXX) ──
  useEffect(() => {
    const token = searchParams.get('token');
    const error = searchParams.get('error');

    if (error) {
      toast.error('Google sign-in failed. Please try again.');
      return;
    }

    if (token) {
      setGoogleLoading(true);

      // Manually call /auth/me with the token from URL
      fetch(`${import.meta.env.VITE_API_URL || 'http://localhost:8000/api'}/auth/me`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Accept': 'application/json',
        },
      })
        .then((r) => r.json())
        .then(({ user }) => {
          if (!user) throw new Error('No user');
          setAuth(user, token);
          connectSocket();
          toast.success(`Welcome, ${user.first_name}! 🎉`);
          navigate('/dashboard', { replace: true });
        })
        .catch(() => {
          toast.error('Google sign-in failed. Please try again.');
          setGoogleLoading(false);
        });
    }
  }, []);   // eslint-disable-line

  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm({
    resolver: zodResolver(loginSchema),
  });

  const onSubmit = async (values) => {
    try {
      const { data } = await authAPI.login(values);
      setAuth(data.user, data.token);
      connectSocket();
      toast.success(`Welcome back, ${data.user.first_name}! 👋`);
      navigate('/dashboard');
    } catch (err) {
      const msg = err.response?.data?.message || 'Invalid credentials';
      toast.error(msg);
    }
  };

  // Show a spinner while we're processing the Google callback token
  if (googleLoading) {
    return (
      <div className="flex flex-col items-center justify-center gap-4 py-20">
        <Loader2 size={40} className="animate-spin text-brand-600" />
        <p className="text-gray-500 text-sm">Signing you in with Google…</p>
      </div>
    );
  }

  return (
    <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} className="w-full max-w-sm mx-auto">
      <div className="text-center mb-8">
        <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white">Welcome back</h1>
        <p className="text-gray-400 text-sm mt-1">Sign in to your EduLink account</p>
      </div>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        {/* Email */}
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">Email address</label>
          <div className="relative">
            <Mail size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              {...register('email')}
              type="email"
              placeholder="you@school.com"
              className={clsx(
                'w-full pl-10 pr-4 py-2.5 rounded-xl border text-sm outline-none transition-all bg-white dark:bg-gray-700 dark:text-white',
                errors.email
                  ? 'border-red-300 focus:border-red-400 focus:ring-2 focus:ring-red-100'
                  : 'border-gray-200 dark:border-gray-600 focus:border-brand-400 focus:ring-2 focus:ring-brand-100 dark:focus:ring-brand-900/30'
              )}
            />
          </div>
          {errors.email && <p className="text-xs text-red-500 mt-1">{errors.email.message}</p>}
        </div>

        {/* Password */}
        <div>
          <div className="flex items-center justify-between mb-1.5">
            <label className="text-sm font-medium text-gray-700 dark:text-gray-300">Password</label>
            <Link to="/forgot-password" className="text-xs text-brand-600 hover:text-brand-700 font-medium">Forgot password?</Link>
          </div>
          <div className="relative">
            <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              {...register('password')}
              type={showPwd ? 'text' : 'password'}
              placeholder="••••••••"
              className={clsx(
                'w-full pl-10 pr-10 py-2.5 rounded-xl border text-sm outline-none transition-all bg-white dark:bg-gray-700 dark:text-white',
                errors.password
                  ? 'border-red-300 focus:border-red-400 focus:ring-2 focus:ring-red-100'
                  : 'border-gray-200 dark:border-gray-600 focus:border-brand-400 focus:ring-2 focus:ring-brand-100 dark:focus:ring-brand-900/30'
              )}
            />
            <button type="button" onClick={() => setShowPwd(!showPwd)} className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
              {showPwd ? <EyeOff size={16} /> : <Eye size={16} />}
            </button>
          </div>
          {errors.password && <p className="text-xs text-red-500 mt-1">{errors.password.message}</p>}
        </div>

        {/* Remember me */}
        <label className="flex items-center gap-2 cursor-pointer">
          <input {...register('remember_me')} type="checkbox" className="w-4 h-4 rounded border-gray-300 text-brand-600 focus:ring-brand-500" />
          <span className="text-sm text-gray-600 dark:text-gray-300">Remember me for 30 days</span>
        </label>

        {/* Submit */}
        <button
          type="submit"
          disabled={isSubmitting}
          className="w-full flex items-center justify-center gap-2 py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-xl text-sm transition-all shadow-md hover:shadow-lg"
        >
          {isSubmitting ? <Loader2 size={16} className="animate-spin" /> : 'Sign in'}
        </button>

        {/* Divider */}
        <div className="relative flex items-center gap-3">
          <div className="flex-1 h-px bg-gray-200 dark:bg-gray-600" />
          <span className="text-xs text-gray-400">or</span>
          <div className="flex-1 h-px bg-gray-200 dark:bg-gray-600" />
        </div>

        {/* Google */}
        <button
          type="button"
          onClick={() => authAPI.googleLogin()}
          className="w-full flex items-center justify-center gap-2.5 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl text-sm font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 transition-all"
        >
          <GoogleIcon />
          Continue with Google
        </button>
      </form>

      <p className="text-center text-sm text-gray-500 mt-6">
        Don't have an account?{' '}
        <Link to="/register" className="text-brand-600 hover:text-brand-700 font-semibold">Create one free</Link>
      </p>
    </motion.div>
  );
}

// ─── REGISTER PAGE ────────────────────────────────────────────
const registerSchema = z.object({
  first_name: z.string().min(1, 'First name is required').max(80),
  last_name:  z.string().min(1, 'Last name is required').max(80),
  email:      z.string().email('Enter a valid email'),
  password:   z.string().min(8, 'Password must be at least 8 characters'),
  password_confirmation: z.string(),
  role:       z.enum(['student', 'teacher', 'school_admin'], { required_error: 'Select a role' }),
  school_name:z.string().optional(),
  grade:      z.string().optional(),
}).refine((d) => d.password === d.password_confirmation, {
  message: 'Passwords do not match',
  path: ['password_confirmation'],
});

export function Register() {
  const navigate  = useNavigate();
  const [searchParams] = useSearchParams();
  const { setAuth, connectSocket } = useAuthStore();
  const [showPwd, setShowPwd] = useState(false);
  const [googleLoading, setGoogleLoading] = useState(false);
  const [googleUser, setGoogleUser] = useState(null);
  const [showRoleModal, setShowRoleModal] = useState(false);

  // ── Handle Google OAuth redirect (backend sends ?token=XXX) ──
  useEffect(() => {
    const token = searchParams.get('token');
    const error = searchParams.get('error');

    if (error) {
      toast.error('Google sign-in failed. Please try again.');
      return;
    }

    if (token) {
      setGoogleLoading(true);

      // Manually call /auth/me with the token from URL
      fetch(`${import.meta.env.VITE_API_URL || 'http://localhost:8000/api'}/auth/me`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Accept': 'application/json',
        },
      })
        .then((r) => r.json())
        .then(({ user }) => {
          if (!user) throw new Error('No user');
          setAuth(user, token);
          connectSocket();
          toast.success(`Welcome, ${user.first_name}! 🎉`);
          navigate('/dashboard', { replace: true });
        })
        .catch(() => {
          toast.error('Google sign-in failed. Please try again.');
          setGoogleLoading(false);
        });
    }
  }, []);   // eslint-disable-line

  const { register, handleSubmit, watch, formState: { errors, isSubmitting } } = useForm({
    resolver: zodResolver(registerSchema),
    defaultValues: { role: 'student' },
  });

  const role = watch('role');

  const handleGoogleRegister = (selectedRole) => {
    const apiUrl = import.meta.env.VITE_API_URL || 'http://localhost:8000/api';
    window.location.href = `${apiUrl}/auth/google?role=${selectedRole}`;
  };

  // Show a spinner while we're processing the Google callback token
  if (googleLoading) {
    return (
      <div className="flex flex-col items-center justify-center gap-4 py-20">
        <Loader2 size={40} className="animate-spin text-brand-600" />
        <p className="text-gray-500 text-sm">Signing you in with Google…</p>
      </div>
    );
  }

  const onSubmit = async (values) => {
    try {
      const fd = new FormData();
      Object.entries(values).forEach(([k, v]) => { if (v !== undefined && v !== '') fd.append(k, v); });
      const { data } = await authAPI.register(fd);
      setAuth(data.user, data.token);
      connectSocket();
      toast.success('Account created! Welcome to EduLink 🎉');
      navigate('/dashboard');
    } catch (err) {
      const errs = err.response?.data?.errors;
      if (errs) Object.values(errs).flat().forEach((e) => toast.error(e));
      else toast.error(err.response?.data?.message || 'Registration failed');
    }
  };

  const Field = ({ name, label, type = 'text', placeholder, icon: Icon }) => (
    <div>
      <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">{label}</label>
      <div className="relative">
        {Icon && <Icon size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />}
        <input
          {...register(name)}
          type={type}
          placeholder={placeholder}
          className={clsx(
            'w-full py-2.5 rounded-xl border text-sm outline-none transition-all bg-white dark:bg-gray-700 dark:text-white',
            Icon ? 'pl-10 pr-4' : 'px-4',
            errors[name]
              ? 'border-red-300 focus:border-red-400 focus:ring-2 focus:ring-red-100'
              : 'border-gray-200 dark:border-gray-600 focus:border-brand-400 focus:ring-2 focus:ring-brand-100'
          )}
        />
      </div>
      {errors[name] && <p className="text-xs text-red-500 mt-1">{errors[name].message}</p>}
    </div>
  );

  return (
    <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} className="w-full max-w-md mx-auto">
      <div className="text-center mb-8">
        <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white">Create your account</h1>
        <p className="text-gray-400 text-sm mt-1">Join thousands of students and teachers on EduLink</p>
      </div>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        {/* Role selector */}
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">I am a…</label>
          <div className="grid grid-cols-3 gap-2">
            {[
              { value: 'student',      label: 'Student',  emoji: '🎒' },
              { value: 'teacher',      label: 'Teacher',  emoji: '🏫' },
              { value: 'school_admin', label: 'Admin',    emoji: '🏛️' },
            ].map((r) => (
              <label
                key={r.value}
                className={clsx(
                  'flex flex-col items-center gap-1.5 p-3 rounded-xl border-2 cursor-pointer transition-all',
                  role === r.value
                    ? 'border-brand-500 bg-brand-50 dark:bg-brand-900/20'
                    : 'border-gray-200 dark:border-gray-600 hover:border-gray-300'
                )}
              >
                <input {...register('role')} type="radio" value={r.value} className="sr-only" />
                <span className="text-xl">{r.emoji}</span>
                <span className={clsx('text-xs font-semibold', role === r.value ? 'text-brand-700 dark:text-brand-300' : 'text-gray-600 dark:text-gray-300')}>
                  {r.label}
                </span>
              </label>
            ))}
          </div>
          {errors.role && <p className="text-xs text-red-500 mt-1">{errors.role.message}</p>}
        </div>

        {/* Name */}
        <div className="grid grid-cols-2 gap-3">
          <Field name="first_name" label="First name" placeholder="Abebe" />
          <Field name="last_name"  label="Last name"  placeholder="Bekele" />
        </div>

        {/* Email */}
        <Field name="email" label="Email address" type="email" placeholder="you@school.com" icon={Mail} />

        {/* School name (admin) */}
        {role === 'school_admin' && (
          <Field name="school_name" label="School name" placeholder="My School Academy" />
        )}

        {/* Grade (student) */}
        {role === 'student' && (
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">Grade / Year (optional)</label>
            <select
              {...register('grade')}
              className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 text-sm outline-none focus:border-brand-400 focus:ring-2 focus:ring-brand-100 bg-white dark:bg-gray-700 dark:text-white"
            >
              <option value="">Select grade</option>
              {['Grade 7','Grade 8','Grade 9','Grade 10','Grade 11','Grade 12','Year 1','Year 2','Year 3','Year 4'].map((g) => (
                <option key={g} value={g}>{g}</option>
              ))}
            </select>
          </div>
        )}

        {/* Password */}
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">Password</label>
          <div className="relative">
            <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              {...register('password')}
              type={showPwd ? 'text' : 'password'}
              placeholder="At least 8 characters"
              className={clsx(
                'w-full pl-10 pr-10 py-2.5 rounded-xl border text-sm outline-none transition-all bg-white dark:bg-gray-700 dark:text-white',
                errors.password ? 'border-red-300' : 'border-gray-200 dark:border-gray-600 focus:border-brand-400 focus:ring-2 focus:ring-brand-100'
              )}
            />
            <button type="button" onClick={() => setShowPwd(!showPwd)} className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400">
              {showPwd ? <EyeOff size={16} /> : <Eye size={16} />}
            </button>
          </div>
          {errors.password && <p className="text-xs text-red-500 mt-1">{errors.password.message}</p>}
        </div>

        {/* Confirm password */}
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">Confirm password</label>
          <div className="relative">
            <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              {...register('password_confirmation')}
              type="password"
              placeholder="Re-enter password"
              className={clsx(
                'w-full pl-10 pr-4 py-2.5 rounded-xl border text-sm outline-none transition-all bg-white dark:bg-gray-700 dark:text-white',
                errors.password_confirmation ? 'border-red-300' : 'border-gray-200 dark:border-gray-600 focus:border-brand-400 focus:ring-2 focus:ring-brand-100'
              )}
            />
          </div>
          {errors.password_confirmation && <p className="text-xs text-red-500 mt-1">{errors.password_confirmation.message}</p>}
        </div>

        <button
          type="submit"
          disabled={isSubmitting}
          className="w-full flex items-center justify-center gap-2 py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-xl text-sm transition-all shadow-md"
        >
          {isSubmitting ? <Loader2 size={16} className="animate-spin" /> : 'Create account'}
        </button>

        <div className="relative flex items-center gap-3">
          <div className="flex-1 h-px bg-gray-200 dark:bg-gray-600" />
          <span className="text-xs text-gray-400">or</span>
          <div className="flex-1 h-px bg-gray-200 dark:bg-gray-600" />
        </div>

        <button
          type="button"
          onClick={() => setShowRoleModal(true)}
          className="w-full flex items-center justify-center gap-2.5 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl text-sm font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 transition-all"
        >
          <GoogleIcon />
          Sign up with Google
        </button>

        {/* Role Selection Modal for Google */}
        {showRoleModal && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              className="bg-white dark:bg-gray-800 rounded-2xl p-6 max-w-sm w-full"
            >
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">Select your role</h3>
              <p className="text-sm text-gray-500 dark:text-gray-400 mb-4">Choose how you'll use EduLink</p>
              <div className="space-y-2">
                {[
                  { value: 'student', label: 'Student', emoji: '🎒', desc: 'Join classes, learn, submit assignments' },
                  { value: 'teacher', label: 'Teacher', emoji: '🏫', desc: 'Create classes, teach, grade students' },
                  { value: 'school_admin', label: 'Admin', emoji: '🏛️', desc: 'Manage school, users, and settings' },
                ].map((r) => (
                  <button
                    key={r.value}
                    onClick={() => handleGoogleRegister(r.value)}
                    className="w-full flex items-center gap-3 p-3 rounded-xl border border-gray-200 dark:border-gray-600 hover:border-brand-400 hover:bg-brand-50 dark:hover:bg-brand-900/20 transition-all text-left"
                  >
                    <span className="text-2xl">{r.emoji}</span>
                    <div>
                      <p className="font-medium text-gray-900 dark:text-white">{r.label}</p>
                      <p className="text-xs text-gray-500 dark:text-gray-400">{r.desc}</p>
                    </div>
                  </button>
                ))}
              </div>
              <button
                onClick={() => setShowRoleModal(false)}
                className="w-full mt-4 py-2 text-sm text-gray-600 dark:text-gray-300 hover:text-gray-900 dark:hover:text-white transition-colors"
              >
                Cancel
              </button>
            </motion.div>
          </div>
        )}
      </form>

      <p className="text-center text-sm text-gray-500 mt-6">
        Already have an account?{' '}
        <Link to="/login" className="text-brand-600 hover:text-brand-700 font-semibold">Sign in</Link>
      </p>

      <p className="text-center text-xs text-gray-400 mt-3">
        By registering you agree to our{' '}
        <a href="#" className="underline hover:text-gray-600">Terms</a> and{' '}
        <a href="#" className="underline hover:text-gray-600">Privacy Policy</a>
      </p>
    </motion.div>
  );
}

export default Login;
