import React, { useEffect, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import {
  ArrowLeft, Eye, EyeOff, Loader2, Lock, Mail, RefreshCw, ShieldCheck,
} from 'lucide-react';
import { authAPI } from '@/utils/api';
import { useAuthStore } from '@/store';
import toast from 'react-hot-toast';
import clsx from 'clsx';
import { GoogleIcon, OtpInput } from './OtpInput';

export function Login() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { setAuth, connectSocket } = useAuthStore();

  // password | otp-email | otp-code
  const [mode, setMode] = useState('password');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [otp, setOtp] = useState('');
  const [showPwd, setShowPwd] = useState(false);
  const [emailError, setEmailError] = useState('');
  const [passwordError, setPasswordError] = useState('');
  const [loading, setLoading] = useState(false);
  const [googleLoading, setGoogleLoading] = useState(false);
  const [countdown, setCountdown] = useState(0);
  const [needsVerify, setNeedsVerify] = useState(false);

  useEffect(() => {
    if (countdown <= 0) return;
    const t = setTimeout(() => setCountdown((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [countdown]);

  const finishAuth = (user, token, greeting) => {
    setAuth(user, token);
    connectSocket();
    // Only show toast if not already shown (avoid duplicates from React Strict Mode)
    if (!window._authToastShown) {
      toast.success(greeting || `Welcome back, ${user.first_name}!`);
      window._authToastShown = true;
      setTimeout(() => { window._authToastShown = false; }, 1000);
    }
    navigate('/dashboard', { replace: true });
  };

  // Google OAuth redirect handler
  useEffect(() => {
    const token = searchParams.get('token');
    const error = searchParams.get('error');
    const info = searchParams.get('info');

    if (info === 'existing_account') {
      // token still processed below, finishAuth will show welcome message
    }

    if (error) {
      if (error === 'db_error') toast.error('Server is currently offline. Please try again later.');
      else if (error === 'account_disabled') toast.error('Your account is disabled. Please contact support.');
      else if (error === 'needs_verification') toast.error('Please verify your email before signing in.');
      else toast.error('Google sign-in failed. Please try again.');
      window.history.replaceState({}, document.title, window.location.pathname);
      return;
    }

    if (!token) return;

    setGoogleLoading(true);
    fetch(`${import.meta.env.VITE_API_URL || 'https://edulink-backend-jxd2.onrender.com/api'}/auth/me`, {
      headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' },
    })
      .then((r) => r.json())
      .then(({ user }) => {
        if (!user) throw new Error('No user');
        finishAuth(user, token);
      })
      .catch(() => {
        toast.error('Google sign-in failed. Please try again.');
        setGoogleLoading(false);
      });
  }, []); // eslint-disable-line


  const handleGoogle = () => {
    // Login: existing accounts keep their role; new Google accounts default to student
    authAPI.googleLogin('student');
  };

  if (googleLoading) {
    return (
      <div className="flex flex-col items-center justify-center gap-4 py-20">
        <Loader2 size={40} className="animate-spin text-brand-600" />
        <p className="text-gray-500 text-sm">Signing you in with Google…</p>
      </div>
    );
  }

  const validateEmail = () => {
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      setEmailError('Enter a valid email address');
      return false;
    }
    setEmailError('');
    return true;
  };

  // ── Password login ─────────────────────────────────────────
  const handlePasswordLogin = async (e) => {
    e.preventDefault();
    if (!validateEmail()) return;
    if (!password) {
      setPasswordError('Password is required');
      return;
    }
    setPasswordError('');
    setLoading(true);
    setNeedsVerify(false);
    try {
      const { data } = await authAPI.login({
        email: email.trim().toLowerCase(),
        password,
      });
      finishAuth(data.user, data.token);
    } catch (err) {
      const data = err.response?.data;
      if (data?.needs_verification) {
        setNeedsVerify(true);
        toast.error(data.message || 'Please verify your email first.');
      } else if (err.response?.status === 422) {
        setPasswordError(data?.errors?.email?.[0] || data?.message || 'Invalid email or password');
        toast.error('Invalid email or password');
      } else {
        toast.error(data?.message || 'Sign-in failed. Try again.');
      }
    } finally {
      setLoading(false);
    }
  };

  // ── OTP: send ──────────────────────────────────────────────
  const sendOtp = async (e) => {
    e?.preventDefault?.();
    if (!validateEmail()) return;
    setLoading(true);
    setNeedsVerify(false);
    try {
      const { data } = await authAPI.sendLoginOtp({ email: email.trim().toLowerCase() });
      toast.success('Code sent! Check your email');
      setMode('otp-code');
      setCountdown(60);
      if (data?.debug_otp) {
        toast.success(`Demo Mode: Code is ${data.debug_otp}`, { duration: 10000 });
        setOtp(data.debug_otp);
      } else {
        setOtp('');
      }
    } catch (err) {
      const data = err.response?.data;
      if (data?.needs_verification) {
        setNeedsVerify(true);
        toast.error(data.message);
      } else {
        toast.error(data?.message || 'Failed to send code. Try again.');
      }
    } finally {
      setLoading(false);
    }
  };

  const resendOtp = async () => {
    if (countdown > 0) return;
    setLoading(true);
    try {
      const { data } = await authAPI.sendLoginOtp({ email: email.trim().toLowerCase() });
      toast.success('New code sent!');
      setCountdown(60);
      if (data?.debug_otp) {
        toast.success(`Demo Mode: Code is ${data.debug_otp}`, { duration: 10000 });
        setOtp(data.debug_otp);
      } else {
        setOtp('');
      }
    } catch {
      toast.error('Failed to resend. Try again.');
    } finally {
      setLoading(false);
    }
  };

  // ── OTP: verify ────────────────────────────────────────────
  const verifyOtp = async (e) => {
    e.preventDefault();
    if (otp.length < 6) return toast.error('Enter the full 6-digit code');
    setLoading(true);
    try {
      const { data } = await authAPI.verifyLoginOtp({
        email: email.trim().toLowerCase(),
        otp,
      });
      finishAuth(data.user, data.token);
    } catch (err) {
      toast.error(err.response?.data?.message || 'Invalid or expired code');
      if (err.response?.data?.expired) {
        setMode('otp-email');
        setOtp('');
      }
    } finally {
      setLoading(false);
    }
  };

  // Resend verification + jump into verify flow on register
  const resendVerify = async () => {
    setLoading(true);
    try {
      await authAPI.resendEmailOtp({ email: email.trim().toLowerCase() });
      toast.success('Verification code sent!');
      navigate(`/register?verify=${encodeURIComponent(email.trim().toLowerCase())}`);
    } catch {
      toast.error('Could not resend verification email.');
    } finally {
      setLoading(false);
    }
  };



  return (
    <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} className="w-full max-w-sm mx-auto">
      <AnimatePresence mode="wait">

        {/* ── Password login ─────────────────────────────────── */}
        {mode === 'password' && (
          <motion.div
            key="password"
            initial={{ opacity: 0, x: -24 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 24 }}
            transition={{ duration: 0.2 }}
          >
            <div className="text-center mb-7">
              <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white">Welcome back</h1>
              <p className="text-gray-400 text-sm mt-1">Sign in to continue to EduLink</p>
            </div>

            <button
              type="button"
              onClick={handleGoogle}
              className="w-full flex items-center justify-center gap-2.5 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl text-sm font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 transition-all mb-4"
            >
              <GoogleIcon />
              Continue with Google
            </button>

            <div className="relative flex items-center gap-3 mb-4">
              <div className="flex-1 h-px bg-gray-200 dark:bg-gray-600" />
              <span className="text-xs text-gray-400">or</span>
              <div className="flex-1 h-px bg-gray-200 dark:bg-gray-600" />
            </div>

            <form onSubmit={handlePasswordLogin} className="space-y-3.5">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">Email</label>
                <div className="relative">
                  <Mail size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
                  <input
                    id="login-email"
                    type="email"
                    value={email}
                    onChange={(e) => { setEmail(e.target.value); setEmailError(''); setNeedsVerify(false); }}
                    placeholder="you@school.com"
                    autoFocus
                    autoComplete="email"
                    className={clsx(fieldCls, emailError && errCls)}
                  />
                </div>
                {emailError && <p className="text-xs text-red-500 mt-1">{emailError}</p>}
              </div>

              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">Password</label>
                  <Link to="/forgot-password" className="text-xs font-medium text-brand-600 hover:text-brand-700">
                    Forgot password?
                  </Link>
                </div>
                <div className="relative">
                  <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
                  <input
                    type={showPwd ? 'text' : 'password'}
                    value={password}
                    onChange={(e) => { setPassword(e.target.value); setPasswordError(''); }}
                    placeholder="Your password"
                    autoComplete="current-password"
                    className={clsx(fieldCls, 'pr-10', passwordError && errCls)}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPwd((s) => !s)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                  >
                    {showPwd ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
                {passwordError && <p className="text-xs text-red-500 mt-1">{passwordError}</p>}
              </div>

              {needsVerify && (
                <div className="rounded-xl bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 px-3.5 py-3 text-sm text-amber-800 dark:text-amber-200">
                  Your email is not verified yet.{' '}
                  <button type="button" onClick={resendVerify} className="font-semibold underline">
                    Resend code
                  </button>
                </div>
              )}

              <button
                type="submit"
                disabled={loading}
                className="w-full flex items-center justify-center gap-2 py-3 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-2xl text-sm transition-all shadow-lg shadow-brand-600/25 hover:shadow-brand-600/40"
              >
                {loading ? <Loader2 size={16} className="animate-spin" /> : 'Sign in'}
              </button>
            </form>

            <button
              type="button"
              onClick={() => setMode('otp-email')}
              className="w-full mt-3 py-3 text-sm font-semibold text-brand-600 hover:text-brand-700 hover:bg-brand-50 dark:hover:bg-brand-900/20 rounded-2xl transition-all"
            >
              Sign in with email code instead
            </button>

            <p className="text-center text-sm text-gray-500 mt-5">
              Don&apos;t have an account?{' '}
              <Link to="/register" className="text-brand-600 hover:text-brand-700 font-semibold">Create one free</Link>
            </p>
          </motion.div>
        )}

        {/* ── OTP: enter email ───────────────────────────────── */}
        {mode === 'otp-email' && (
          <motion.div
            key="otp-email"
            initial={{ opacity: 0, x: 24 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -24 }}
            transition={{ duration: 0.2 }}
          >
            <button
              type="button"
              onClick={() => setMode('password')}
              className="flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-700 mb-5"
            >
              <ArrowLeft size={14} />
              Back to password
            </button>

            <div className="text-center mb-7">
              <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-brand-100 dark:bg-brand-900/30 mb-4">
                <Mail size={24} className="text-brand-600 dark:text-brand-400" />
              </div>
              <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white">Email sign-in code</h1>
              <p className="text-gray-400 text-sm mt-1">We&apos;ll send a 6-digit code — no password needed</p>
            </div>

            <form onSubmit={sendOtp} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">Email address</label>
                <div className="relative">
                  <Mail size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => { setEmail(e.target.value); setEmailError(''); }}
                    placeholder="you@school.com"
                    autoFocus
                    className={clsx(fieldCls, emailError && errCls)}
                  />
                </div>
                {emailError && <p className="text-xs text-red-500 mt-1">{emailError}</p>}
              </div>

              <button
                type="submit"
                disabled={loading}
                className="w-full flex items-center justify-center gap-2 py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-xl text-sm transition-all shadow-md"
              >
                {loading ? <Loader2 size={16} className="animate-spin" /> : 'Send sign-in code'}
              </button>
            </form>
          </motion.div>
        )}

        {/* ── OTP: enter code ────────────────────────────────── */}
        {mode === 'otp-code' && (
          <motion.div
            key="otp-code"
            initial={{ opacity: 0, x: 24 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -24 }}
            transition={{ duration: 0.2 }}
          >
            <div className="text-center mb-8">
              <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-green-100 dark:bg-green-900/30 mb-4">
                <ShieldCheck size={24} className="text-green-600 dark:text-green-400" />
              </div>
              <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white">Check your email</h1>
              <p className="text-gray-400 text-sm mt-1">
                We sent a 6-digit code to<br />
                <span className="font-medium text-gray-700 dark:text-gray-200">{email}</span>
              </p>
            </div>

            <form onSubmit={verifyOtp} className="space-y-6">
              <OtpInput value={otp} onChange={setOtp} disabled={loading} />
              <button
                type="submit"
                disabled={loading || otp.length < 6}
                className="w-full flex items-center justify-center gap-2 py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-xl text-sm transition-all shadow-md"
              >
                {loading ? <Loader2 size={16} className="animate-spin" /> : 'Verify & sign in'}
              </button>
            </form>

            <div className="mt-6 flex flex-col items-center gap-3">
              <button
                type="button"
                onClick={resendOtp}
                disabled={countdown > 0 || loading}
                className="flex items-center gap-1.5 text-sm text-brand-600 hover:text-brand-700 disabled:text-gray-400 disabled:cursor-not-allowed font-medium"
              >
                <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
                {countdown > 0 ? `Resend code in ${countdown}s` : 'Resend code'}
              </button>
              <button
                type="button"
                onClick={() => { setMode('otp-email'); setOtp(''); }}
                className="flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-700 dark:hover:text-gray-300"
              >
                <ArrowLeft size={14} />
                Use a different email
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}

const fieldCls =
  'w-full pl-10 pr-4 py-2.5 rounded-xl border text-sm outline-none transition-all bg-white dark:bg-gray-700 dark:text-white border-gray-200 dark:border-gray-600 focus:border-brand-400 focus:ring-2 focus:ring-brand-100 dark:focus:ring-brand-900/30';
const errCls = 'border-red-300 focus:border-red-400 focus:ring-2 focus:ring-red-100';

export default Login;
