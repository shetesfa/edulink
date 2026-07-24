import React, { useRef } from 'react';
import clsx from 'clsx';

export function GoogleIcon({ size = 18 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden="true">
      <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
      <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
      <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
      <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
    </svg>
  );
}

export function OtpInput({ value, onChange, disabled = false }) {
  const inputs = useRef([]);
  const digits = value.split('');

  const handleChange = (i, e) => {
    const val = e.target.value.replace(/\D/g, '');
    const next = [...digits];
    next[i] = val.slice(-1);
    onChange(next.join('').slice(0, 6));
    if (val && i < 5) inputs.current[i + 1]?.focus();
  };

  const handleKeyDown = (i, e) => {
    if (e.key === 'Backspace' && !digits[i] && i > 0) {
      inputs.current[i - 1]?.focus();
    }
  };

  const handlePaste = (e) => {
    const pasted = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6);
    if (pasted) {
      onChange(pasted);
      inputs.current[Math.min(pasted.length, 5)]?.focus();
    }
    e.preventDefault();
  };

  return (
    <div className="flex gap-2.5 justify-center">
      {[0, 1, 2, 3, 4, 5].map((i) => (
        <input
          key={i}
          ref={(el) => { inputs.current[i] = el; }}
          type="text"
          inputMode="numeric"
          autoComplete={i === 0 ? 'one-time-code' : 'off'}
          maxLength={1}
          disabled={disabled}
          value={digits[i] || ''}
          onChange={(e) => handleChange(i, e)}
          onKeyDown={(e) => handleKeyDown(i, e)}
          onPaste={handlePaste}
          className={clsx(
            'w-11 h-14 sm:w-12 sm:h-14 text-center text-xl font-bold rounded-2xl border-2 outline-none transition-all bg-white dark:bg-gray-700 dark:text-white',
            digits[i]
              ? 'border-brand-500 bg-brand-50 dark:bg-brand-900/20 text-brand-700 dark:text-brand-300 shadow-sm shadow-brand-500/20'
              : 'border-gray-200 dark:border-gray-600 focus:border-brand-400 focus:ring-4 focus:ring-brand-100 dark:focus:ring-brand-900/30'
          )}
        />
      ))}
    </div>
  );
}

export const ROLES = [
  {
    id: 'student',
    label: 'I\'m a Student',
    desc: 'Join classes, chat with teachers, learn with AI',
    accent: 'bg-brand-gradient',
    ring: 'ring-brand-400/40',
    bg: 'bg-brand-50 dark:bg-brand-900/20 border-brand-200 dark:border-brand-800',
  },
  {
    id: 'teacher',
    label: 'I\'m a Teacher',
    desc: 'Create classes, teach live, message students freely',
    accent: 'bg-gradient-to-br from-amber-500 to-orange-600',
    ring: 'ring-amber-400/40',
    bg: 'bg-amber-50 dark:bg-amber-900/20 border-amber-200 dark:border-amber-800',
  },
];

export function passwordStrength(password) {
  if (!password) return 0;
  if (password.length >= 12 && /[A-Z]/.test(password) && /[0-9]/.test(password) && /[^A-Za-z0-9]/.test(password)) return 4;
  if (password.length >= 10 && /[A-Z]/.test(password) && /[0-9]/.test(password)) return 3;
  if (password.length >= 8) return 2;
  return 1;
}

export const STRENGTH_LABELS = ['', 'Weak', 'Fair', 'Good', 'Strong'];
export const STRENGTH_COLORS = ['', 'bg-red-400', 'bg-amber-400', 'bg-blue-400', 'bg-green-500'];
