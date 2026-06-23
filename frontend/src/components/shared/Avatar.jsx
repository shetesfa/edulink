import React from 'react';
import clsx from 'clsx';

const SIZES = {
  xs: 'w-6 h-6 text-[10px]',
  sm: 'w-8 h-8 text-xs',
  md: 'w-10 h-10 text-sm',
  lg: 'w-14 h-14 text-lg',
  xl: 'w-20 h-20 text-2xl',
};

const GRADIENTS = [
  'from-violet-500 to-violet-700',
  'from-blue-500 to-cyan-600',
  'from-green-500 to-emerald-600',
  'from-orange-500 to-amber-600',
  'from-pink-500 to-rose-600',
  'from-indigo-500 to-violet-600',
];

export default function Avatar({ user, size = 'md', className = '' }) {
  const sizeClass = SIZES[size] || SIZES.md;
  const name      = user?.full_name || user?.first_name || '';
  const initials  = name.split(' ').map((n) => n[0]).join('').slice(0, 2).toUpperCase() || '?';
  const gradient  = GRADIENTS[(name.charCodeAt(0) || 0) % GRADIENTS.length];

  if (user?.profile_photo) {
    return (
      <img
        src={user.profile_photo}
        alt={name}
        className={clsx('rounded-full object-cover flex-shrink-0', sizeClass, className)}
        onError={(e) => { e.target.style.display = 'none'; }}
      />
    );
  }

  return (
    <div className={clsx(
      'rounded-full flex items-center justify-center font-bold text-white flex-shrink-0 bg-gradient-to-br select-none',
      gradient, sizeClass, className
    )}>
      {initials}
    </div>
  );
}
