import React, { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { LogIn, UserPlus, MessageSquare, BookOpen, Sparkles, ChevronRight } from 'lucide-react';
import { useAuthStore } from '@/store';

export default function Landing() {
  const navigate = useNavigate();
  const { isAuthenticated } = useAuthStore();
  const [activeTab, setActiveTab] = useState('chat');

  // If already logged in, redirect immediately to dashboard (Telegram / Web app style)
  useEffect(() => {
    if (isAuthenticated) {
      navigate('/dashboard', { replace: true });
    }
  }, [isAuthenticated, navigate]);

  // Tab auto-switching interval for the interactive mockup
  useEffect(() => {
    const tabs = ['chat', 'classes', 'ai'];
    const interval = setInterval(() => {
      setActiveTab((prev) => {
        const nextIndex = (tabs.indexOf(prev) + 1) % tabs.length;
        return tabs[nextIndex];
      });
    }, 4500);
    return () => clearInterval(interval);
  }, []);

  if (isAuthenticated) return null;

  return (
    <div className="min-h-screen bg-[#0f0d24] flex items-center justify-center relative overflow-hidden font-sans">
      {/* Background gradients */}
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

      <div className="max-w-6xl w-full grid grid-cols-1 lg:grid-cols-12 gap-8 lg:gap-16 items-center relative z-10 px-6 sm:px-12 py-12">
        {/* Left Column: Interactive Showcase */}
        <motion.div
          initial={{ opacity: 0, x: -30 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.6 }}
          className="lg:col-span-7 hidden lg:flex flex-col text-left space-y-6"
        >
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-violet-500/10 text-violet-400 border border-violet-500/20 w-fit">
            <span>✨ Real-time classroom & campus ecosystem</span>
          </div>

          <h1 className="font-display font-black text-5xl text-white leading-tight">
            Edu<span className="text-amber-400">Link</span><br />
            <span className="text-white/95 text-4xl font-extrabold">Learn. Teach. Connect.</span>
          </h1>

          <p className="text-white/55 text-base leading-relaxed max-w-lg">
            Real-time chat, AI tutoring, virtual classrooms, and study tools built to make education seamless and engaging.
          </p>

          {/* Interactive Feature Selector Tabs */}
          <div className="flex gap-2 p-1 bg-white/5 border border-white/10 rounded-2xl w-fit">
            {[
              { id: 'chat', label: 'Chat Messaging', icon: MessageSquare },
              { id: 'classes', label: 'Virtual Classes', icon: BookOpen },
              { id: 'ai', label: 'AI Tutor 24/7', icon: Sparkles },
            ].map((tab) => {
              const Icon = tab.icon;
              const isActive = activeTab === tab.id;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium transition-all ${
                    isActive
                      ? 'bg-violet-600 text-white shadow-lg shadow-violet-600/30'
                      : 'text-white/60 hover:text-white hover:bg-white/5'
                  }`}
                >
                  <Icon size={16} />
                  {tab.label}
                </button>
              );
            })}
          </div>

          {/* Mockup Display Box */}
          <div className="bg-white/5 border border-white/10 rounded-3xl p-6 shadow-2xl relative overflow-hidden h-[340px] flex flex-col backdrop-blur-xl w-full">
            {/* Mock Window Controls */}
            <div className="flex items-center justify-between pb-4 border-b border-white/10 mb-4">
              <div className="flex gap-1.5">
                <span className="w-3 h-3 rounded-full bg-red-500/80" />
                <span className="w-3 h-3 rounded-full bg-yellow-500/80" />
                <span className="w-3 h-3 rounded-full bg-green-500/80" />
              </div>
              <span className="text-xs text-white/40 font-mono">
                {activeTab === 'chat' && 'chat.edulink.school'}
                {activeTab === 'classes' && 'classroom.edulink.school'}
                {activeTab === 'ai' && 'ai-tutor.edulink.school'}
              </span>
            </div>

            <div className="flex-1 relative overflow-hidden">
              <AnimatePresence mode="wait">
                {activeTab === 'chat' && (
                  <motion.div
                    key="chat-mock"
                    initial={{ opacity: 0, y: 15 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -15 }}
                    transition={{ duration: 0.3 }}
                    className="space-y-3"
                  >
                    <div className="flex items-start gap-3 max-w-[80%]">
                      <div className="w-8 h-8 rounded-full bg-violet-600 flex items-center justify-center text-xs font-bold text-white shrink-0">TA</div>
                      <div className="bg-white/10 border border-white/5 rounded-2xl p-3 text-sm text-white/90">
                        <p className="font-semibold text-xs text-violet-400 mb-0.5">Teacher Aster</p>
                        Welcome class! Let's discuss our upcoming chemistry assignment.
                      </div>
                    </div>
                    <div className="flex items-start gap-3 max-w-[80%] ml-auto flex-row-reverse">
                      <div className="w-8 h-8 rounded-full bg-amber-500 flex items-center justify-center text-xs font-bold text-white shrink-0">KB</div>
                      <div className="bg-violet-600 text-white rounded-2xl p-3 text-sm">
                        <p className="font-semibold text-xs text-amber-300 mb-0.5">Kebede</p>
                        I finished the organic chemistry section! Should we upload it today?
                      </div>
                    </div>
                    <div className="flex items-start gap-3 max-w-[85%]">
                      <div className="w-8 h-8 rounded-full bg-emerald-600 flex items-center justify-center text-xs font-bold text-white shrink-0">AI</div>
                      <div className="bg-emerald-950/40 border border-emerald-500/20 rounded-2xl p-3 text-sm text-emerald-200">
                        <p className="font-semibold text-xs text-emerald-400 mb-0.5">AI Classroom Bot</p>
                        Yes, Kebede. Upload portals remain open until Friday 11:59 PM.
                      </div>
                    </div>
                  </motion.div>
                )}

                {activeTab === 'classes' && (
                  <motion.div
                    key="classes-mock"
                    initial={{ opacity: 0, y: 15 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -15 }}
                    transition={{ duration: 0.3 }}
                    className="grid grid-cols-2 gap-4"
                  >
                    <div className="bg-white/10 border border-white/5 rounded-2xl p-4 flex flex-col justify-between h-[180px]">
                      <div>
                        <div className="flex items-center justify-between mb-2">
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-violet-500/20 text-violet-300">Grade 11</span>
                          <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-pulse" />
                        </div>
                        <h3 className="font-bold text-white text-base leading-tight">Advanced Chemistry</h3>
                        <p className="text-xs text-white/50 mt-1">Teacher: Dr. Aster</p>
                      </div>
                      <div className="flex items-center justify-between mt-4">
                        <span className="text-[11px] text-white/40">14 Students online</span>
                        <span className="px-3 py-1.5 bg-violet-600 text-white rounded-lg text-xs font-semibold">Join Live</span>
                      </div>
                    </div>

                    <div className="bg-white/10 border border-white/5 rounded-2xl p-4 flex flex-col justify-between h-[180px]">
                      <div>
                        <div className="flex items-center justify-between mb-2">
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-amber-500/20 text-amber-300">Grade 11</span>
                        </div>
                        <h3 className="font-bold text-white text-base leading-tight">Introduction to Calculus</h3>
                        <p className="text-xs text-white/50 mt-1">Teacher: Hagos G.</p>
                      </div>
                      <div>
                        <div className="flex justify-between text-[10px] text-white/50 mb-1">
                          <span>Syllabus progress</span>
                          <span>65%</span>
                        </div>
                        <div className="w-full h-1.5 bg-white/10 rounded-full overflow-hidden">
                          <div className="h-full bg-amber-500 rounded-full" style={{ width: '65%' }} />
                        </div>
                      </div>
                    </div>
                  </motion.div>
                )}

                {activeTab === 'ai' && (
                  <motion.div
                    key="ai-mock"
                    initial={{ opacity: 0, y: 15 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -15 }}
                    transition={{ duration: 0.3 }}
                    className="space-y-4"
                  >
                    <div className="bg-white/5 border border-white/10 rounded-xl p-3 text-sm text-white/80 w-fit max-w-[85%]">
                      "Help me solve this chemistry question step-by-step: How does catalyst affect activation energy?"
                    </div>
                    <div className="flex gap-3 max-w-[90%] ml-auto flex-row-reverse">
                      <div className="w-8 h-8 rounded-full bg-gradient-to-br from-violet-500 to-amber-500 flex items-center justify-center shrink-0">
                        <Sparkles size={14} className="text-white" />
                      </div>
                      <div className="bg-violet-950/40 border border-violet-500/30 rounded-2xl p-4 text-sm text-violet-100 space-y-2">
                        <p className="font-bold text-xs text-violet-400">EduLink AI Tutor</p>
                        <p className="leading-relaxed">
                          A catalyst lowers the **activation energy** required for a chemical reaction. It provides an alternative pathway with a lower energy barrier, allowing the reaction to proceed faster. 🧪✨
                        </p>
                      </div>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </div>
        </motion.div>

        {/* Right Column: Portal Login/Register Options */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.1 }}
          className="lg:col-span-5 w-full max-w-md mx-auto"
        >
          {/* Main Card (Matching your preferred login page theme, always dark & immersive) */}
          <div className="bg-[#12102b]/90 border border-white/10 rounded-3xl shadow-2xl shadow-black/45 p-8 backdrop-blur-md text-white">
            {/* Header / Logo */}
            <div className="flex flex-col items-center text-center">
              <div className="w-16 h-16 bg-gradient-to-br from-violet-500 to-amber-500 rounded-2xl flex items-center justify-center shadow-lg shadow-violet-500/30 mb-5">
                <span className="font-display font-black text-3xl text-white">E</span>
              </div>
              <h2 className="font-display font-bold text-3xl text-white">EduLink</h2>
              <p className="text-white/55 text-sm mt-1 mb-8">Choose an action to open the application</p>
            </div>

            {/* Action Buttons */}
            <div className="space-y-4">
              <Link
                to="/login"
                className="group flex items-center justify-between p-4 bg-white/5 border border-white/5 hover:border-violet-500/50 hover:bg-violet-500/10 rounded-2xl transition-all shadow-sm hover:shadow-md"
              >
                <div className="flex items-center gap-4">
                  <div className="w-12 h-12 bg-violet-500/10 text-violet-400 rounded-xl flex items-center justify-center group-hover:scale-105 transition-transform">
                    <LogIn size={22} />
                  </div>
                  <div className="text-left">
                    <h3 className="font-semibold text-white text-base">Sign In</h3>
                    <p className="text-xs text-white/40 mt-0.5">Access classes, chat, and files</p>
                  </div>
                </div>
                <ChevronRight size={18} className="text-white/40 group-hover:translate-x-1 group-hover:text-white transition-all" />
              </Link>

              <Link
                to="/register"
                className="group flex items-center justify-between p-4 bg-white/5 border border-white/5 hover:border-amber-500/50 hover:bg-amber-500/10 rounded-2xl transition-all shadow-sm hover:shadow-md"
              >
                <div className="flex items-center gap-4">
                  <div className="w-12 h-12 bg-amber-500/10 text-amber-400 rounded-xl flex items-center justify-center group-hover:scale-105 transition-transform">
                    <UserPlus size={22} />
                  </div>
                  <div className="text-left">
                    <h3 className="font-semibold text-white text-base">Register</h3>
                    <p className="text-xs text-white/40 mt-0.5">Create free student or teacher account</p>
                  </div>
                </div>
                <ChevronRight size={18} className="text-white/40 group-hover:translate-x-1 group-hover:text-white transition-all" />
              </Link>
            </div>

            {/* Quick trust metrics */}
            <div className="mt-8 pt-6 border-t border-white/10">
              <div className="grid grid-cols-3 gap-2">
                {[
                  { label: 'Real-time Chat', icon: MessageSquare },
                  { label: 'Classes', icon: BookOpen },
                  { label: 'AI Tutor', icon: Sparkles }
                ].map((item, idx) => {
                  const Icon = item.icon;
                  return (
                    <div key={idx} className="flex flex-col items-center text-center space-y-1">
                      <Icon size={16} className="text-violet-400" />
                      <span className="text-[10px] font-semibold text-white/60 leading-tight">
                        {item.label}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>

            <p className="text-center text-[11px] text-white/40 mt-8">
              © {new Date().getFullYear()} EduLink · Built for modern schools
            </p>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
