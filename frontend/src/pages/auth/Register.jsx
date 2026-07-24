import React, { useEffect, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import {
  ArrowLeft, Eye, EyeOff, Loader2, Mail, RefreshCw, ShieldCheck, User,
} from 'lucide-react';
import { authAPI } from '@/utils/api';
import { useAuthStore } from '@/store';
import toast from 'react-hot-toast';
import clsx from 'clsx';
import {
  GoogleIcon, OtpInput, ROLES, passwordStrength, STRENGTH_LABELS, STRENGTH_COLORS,
} from './OtpInput';

const VALID_ROLES = ['student', 'teacher'];

export default function Register() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { setAuth, connectSocket } = useAuthStore();

  const roleFromUrl = searchParams.get('role');
  const verifyEmail = searchParams.get('verify');
  const initialRole = VALID_ROLES.includes(roleFromUrl) ? roleFromUrl : null;

  const [step, setStep] = useState(
    verifyEmail ? 'otp' : initialRole ? 'form' : 'role'
  );
  const [role, setRole] = useState(initialRole);
  const [form, setForm] = useState({
    first_name: '',
    last_name: '',
    email: verifyEmail || '',
    password: '',
    password_confirmation: '',
    grade: '',
  });
  const [errors, setErrors] = useState({});
  const [showPwd, setShowPwd] = useState(false);
  const [loading, setLoading] = useState(false);
  const [otp, setOtp] = useState('');
  const [countdown, setCountdown] = useState(verifyEmail ? 60 : 0);
  const [googleLoading, setGoogleLoading] = useState(false);

  useEffect(() => {
    if (countdown <= 0) return;
    const t = setTimeout(() => setCountdown((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [countdown]);

  // Google OAuth redirect handler
  useEffect(() => {
    const token = searchParams.get('token');
    const error = searchParams.get('error');
    if (error) {
      if (error === 'db_error') toast.error('Server is currently offline. Please try again later.');
      else if (error === 'account_disabled') toast.error('Your account is disabled. Please contact support.');
      else toast.error('Google sign-in failed. Please try again.');
      window.history.replaceState({}, document.title, window.location.pathname + (role ? `?role=${role}` : ''));
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
        setAuth(user, token);
        connectSocket();
        toast.success(`Welcome, ${user.first_name}!`);
        navigate('/dashboard', { replace: true });
      })
      .catch(() => {
        toast.error('Google sign-in failed. Please try again.');
        setGoogleLoading(false);
      });
  }, []); // eslint-disable-line

  const handleGoogle = () => {
    if (!role) {
      toast.error('Choose Student or Teacher first');
      setStep('role');
      return;
    }
    authAPI.googleLogin(role);
  };

  if (googleLoading) {
    return (
      <div className="flex flex-col items-center justify-center gap-4 py-16">
        <Loader2 size={40} className="animate-spin text-brand-600" />
        <p className="text-gray-500 text-sm">Creating your account with Google…</p>
      </div>
    );
  }

  const setField = (key, value) => {
    setForm((f) => ({ ...f, [key]: value }));
    if (errors[key]) setErrors((e) => ({ ...e, [key]: '' }));
  };

  const selectRole = (id) => {
    setRole(id);
    setStep('form');
    const url = new URL(window.location.href);
    url.searchParams.set('role', id);
    url.searchParams.delete('verify');
    window.history.replaceState({}, '', url.pathname + '?' + url.searchParams.toString());
  };

  const validateForm = () => {
    const next = {};
    if (!form.first_name.trim()) next.first_name = 'First name is required';
    if (!form.last_name.trim()) next.last_name = 'Last name is required';
    if (!form.email.trim() || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) {
      next.email = 'Enter a valid email address';
    }
    if (form.password.length < 8) next.password = 'Password must be at least 8 characters';
    if (form.password !== form.password_confirmation) {
      next.password_confirmation = 'Passwords do not match';
    }
    setErrors(next);
    return Object.keys(next).length === 0;
  };

  const handleRegister = async (e) => {
    e.preventDefault();
    if (!role) {
      toast.error('Please choose Student or Teacher first');
      setStep('role');
      return;
    }
    if (!validateForm()) return;

    setLoading(true);
    try {
      const fd = new FormData();
      fd.append('first_name', form.first_name.trim());
      fd.append('last_name', form.last_name.trim());
      fd.append('email', form.email.trim().toLowerCase());
      fd.append('password', form.password);
      fd.append('password_confirmation', form.password_confirmation);
      fd.append('role', role);
      if (role === 'student' && form.grade) fd.append('grade', form.grade);

      const { data } = await authAPI.register(fd);
      toast.success('Account created! Check your email for the code.');
      setStep('otp');
      setCountdown(60);
      if (data?.debug_otp) {
        toast.success(`Demo Mode: Code is ${data.debug_otp}`, { duration: 10000 });
        setOtp(data.debug_otp);
      } else {
        setOtp('');
      }
    } catch (err) {
      const apiErrors = err.response?.data?.errors;
      if (apiErrors) {
        const mapped = {};
        Object.entries(apiErrors).forEach(([k, v]) => { mapped[k] = Array.isArray(v) ? v[0] : v; });
        setErrors(mapped);
      }
      toast.error(err.response?.data?.message || 'Registration failed. Try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleVerify = async (e) => {
    e.preventDefault();
    if (otp.length < 6) return toast.error('Enter the full 6-digit code');
    setLoading(true);
    try {
      const { data } = await authAPI.verifyEmailOtp({
        email: (form.email || verifyEmail || '').trim().toLowerCase(),
        otp,
      });
      setAuth(data.user, data.token);
      connectSocket();
      toast.success(`Welcome to EduLink, ${data.user.first_name}!`);
      navigate('/dashboard', { replace: true });
    } catch (err) {
      toast.error(err.response?.data?.message || 'Invalid or expired code');
      if (err.response?.data?.expired) setOtp('');
    } finally {
      setLoading(false);
    }
  };

  const resendOtp = async () => {
    if (countdown > 0) return;
    setLoading(true);
    try {
      const { data } = await authAPI.resendEmailOtp({ email: (form.email || verifyEmail || '').trim().toLowerCase() });
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


  const strength = passwordStrength(form.password);
  const roleMeta = ROLES.find((r) => r.id === role);


  return (
    <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="w-full">
      <AnimatePresence mode="wait">

        {step === 'role' && (
          <motion.div
            key="role"
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 20 }}
            transition={{ duration: 0.22 }}
          >
            <div className="text-center mb-8">
              <p className="text-xs font-semibold uppercase tracking-[0.2em] text-brand-500 mb-2">Get started</p>
              <h1 className="font-display font-bold text-2xl sm:text-3xl text-gray-900 dark:text-white">
                Who are you?
              </h1>
              <p className="text-gray-400 text-sm mt-2 max-w-xs mx-auto">
                Students and teachers talk freely. Pick your role — it shapes your EduLink home.
              </p>
            </div>

            <div className="grid gap-3">
              {ROLES.map((r, i) => (
                <motion.button
                  key={r.id}
                  type="button"
                  initial={{ opacity: 0, y: 12 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.08 * i }}
                  onClick={() => selectRole(r.id)}
                  className={clsx(
                    'group relative w-full overflow-hidden rounded-2xl border-2 p-5 text-left transition-all duration-300',
                    'hover:scale-[1.02] hover:shadow-xl hover:shadow-brand-500/10',
                    r.bg
                  )}
                >
                  <div className={clsx('absolute inset-y-0 left-0 w-1.5', r.accent)} />
                  <div className="flex items-center gap-4 pl-2">
                    <div className={clsx(
                      'w-14 h-14 rounded-2xl flex items-center justify-center text-white text-2xl font-black shadow-lg',
                      r.accent
                    )}>
                      {r.id === 'student' ? 'S' : 'T'}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-display font-bold text-lg text-gray-900 dark:text-white">{r.label}</p>
                      <p className="text-sm text-gray-500 dark:text-gray-400 mt-0.5 leading-snug">{r.desc}</p>
                    </div>
                    <span className="text-gray-400 group-hover:text-brand-600 group-hover:translate-x-1 transition-all text-xl">→</span>
                  </div>
                </motion.button>
              ))}
            </div>

            <p className="text-center text-sm text-gray-500 mt-7">
              Already on EduLink?{' '}
              <Link to="/login" className="text-brand-600 hover:text-brand-700 font-semibold">Sign in</Link>
            </p>
          </motion.div>
        )}

        {step === 'form' && (
          <motion.div
            key="form"
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            transition={{ duration: 0.2 }}
          >
            <button
              type="button"
              onClick={() => setStep('role')}
              className="flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-700 dark:hover:text-gray-300 mb-5 transition-colors"
            >
              <ArrowLeft size={14} />
              Change role
            </button>

            <div className="text-center mb-6">
              <div className={clsx(
                'inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full text-xs font-bold text-white mb-3 bg-gradient-to-r shadow-md',
                roleMeta?.accent
              )}>
                {roleMeta?.label}
              </div>
              <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white">
                Create your account
              </h1>
              <p className="text-gray-400 text-sm mt-1">Free forever · verify with email</p>
            </div>

            <button
              type="button"
              onClick={handleGoogle}
              className="w-full flex items-center justify-center gap-2.5 py-3 border border-gray-200 dark:border-gray-600 rounded-2xl text-sm font-semibold text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-700/80 transition-all mb-4 shadow-sm"
            >
              <GoogleIcon />
              Continue with Google
            </button>

            <div className="relative flex items-center gap-3 mb-4">
              <div className="flex-1 h-px bg-gray-200 dark:bg-gray-600" />
              <span className="text-xs text-gray-400">or email</span>
              <div className="flex-1 h-px bg-gray-200 dark:bg-gray-600" />
            </div>

            <form onSubmit={handleRegister} className="space-y-3.5">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">First name</label>
                  <div className="relative">
                    <User size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                    <input
                      type="text"
                      value={form.first_name}
                      onChange={(e) => setField('first_name', e.target.value)}
                      autoFocus
                      className={clsx(inputCls, errors.first_name && errCls)}
                      placeholder="Abebe"
                    />
                  </div>
                  {errors.first_name && <p className="text-xs text-red-500 mt-1">{errors.first_name}</p>}
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Last name</label>
                  <input
                    type="text"
                    value={form.last_name}
                    onChange={(e) => setField('last_name', e.target.value)}
                    className={clsx(inputCls, 'px-3.5', errors.last_name && errCls)}
                    placeholder="Kebede"
                  />
                  {errors.last_name && <p className="text-xs text-red-500 mt-1">{errors.last_name}</p>}
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Email</label>
                <div className="relative">
                  <Mail size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                  <input
                    type="email"
                    value={form.email}
                    onChange={(e) => setField('email', e.target.value)}
                    className={clsx(inputCls, errors.email && errCls)}
                    placeholder="you@school.com"
                    autoComplete="email"
                  />
                </div>
                {errors.email && <p className="text-xs text-red-500 mt-1">{errors.email}</p>}
              </div>

              {role === 'student' && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Grade <span className="text-gray-400 font-normal">(optional)</span>
                  </label>
                  <input
                    type="text"
                    value={form.grade}
                    onChange={(e) => setField('grade', e.target.value)}
                    className={clsx(inputCls, 'px-3.5')}
                    placeholder="e.g. Grade 10"
                  />
                </div>
              )}

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Password</label>
                <div className="relative">
                  <input
                    type={showPwd ? 'text' : 'password'}
                    value={form.password}
                    onChange={(e) => setField('password', e.target.value)}
                    className={clsx(inputCls, 'pl-3.5 pr-10', errors.password && errCls)}
                    placeholder="Min. 8 characters"
                    autoComplete="new-password"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPwd((s) => !s)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                  >
                    {showPwd ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
                {form.password && (
                  <div className="mt-2 flex items-center gap-2">
                    <div className="flex-1 flex gap-1">
                      {[1, 2, 3, 4].map((n) => (
                        <div
                          key={n}
                          className={clsx('h-1.5 flex-1 rounded-full transition-colors', n <= strength ? STRENGTH_COLORS[strength] : 'bg-gray-200 dark:bg-gray-600')}
                        />
                      ))}
                    </div>
                    <span className="text-xs text-gray-500 font-medium">{STRENGTH_LABELS[strength]}</span>
                  </div>
                )}
                {errors.password && <p className="text-xs text-red-500 mt-1">{errors.password}</p>}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Confirm password</label>
                <input
                  type="password"
                  value={form.password_confirmation}
                  onChange={(e) => setField('password_confirmation', e.target.value)}
                  className={clsx(inputCls, 'px-3.5', errors.password_confirmation && errCls)}
                  placeholder="Re-enter password"
                  autoComplete="new-password"
                />
                {errors.password_confirmation && (
                  <p className="text-xs text-red-500 mt-1">{errors.password_confirmation}</p>
                )}
              </div>

              <button
                type="submit"
                disabled={loading}
                className="w-full flex items-center justify-center gap-2 py-3 mt-1 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-2xl text-sm transition-all shadow-lg shadow-brand-600/25 hover:shadow-brand-600/40"
              >
                {loading ? <Loader2 size={16} className="animate-spin" /> : 'Create account'}
              </button>
            </form>

            <p className="text-center text-sm text-gray-500 mt-5">
              Already have an account?{' '}
              <Link to="/login" className="text-brand-600 hover:text-brand-700 font-semibold">Sign in</Link>
            </p>
          </motion.div>
        )}

        {step === 'otp' && (
          <motion.div
            key="otp"
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            transition={{ duration: 0.2 }}
          >
            <div className="text-center mb-8">
              <div className="inline-flex items-center justify-center w-16 h-16 rounded-3xl bg-gradient-to-br from-emerald-400 to-green-600 mb-4 shadow-lg shadow-green-500/30">
                <ShieldCheck size={28} className="text-white" />
              </div>
              <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white">Verify your email</h1>
              <p className="text-gray-400 text-sm mt-1.5">
                Code sent to<br />
                <span className="font-semibold text-gray-700 dark:text-gray-200">
                  {form.email || verifyEmail}
                </span>
              </p>
            </div>

            <form onSubmit={handleVerify} className="space-y-6">
              <OtpInput value={otp} onChange={setOtp} disabled={loading} />
              <button
                type="submit"
                disabled={loading || otp.length < 6}
                className="w-full flex items-center justify-center gap-2 py-3 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-2xl text-sm transition-all shadow-lg shadow-brand-600/25"
              >
                {loading ? <Loader2 size={16} className="animate-spin" /> : 'Verify & continue'}
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
                {countdown > 0 ? `Resend in ${countdown}s` : 'Resend code'}
              </button>
              <button
                type="button"
                onClick={() => {
                  if (verifyEmail) {
                    navigate('/login');
                    return;
                  }
                  setStep('form');
                  setOtp('');
                }}
                className="flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-700 dark:hover:text-gray-300"
              >
                <ArrowLeft size={14} />
                {verifyEmail ? 'Back to sign in' : 'Edit details'}
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}

const inputCls =
  'w-full pl-9 pr-3.5 py-3 rounded-2xl border text-sm outline-none transition-all bg-white dark:bg-gray-700 dark:text-white border-gray-200 dark:border-gray-600 focus:border-brand-400 focus:ring-4 focus:ring-brand-100 dark:focus:ring-brand-900/30';
const errCls = 'border-red-300 focus:border-red-400 focus:ring-red-100';
