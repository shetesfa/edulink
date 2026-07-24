import React, { useState, useRef, useEffect } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { Mail, Lock, ArrowLeft, CheckCircle2, Loader2, Eye, EyeOff, RefreshCw } from 'lucide-react';
import { authAPI } from '@/utils/api';
import toast from 'react-hot-toast';
import clsx from 'clsx';

/* ─── Step machine ───────────────────────────────────────────
   step 1: enter email
   step 2: enter 6-digit OTP
   step 3: set new password
   step 4: success
────────────────────────────────────────────────────────────── */
export default function ForgotPassword() {
  const navigate       = useNavigate();
  const [step, setStep]= useState(1);
  const [email, setEmail]       = useState('');
  const [otp, setOtp]           = useState(['','','','','','']);
  const [password, setPassword] = useState('');
  const [confirm, setConfirm]   = useState('');
  const [token, setToken]       = useState('');   // server returns real token with OTP
  const [loading, setLoading]   = useState(false);
  const [showPwd, setShowPwd]   = useState(false);
  const [resendCD, setResendCD] = useState(0);
  const otpRefs = useRef([]);

  // Resend countdown
  useEffect(() => {
    if (resendCD <= 0) return;
    const t = setTimeout(() => setResendCD((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [resendCD]);

  /* Step 1 — send email */
  const sendEmail = async (e) => {
    e.preventDefault();
    if (!email.trim()) return;
    setLoading(true);
    try {
      await authAPI.forgotPassword({ email: email.toLowerCase().trim() });
      setStep(2);
      setResendCD(60);
      toast.success('A 6-digit code has been sent to your email.');
    } catch (err) {
      // Always show success for security (don't reveal if email exists)
      setStep(2);
      setResendCD(60);
      toast.success('If this email exists, a code has been sent.');
    } finally { setLoading(false); }
  };

  /* OTP input handling */
  const handleOtpChange = (idx, val) => {
    const digit = val.replace(/\D/,'').slice(-1);
    const next  = [...otp];
    next[idx]   = digit;
    setOtp(next);
    if (digit && idx < 5) otpRefs.current[idx+1]?.focus();
  };

  const handleOtpKeyDown = (idx, e) => {
    if (e.key === 'Backspace' && !otp[idx] && idx > 0) {
      otpRefs.current[idx-1]?.focus();
    }
    if (e.key === 'ArrowLeft'  && idx > 0) otpRefs.current[idx-1]?.focus();
    if (e.key === 'ArrowRight' && idx < 5) otpRefs.current[idx+1]?.focus();
  };

  const handleOtpPaste = (e) => {
    const pasted = e.clipboardData.getData('text').replace(/\D/g,'').slice(0,6);
    if (pasted.length) {
      const next = [...otp];
      pasted.split('').forEach((d,i) => { if(i<6) next[i]=d; });
      setOtp(next);
      otpRefs.current[Math.min(pasted.length,5)]?.focus();
    }
    e.preventDefault();
  };

  /* Step 2 — verify OTP */
  const verifyOtp = async (e) => {
    e.preventDefault();
    const code = otp.join('');
    if (code.length < 6) return toast.error('Enter the 6-digit code from your email');
    setLoading(true);
    try {
      // Call a verify-otp endpoint that returns a short-lived reset token
      const { data } = await authAPI.verifyOtp({ email, otp: code });
      setToken(data.reset_token);
      setStep(3);
    } catch (err) {
      toast.error(err.response?.data?.message || 'Invalid or expired code. Please try again.');
      setOtp(['','','','','','']);
      otpRefs.current[0]?.focus();
    } finally { setLoading(false); }
  };

  /* Resend OTP */
  const resendOtp = async () => {
    if (resendCD > 0) return;
    setLoading(true);
    try {
      await authAPI.forgotPassword({ email });
      setResendCD(60);
      setOtp(['','','','','','']);
      otpRefs.current[0]?.focus();
      toast.success('New code sent!');
    } catch { toast.error('Failed to resend'); } finally { setLoading(false); }
  };

  /* Step 3 — set new password */
  const resetPassword = async (e) => {
    e.preventDefault();
    if (password.length < 8)         return toast.error('Password must be at least 8 characters');
    if (password !== confirm)         return toast.error('Passwords do not match');
    setLoading(true);
    try {
      await authAPI.resetPassword({ email, token, password, password_confirmation: confirm });
      setStep(4);
    } catch (err) {
      toast.error(err.response?.data?.message || 'Reset failed. Please start over.');
    } finally { setLoading(false); }
  };

  const stepVariants = {
    initial: { opacity:0, x:30 },
    animate: { opacity:1, x:0 },
    exit:    { opacity:0, x:-30 },
  };

  return (
    <AnimatePresence mode="wait">
      {/* ── Step 1: Email ───────────────────────────────────────── */}
      {step === 1 && (
        <motion.div key="s1" {...stepVariants} transition={{ duration:0.2 }}>
          <div className="text-center mb-6">
            <div className="w-14 h-14 bg-brand-100 dark:bg-brand-900/40 rounded-2xl flex items-center justify-center mx-auto mb-4">
              <Mail size={26} className="text-brand-600"/>
            </div>
            <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white">Forgot password?</h1>
            <p className="text-gray-400 text-sm mt-1">Enter your email and we'll send a 6-digit code</p>
          </div>
          <form onSubmit={sendEmail} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">Email address</label>
              <div className="relative">
                <Mail size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400"/>
                <input
                  type="email" value={email} onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@school.com" required autoFocus
                  className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-sm outline-none focus:border-brand-400 focus:ring-2 focus:ring-brand-100 dark:text-white transition-all"
                />
              </div>
            </div>
            <button type="submit" disabled={loading || !email.trim()}
              className="w-full flex items-center justify-center gap-2 py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-xl text-sm transition-all">
              {loading ? <Loader2 size={16} className="animate-spin"/> : null}
              {loading ? 'Sending…' : 'Send Code'}
            </button>
          </form>
          <p className="text-center text-sm text-gray-500 mt-6">
            <Link to="/login" className="flex items-center justify-center gap-1.5 text-brand-600 hover:text-brand-700 font-medium">
              <ArrowLeft size={14}/> Back to login
            </Link>
          </p>
        </motion.div>
      )}

      {/* ── Step 2: OTP ─────────────────────────────────────────── */}
      {step === 2 && (
        <motion.div key="s2" {...stepVariants} transition={{ duration:0.2 }}>
          <div className="text-center mb-6">
            <div className="w-14 h-14 bg-green-100 dark:bg-green-900/40 rounded-2xl flex items-center justify-center mx-auto mb-4">
              <Mail size={26} className="text-green-600"/>
            </div>
            <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white">Check your email</h1>
            <p className="text-gray-400 text-sm mt-1">
              We sent a 6-digit code to<br/>
              <strong className="text-gray-700 dark:text-gray-200">{email}</strong>
            </p>
          </div>
          <form onSubmit={verifyOtp} className="space-y-6">
            {/* OTP boxes */}
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-3 text-center">Enter 6-digit code</label>
              <div className="flex gap-2 justify-center" onPaste={handleOtpPaste}>
                {otp.map((digit, i) => (
                  <input
                    key={i}
                    ref={(el) => (otpRefs.current[i] = el)}
                    type="text" inputMode="numeric" maxLength={1}
                    value={digit}
                    onChange={(e) => handleOtpChange(i, e.target.value)}
                    onKeyDown={(e) => handleOtpKeyDown(i, e)}
                    autoFocus={i === 0}
                    className={clsx(
                      'w-11 h-14 text-center text-xl font-bold rounded-xl border-2 outline-none transition-all dark:bg-gray-700 dark:text-white',
                      digit
                        ? 'border-brand-500 bg-brand-50 dark:bg-brand-900/20 text-brand-700 dark:text-brand-300'
                        : 'border-gray-200 dark:border-gray-600 text-gray-900'
                    )}
                  />
                ))}
              </div>
            </div>
            <button type="submit" disabled={loading || otp.join('').length < 6}
              className="w-full flex items-center justify-center gap-2 py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-xl text-sm transition-all">
              {loading ? <Loader2 size={16} className="animate-spin"/> : null}
              {loading ? 'Verifying…' : 'Verify Code'}
            </button>
          </form>

          {/* Resend */}
          <div className="text-center mt-5 space-y-2">
            <p className="text-sm text-gray-500">Didn't receive the code?</p>
            <button onClick={resendOtp} disabled={resendCD > 0 || loading}
              className="flex items-center gap-1.5 mx-auto text-sm text-brand-600 hover:text-brand-700 font-medium disabled:text-gray-400 disabled:cursor-not-allowed transition-colors">
              <RefreshCw size={13}/> {resendCD > 0 ? `Resend in ${resendCD}s` : 'Resend code'}
            </button>
            <button onClick={() => { setStep(1); setOtp(['','','','','','']); }}
              className="flex items-center gap-1.5 mx-auto text-sm text-gray-400 hover:text-gray-600 transition-colors">
              <ArrowLeft size={13}/> Change email
            </button>
          </div>
        </motion.div>
      )}

      {/* ── Step 3: New password ────────────────────────────────── */}
      {step === 3 && (
        <motion.div key="s3" {...stepVariants} transition={{ duration:0.2 }}>
          <div className="text-center mb-6">
            <div className="w-14 h-14 bg-brand-100 dark:bg-brand-900/40 rounded-2xl flex items-center justify-center mx-auto mb-4">
              <Lock size={26} className="text-brand-600"/>
            </div>
            <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white">Set new password</h1>
            <p className="text-gray-400 text-sm mt-1">Choose a strong password for your account</p>
          </div>
          <form onSubmit={resetPassword} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">New password</label>
              <div className="relative">
                <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400"/>
                <input type={showPwd ? 'text' : 'password'} value={password} onChange={(e) => setPassword(e.target.value)}
                  placeholder="At least 8 characters" required autoFocus
                  className="w-full pl-10 pr-10 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-sm outline-none focus:border-brand-400 focus:ring-2 focus:ring-brand-100 dark:text-white transition-all"/>
                <button type="button" onClick={() => setShowPwd(!showPwd)} className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                  {showPwd ? <EyeOff size={16}/> : <Eye size={16}/>}
                </button>
              </div>
              {/* Strength indicator */}
              {password && (
                <div className="mt-2 flex gap-1">
                  {[1,2,3,4].map((level) => {
                    const strength = password.length >= 12 && /[A-Z]/.test(password) && /[0-9]/.test(password) && /[^A-Za-z0-9]/.test(password) ? 4
                      : password.length >= 10 && /[A-Z]/.test(password) && /[0-9]/.test(password) ? 3
                      : password.length >= 8 ? 2 : 1;
                    return <div key={level} className={clsx('h-1.5 flex-1 rounded-full transition-all', level<=strength
                      ? level===1?'bg-red-500':level===2?'bg-orange-400':level===3?'bg-yellow-400':'bg-green-500'
                      : 'bg-gray-200 dark:bg-gray-600')}/>;
                  })}
                </div>
              )}
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">Confirm password</label>
              <div className="relative">
                <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400"/>
                <input type="password" value={confirm} onChange={(e) => setConfirm(e.target.value)}
                  placeholder="Re-enter password" required
                  className={clsx('w-full pl-10 pr-4 py-2.5 rounded-xl border text-sm outline-none focus:ring-2 transition-all dark:bg-gray-700 dark:text-white',
                    confirm && password !== confirm ? 'border-red-300 focus:border-red-400 focus:ring-red-100' : 'border-gray-200 dark:border-gray-600 focus:border-brand-400 focus:ring-brand-100')}/>
              </div>
              {confirm && password !== confirm && <p className="text-xs text-red-500 mt-1">Passwords do not match</p>}
            </div>
            <button type="submit" disabled={loading || !password || password !== confirm}
              className="w-full flex items-center justify-center gap-2 py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-xl text-sm transition-all">
              {loading ? <Loader2 size={16} className="animate-spin"/> : null}
              {loading ? 'Saving…' : 'Set New Password'}
            </button>
          </form>
        </motion.div>
      )}

      {/* ── Step 4: Success ─────────────────────────────────────── */}
      {step === 4 && (
        <motion.div key="s4" {...stepVariants} transition={{ duration:0.2 }} className="text-center">
          <motion.div initial={{ scale:0 }} animate={{ scale:1 }} transition={{ type:'spring', stiffness:200, delay:0.1 }}
            className="w-16 h-16 bg-green-100 dark:bg-green-900/40 rounded-full flex items-center justify-center mx-auto mb-5">
            <CheckCircle2 size={32} className="text-green-600"/>
          </motion.div>
          <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white mb-2">Password reset!</h1>
          <p className="text-gray-400 text-sm mb-6">Your password has been updated successfully. You can now sign in with your new password.</p>
          <button onClick={() => navigate('/login')}
            className="w-full py-2.5 bg-brand-600 hover:bg-brand-700 text-white font-semibold rounded-xl text-sm transition-all">
            Sign in now
          </button>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
