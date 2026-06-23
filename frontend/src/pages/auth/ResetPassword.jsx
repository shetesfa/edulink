// Re-export — ResetPassword is handled inside ForgotPassword (step 3)
// This file handles the /reset-password?token=xxx&email=xxx URL flow
// (clicked from email link — alternative to OTP flow)

import React, { useState, useEffect } from 'react';
import { useSearchParams, useNavigate, Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Lock, Eye, EyeOff, CheckCircle2, Loader2, ArrowLeft } from 'lucide-react';
import { authAPI } from '@/utils/api';
import toast from 'react-hot-toast';
import clsx from 'clsx';

export default function ResetPassword() {
  const [params]   = useSearchParams();
  const navigate   = useNavigate();
  const token      = params.get('token') || '';
  const email      = params.get('email') || '';

  const [password, setPassword]   = useState('');
  const [confirm,  setConfirm]    = useState('');
  const [showPwd,  setShowPwd]    = useState(false);
  const [loading,  setLoading]    = useState(false);
  const [done,     setDone]       = useState(false);

  useEffect(() => {
    if (!token || !email) {
      toast.error('Invalid reset link. Please request a new one.');
      navigate('/forgot-password');
    }
  }, [token, email]);

  const strength = password.length === 0 ? 0
    : password.length >= 12 && /[A-Z]/.test(password) && /[0-9]/.test(password) && /[^A-Za-z0-9]/.test(password) ? 4
    : password.length >= 10 && /[A-Z]/.test(password) && /[0-9]/.test(password) ? 3
    : password.length >= 8 ? 2 : 1;

  const strengthLabel = ['','Weak','Fair','Good','Strong'];
  const strengthColor = ['','bg-red-500','bg-orange-400','bg-yellow-400','bg-green-500'];

  const submit = async (e) => {
    e.preventDefault();
    if (password.length < 8)      return toast.error('Password must be at least 8 characters');
    if (password !== confirm)     return toast.error('Passwords do not match');
    setLoading(true);
    try {
      await authAPI.resetPassword({ email, token, password, password_confirmation: confirm });
      setDone(true);
    } catch (err) {
      toast.error(err.response?.data?.message || 'Reset link expired. Please request a new one.');
      navigate('/forgot-password');
    } finally { setLoading(false); }
  };

  if (done) return (
    <motion.div initial={{ opacity:0,y:16 }} animate={{ opacity:1,y:0 }} className="text-center">
      <motion.div initial={{ scale:0 }} animate={{ scale:1 }} transition={{ type:'spring',stiffness:200,delay:0.1 }}
        className="w-16 h-16 bg-green-100 dark:bg-green-900/40 rounded-full flex items-center justify-center mx-auto mb-5">
        <CheckCircle2 size={32} className="text-green-600"/>
      </motion.div>
      <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white mb-2">Password updated!</h1>
      <p className="text-gray-400 text-sm mb-6">Your password has been changed. You can now sign in.</p>
      <button onClick={() => navigate('/login')}
        className="w-full py-2.5 bg-brand-600 hover:bg-brand-700 text-white font-semibold rounded-xl text-sm transition-all">
        Sign in now
      </button>
    </motion.div>
  );

  return (
    <motion.div initial={{ opacity:0,y:16 }} animate={{ opacity:1,y:0 }}>
      <div className="text-center mb-6">
        <div className="w-14 h-14 bg-brand-100 dark:bg-brand-900/40 rounded-2xl flex items-center justify-center mx-auto mb-4">
          <Lock size={26} className="text-brand-600"/>
        </div>
        <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white">Set new password</h1>
        <p className="text-gray-400 text-sm mt-1">For <strong className="text-gray-600 dark:text-gray-300">{email}</strong></p>
      </div>

      <form onSubmit={submit} className="space-y-4">
        {/* New password */}
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">New password</label>
          <div className="relative">
            <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400"/>
            <input
              type={showPwd ? 'text' : 'password'}
              value={password} onChange={(e) => setPassword(e.target.value)}
              placeholder="At least 8 characters" required autoFocus
              className="w-full pl-10 pr-10 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-sm outline-none focus:border-brand-400 focus:ring-2 focus:ring-brand-100 dark:text-white transition-all"
            />
            <button type="button" onClick={() => setShowPwd(!showPwd)}
              className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
              {showPwd ? <EyeOff size={16}/> : <Eye size={16}/>}
            </button>
          </div>
          {/* Strength meter */}
          {password && (
            <div className="mt-2 space-y-1">
              <div className="flex gap-1">
                {[1,2,3,4].map((lvl) => (
                  <div key={lvl} className={clsx('h-1.5 flex-1 rounded-full transition-all',
                    lvl <= strength ? strengthColor[strength] : 'bg-gray-200 dark:bg-gray-600')}/>
                ))}
              </div>
              <p className={clsx('text-xs font-medium',
                strength<=1?'text-red-500':strength===2?'text-orange-400':strength===3?'text-yellow-500':'text-green-500')}>
                {strengthLabel[strength]}
              </p>
            </div>
          )}
        </div>

        {/* Confirm password */}
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">Confirm new password</label>
          <div className="relative">
            <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400"/>
            <input
              type="password" value={confirm} onChange={(e) => setConfirm(e.target.value)}
              placeholder="Re-enter password" required
              className={clsx('w-full pl-10 pr-4 py-2.5 rounded-xl border text-sm outline-none focus:ring-2 transition-all dark:bg-gray-700 dark:text-white',
                confirm && password !== confirm
                  ? 'border-red-300 focus:border-red-400 focus:ring-red-100'
                  : 'border-gray-200 dark:border-gray-600 focus:border-brand-400 focus:ring-brand-100')}
            />
          </div>
          {confirm && password !== confirm && (
            <p className="text-xs text-red-500 mt-1">Passwords do not match</p>
          )}
          {confirm && password === confirm && confirm.length >= 8 && (
            <p className="text-xs text-green-500 mt-1 flex items-center gap-1">
              <CheckCircle2 size={11}/> Passwords match
            </p>
          )}
        </div>

        <button type="submit" disabled={loading || !password || password !== confirm || strength < 2}
          className="w-full flex items-center justify-center gap-2 py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-xl text-sm transition-all">
          {loading ? <Loader2 size={16} className="animate-spin"/> : <Lock size={15}/>}
          {loading ? 'Saving…' : 'Set New Password'}
        </button>
      </form>

      <p className="text-center mt-5">
        <Link to="/login" className="flex items-center justify-center gap-1.5 text-sm text-brand-600 hover:text-brand-700 font-medium">
          <ArrowLeft size={13}/> Back to login
        </Link>
      </p>
    </motion.div>
  );
}
