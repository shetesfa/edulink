import React from 'react';
import { Outlet, Link } from 'react-router-dom';

export default function AuthLayout() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-[#1E1B4B] via-violet-900 to-indigo-900 flex items-center justify-center p-4">
      <div className="fixed inset-0 opacity-20"
        style={{ backgroundImage: 'radial-gradient(circle at 1px 1px, rgba(255,255,255,0.15) 1px, transparent 0)', backgroundSize: '32px 32px' }}/>
      <div className="w-full max-w-md relative z-10">
        <div className="text-center mb-8">
          <Link to="/" className="inline-flex items-center gap-3">
            <div className="w-12 h-12 bg-gradient-to-br from-violet-500 to-amber-500 rounded-2xl flex items-center justify-center">
              <span className="font-display font-black text-2xl text-white">E</span>
            </div>
            <span className="font-display font-bold text-2xl text-white">
              Edu<span className="text-amber-400">Link</span>
            </span>
          </Link>
        </div>
        <div className="bg-white dark:bg-gray-800 rounded-3xl shadow-2xl p-8">
          <Outlet/>
        </div>
      </div>
    </div>
  );
}
