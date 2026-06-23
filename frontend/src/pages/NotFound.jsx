// ── NotFound ─────────────────────────────────────────────────
import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Home, ArrowLeft } from 'lucide-react';

export default function NotFound() {
  const navigate = useNavigate();
  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900 flex items-center justify-center p-6">
      <motion.div initial={{ opacity:0, y:20 }} animate={{ opacity:1, y:0 }} className="text-center max-w-md">
        <div className="relative mb-8">
          <span className="text-9xl font-display font-black text-brand-100 dark:text-brand-900 select-none">404</span>
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="w-24 h-24 bg-gradient-to-br from-brand-600 to-amber-500 rounded-3xl flex items-center justify-center shadow-glow">
              <span className="text-3xl">🔍</span>
            </div>
          </div>
        </div>
        <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white mb-2">Page not found</h1>
        <p className="text-gray-400 mb-8">The page you're looking for doesn't exist or has been moved.</p>
        <div className="flex gap-3 justify-center">
          <button onClick={() => navigate(-1)} className="flex items-center gap-2 px-5 py-2.5 border border-gray-200 dark:border-gray-700 rounded-xl text-sm font-semibold text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 transition-all">
            <ArrowLeft size={15}/> Go back
          </button>
          <Link to="/dashboard" className="flex items-center gap-2 px-5 py-2.5 bg-brand-600 hover:bg-brand-700 text-white rounded-xl text-sm font-semibold transition-all">
            <Home size={15}/> Dashboard
          </Link>
        </div>
      </motion.div>
    </div>
  );
}
