import React from 'react';
import { Outlet, Link } from 'react-router-dom';

export default function AuthLayout() {
  return (
    <div className="min-h-screen flex bg-[#0f0d24]">
      {/* Brand panel — desktop */}
      <div className="hidden lg:flex lg:w-[46%] relative flex-col justify-between p-12 overflow-hidden">
        <div
          className="absolute inset-0"
          style={{
            background:
              'radial-gradient(ellipse 80% 60% at 20% 40%, rgba(124,58,237,0.45), transparent), radial-gradient(ellipse 60% 50% at 80% 80%, rgba(245,158,11,0.18), transparent), #0f0d24',
          }}
        />
        <div
          className="absolute inset-0 opacity-30"
          style={{
            backgroundImage:
              'radial-gradient(circle at 1px 1px, rgba(255,255,255,0.12) 1px, transparent 0)',
            backgroundSize: '28px 28px',
          }}
        />

        <Link to="/" className="relative z-10 inline-flex items-center gap-3 w-fit">
          <div className="w-11 h-11 bg-gradient-to-br from-violet-500 to-amber-500 rounded-2xl flex items-center justify-center shadow-lg shadow-violet-500/30">
            <span className="font-display font-black text-xl text-white">E</span>
          </div>
          <span className="font-display font-bold text-2xl text-white">
            Edu<span className="text-amber-400">Link</span>
          </span>
        </Link>

        <div className="relative z-10 max-w-md">
          <h2 className="font-display font-black text-4xl text-white leading-tight mb-4">
            Learn. Teach.<br />
            <span className="text-amber-400">Connect.</span>
          </h2>
          <p className="text-white/55 text-base leading-relaxed">
            Real-time chat, AI tutoring, and classroom tools —
            built for modern Ethiopian schools.
          </p>
          <div className="mt-8 flex flex-wrap gap-2">
            {['Chat', 'Classes', 'AI Tutor'].map((t) => (
              <span
                key={t}
                className="px-3 py-1 rounded-full text-xs font-medium bg-white/8 text-white/70 border border-white/10"
              >
                {t}
              </span>
            ))}
          </div>
        </div>

        <p className="relative z-10 text-white/30 text-xs">
          © {new Date().getFullYear()} EduLink · Free for schools
        </p>
      </div>

      {/* Form panel */}
      <div className="flex-1 flex flex-col items-center justify-center p-4 sm:p-8 relative">
        <div
          className="absolute inset-0 lg:hidden"
          style={{
            background:
              'radial-gradient(ellipse at top, rgba(124,58,237,0.35), transparent 55%), #0f0d24',
          }}
        />

        <div className="w-full max-w-md relative z-10">
          <div className="lg:hidden text-center mb-8">
            <Link to="/" className="inline-flex items-center gap-2.5">
              <div className="w-10 h-10 bg-gradient-to-br from-violet-500 to-amber-500 rounded-xl flex items-center justify-center">
                <span className="font-display font-black text-lg text-white">E</span>
              </div>
              <span className="font-display font-bold text-xl text-white">
                Edu<span className="text-amber-400">Link</span>
              </span>
            </Link>
          </div>

          <div className="bg-white dark:bg-gray-800 rounded-3xl shadow-2xl shadow-black/40 p-6 sm:p-8">
            <Outlet />
          </div>
        </div>
      </div>
    </div>
  );
}
