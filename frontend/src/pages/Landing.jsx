import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import {
  MessageSquare, BookOpen, Video, Brain, BarChart2, Bot,
  ChevronRight, Star, CheckCircle2, Menu, X, Sparkles,
} from 'lucide-react';

const FEATURES = [
  { icon: MessageSquare, title: 'Real-Time Chat',      desc: 'Telegram-style messaging with reactions, file sharing, voice notes and group chats.',       color: 'violet' },
  { icon: BookOpen,      title: 'Lesson Library',      desc: 'Upload PDFs, videos and notes. Students bookmark, comment and download anytime.',          color: 'blue'   },
  { icon: Video,         title: 'Video Meetings',      desc: 'HD video calls with screen sharing, raise hand, recording and participant controls.',        color: 'green'  },
  { icon: Brain,         title: 'Smart Quizzes',       desc: 'MCQ, True/False, Fill-in-blank and Essay. Auto-graded with instant analytics.',              color: 'amber'  },
  { icon: BarChart2,     title: 'Progress Tracking',   desc: 'Per-student dashboards with charts showing lesson completion, quiz scores and grades.',      color: 'red'    },
  { icon: Bot,           title: 'AI Study Assistant',  desc: '6 free AI providers working together — never stops. Explains, summarizes, translates to Amharic.', color: 'indigo' },
];

const STATS = [
  { value: '12K+', label: 'Active Students' },
  { value: '850+', label: 'Teachers' },
  { value: '6',    label: 'Free AI Providers' },
  { value: '100%', label: 'Free to Use' },
];

const TESTIMONIALS = [
  { name: 'Biruk Tadesse',    role: 'Principal, Unity Academy',          text: 'EduLink transformed how our school communicates. Students submit assignments on time and teachers love the quiz builder.', rating: 5 },
  { name: 'Sara Haile',       role: 'Biology Teacher, St. Mary\'s School', text: 'The AI assistant is incredible. My students ask questions any time — even at midnight before an exam!',                  rating: 5 },
  { name: 'Yonas Mengistu',   role: 'School Admin, Bethel Secondary',    text: 'Managing 800 students used to be chaos. The admin dashboard gives me a clear view of everything in real time.',           rating: 5 },
];

const FAQ = [
  { q: 'Is EduLink free?',                       a: 'Yes — completely free for schools with up to 100 students. All 6 AI providers used are free tier APIs.' },
  { q: 'Does it work on mobile phones?',          a: 'Yes! EduLink is mobile-first. Students can install it as an app on Android and iOS from their browser, or use the APK file.' },
  { q: 'What languages does EduLink support?',    a: 'English and Amharic (አማርኛ) throughout the entire platform. The AI assistant can also translate lesson content into any language.' },
  { q: 'Will the AI always work for students?',   a: 'Yes. EduLink uses 6 different free AI providers in a chain. If one runs out of daily requests, it automatically switches to the next one.' },
  { q: 'Can students join without an account?',   a: 'Students need a free account (takes 1 minute). Teachers share a join code and students are in the class instantly.' },
];

function ColorClasses(color) {
  return {
    violet: { bg: 'bg-violet-100 dark:bg-violet-900/30', text: 'text-violet-600' },
    blue:   { bg: 'bg-blue-100 dark:bg-blue-900/30',     text: 'text-blue-600'   },
    green:  { bg: 'bg-green-100 dark:bg-green-900/30',   text: 'text-green-600'  },
    amber:  { bg: 'bg-amber-100 dark:bg-amber-900/30',   text: 'text-amber-600'  },
    red:    { bg: 'bg-red-100 dark:bg-red-900/30',       text: 'text-red-500'    },
    indigo: { bg: 'bg-indigo-100 dark:bg-indigo-900/30', text: 'text-indigo-600' },
  }[color] || { bg: 'bg-gray-100', text: 'text-gray-600' };
}

export default function Landing() {
  const [mobileOpen, setMobile] = useState(false);
  const [openFAQ, setOpenFAQ]   = useState(null);

  return (
    <div className="min-h-screen bg-white dark:bg-gray-900 font-sans">
      {/* NAV */}
      <nav className="fixed top-0 left-0 right-0 z-50 bg-[#1E1B4B]/95 backdrop-blur border-b border-white/10">
        <div className="max-w-6xl mx-auto px-4 h-16 flex items-center justify-between">
          <Link to="/" className="flex items-center gap-2.5">
            <div className="w-9 h-9 bg-gradient-to-br from-violet-600 to-amber-500 rounded-xl flex items-center justify-center font-black text-white text-lg font-display">E</div>
            <span className="font-display font-bold text-xl text-white">Edu<span className="text-amber-400">Link</span></span>
          </Link>
          <div className="hidden md:flex items-center gap-6">
            {['Features','For Schools','AI','FAQ'].map(l => (
              <a key={l} href={`#${l.toLowerCase().replace(' ','')}`} className="text-white/70 hover:text-white text-sm font-medium transition-colors">{l}</a>
            ))}
          </div>
          <div className="flex items-center gap-2">
            <Link to="/login"    className="hidden md:inline-flex px-4 py-2 text-white/80 hover:text-white text-sm font-medium transition-colors">Sign in</Link>
            <Link to="/register" className="px-4 py-2 bg-violet-600 hover:bg-violet-700 text-white rounded-xl text-sm font-semibold transition-all">Get started</Link>
            <button onClick={() => setMobile(!mobileOpen)} className="md:hidden p-2 text-white/70 hover:text-white">
              {mobileOpen ? <X size={20}/> : <Menu size={20}/>}
            </button>
          </div>
        </div>
        {mobileOpen && (
          <div className="md:hidden bg-[#1E1B4B] border-t border-white/10 px-4 py-3 flex flex-col gap-2">
            {['Features','For Schools','AI','FAQ'].map(l => (
              <a key={l} href={`#${l.toLowerCase().replace(' ','')}`} onClick={() => setMobile(false)} className="text-white/70 hover:text-white py-2 text-sm font-medium transition-colors">{l}</a>
            ))}
            <Link to="/login" className="text-white/70 py-2 text-sm font-medium">Sign in</Link>
          </div>
        )}
      </nav>

      {/* HERO */}
      <section className="min-h-screen bg-[#1E1B4B] flex items-center pt-16 relative overflow-hidden">
        <div className="absolute inset-0" style={{ backgroundImage:'radial-gradient(circle at 1px 1px, rgba(124,58,237,0.07) 1px, transparent 0)', backgroundSize:'48px 48px' }}/>
        <div className="absolute top-1/4 left-1/2 -translate-x-1/2 w-[600px] h-[400px] bg-violet-600/15 rounded-full blur-3xl pointer-events-none"/>
        <div className="max-w-6xl mx-auto px-4 py-20 relative z-10 text-center">
          <motion.div initial={{ opacity:0, y:20 }} animate={{ opacity:1, y:0 }}>
            <div className="inline-flex items-center gap-2 bg-violet-600/20 border border-violet-500/30 rounded-full px-4 py-1.5 text-violet-300 text-sm font-medium mb-8">
              <span className="w-2 h-2 bg-green-400 rounded-full animate-pulse"/>
              Now available in Amharic & English
            </div>
            <h1 className="font-display font-black text-5xl sm:text-6xl lg:text-7xl text-white leading-tight mb-6">
              Learn, Teach<br className="hidden sm:block"/> and{' '}
              <span className="text-amber-400">Connect</span>
            </h1>
            <p className="text-white/60 text-lg sm:text-xl max-w-2xl mx-auto mb-10 leading-relaxed">
              A complete platform for schools, universities and self-learning communities.<br/>
              Real-time chat · AI tutoring · Video meetings · Classroom management
            </p>
            <div className="flex flex-wrap items-center justify-center gap-3 mb-14">
              <Link to="/register?role=student" className="px-6 py-3 bg-violet-600 hover:bg-violet-700 text-white rounded-2xl font-semibold text-base transition-all hover:scale-105 shadow-lg shadow-violet-500/30">
                Join as Student →
              </Link>
              <Link to="/register?role=teacher" className="px-6 py-3 bg-white/10 hover:bg-white/15 border border-white/20 text-white rounded-2xl font-semibold text-base transition-all">
                Join as Teacher
              </Link>
              <Link to="/register?role=school_admin" className="px-6 py-3 bg-white/10 hover:bg-white/15 border border-white/20 text-white rounded-2xl font-semibold text-base transition-all">
                Create School
              </Link>
            </div>
            <div className="flex flex-wrap items-center justify-center gap-8 sm:gap-12">
              {STATS.map(s => (
                <div key={s.label} className="text-center">
                  <div className="font-display font-black text-3xl text-white">{s.value}</div>
                  <div className="text-white/50 text-sm mt-1">{s.label}</div>
                </div>
              ))}
            </div>
          </motion.div>
        </div>
      </section>

      {/* FEATURES */}
      <section id="features" className="py-20 bg-gray-50 dark:bg-gray-800">
        <div className="max-w-6xl mx-auto px-4">
          <div className="text-center mb-14">
            <span className="text-violet-600 text-sm font-bold uppercase tracking-widest">Everything you need</span>
            <h2 className="font-display font-black text-4xl text-gray-900 dark:text-white mt-2 mb-3">Built for modern schools</h2>
            <p className="text-gray-500 dark:text-gray-400 max-w-xl mx-auto">From primary schools to universities — one platform for all your communication and learning needs.</p>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
            {FEATURES.map((f, i) => {
              const c = ColorClasses(f.color);
              return (
                <motion.div key={f.title} initial={{ opacity:0, y:20 }} whileInView={{ opacity:1, y:0 }} viewport={{ once:true }} transition={{ delay:i*0.08 }}
                  className="bg-white dark:bg-gray-900 rounded-2xl p-5 border border-gray-100 dark:border-gray-700 hover:border-violet-200 hover:shadow-lg transition-all group">
                  <div className={`w-12 h-12 rounded-xl ${c.bg} flex items-center justify-center mb-4`}>
                    <f.icon size={22} className={c.text}/>
                  </div>
                  <h3 className="font-display font-bold text-gray-900 dark:text-white mb-2">{f.title}</h3>
                  <p className="text-gray-500 dark:text-gray-400 text-sm leading-relaxed">{f.desc}</p>
                </motion.div>
              );
            })}
          </div>
        </div>
      </section>

      {/* AI SECTION */}
      <section id="ai" className="py-20 bg-white dark:bg-gray-900">
        <div className="max-w-5xl mx-auto px-4">
          <div className="text-center mb-12">
            <span className="text-violet-600 text-sm font-bold uppercase tracking-widest">AI Study Assistant</span>
            <h2 className="font-display font-black text-4xl text-gray-900 dark:text-white mt-2 mb-3">AI that never stops working</h2>
            <p className="text-gray-500 dark:text-gray-400 max-w-xl mx-auto">6 free AI providers connected together. When one runs out of daily quota, EduLink automatically switches to the next one. Students always get help — completely free.</p>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 mb-10">
            {[
              { name:'Google Gemini',  limit:'1,500/day',  speed:'Fast',       color:'bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800' },
              { name:'Groq (Llama 3)', limit:'14,400/day', speed:'Ultra Fast', color:'bg-orange-50 dark:bg-orange-900/20 border-orange-200 dark:border-orange-800' },
              { name:'Cohere',         limit:'1,000/day',  speed:'Fast',       color:'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800' },
              { name:'Mistral AI',     limit:'1,000/day',  speed:'Fast',       color:'bg-purple-50 dark:bg-purple-900/20 border-purple-200 dark:border-purple-800' },
              { name:'Together AI',    limit:'1,000/day',  speed:'Medium',     color:'bg-pink-50 dark:bg-pink-900/20 border-pink-200 dark:border-pink-800' },
              { name:'HuggingFace',    limit:'Unlimited',  speed:'Always on',  color:'bg-amber-50 dark:bg-amber-900/20 border-amber-200 dark:border-amber-800' },
            ].map((p, i) => (
              <motion.div key={p.name} initial={{ opacity:0, scale:0.9 }} whileInView={{ opacity:1, scale:1 }} viewport={{ once:true }} transition={{ delay:i*0.06 }}
                className={`rounded-xl border p-4 ${p.color}`}>
                <p className="font-semibold text-sm text-gray-800 dark:text-gray-200">{p.name}</p>
                <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">{p.limit}</p>
                <span className="inline-block mt-2 text-xs bg-green-100 dark:bg-green-900/40 text-green-700 dark:text-green-400 px-2 py-0.5 rounded-full font-medium">{p.speed}</span>
              </motion.div>
            ))}
          </div>
          <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
            {['Explain any concept','Summarize lessons','Generate quizzes','Translate to Amharic'].map(f => (
              <div key={f} className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-300">
                <CheckCircle2 size={16} className="text-green-500 flex-shrink-0"/>
                {f}
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* TESTIMONIALS */}
      <section className="py-20 bg-gray-50 dark:bg-gray-800">
        <div className="max-w-5xl mx-auto px-4">
          <div className="text-center mb-12">
            <h2 className="font-display font-black text-4xl text-gray-900 dark:text-white mb-3">Loved by schools</h2>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
            {TESTIMONIALS.map((t, i) => (
              <motion.div key={t.name} initial={{ opacity:0, y:20 }} whileInView={{ opacity:1, y:0 }} viewport={{ once:true }} transition={{ delay:i*0.1 }}
                className="bg-white dark:bg-gray-900 rounded-2xl p-5 border border-gray-100 dark:border-gray-700">
                <div className="flex gap-0.5 mb-3">
                  {[...Array(t.rating)].map((_,i) => <Star key={i} size={14} className="text-amber-400 fill-amber-400"/>)}
                </div>
                <p className="text-gray-600 dark:text-gray-300 text-sm leading-relaxed mb-4 italic">"{t.text}"</p>
                <div>
                  <p className="font-semibold text-sm text-gray-900 dark:text-white">{t.name}</p>
                  <p className="text-xs text-gray-400">{t.role}</p>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* FAQ */}
      <section id="faq" className="py-20 bg-white dark:bg-gray-900">
        <div className="max-w-2xl mx-auto px-4">
          <h2 className="font-display font-black text-4xl text-gray-900 dark:text-white text-center mb-12">Frequently asked</h2>
          <div className="space-y-2">
            {FAQ.map((item, i) => (
              <div key={i} className="border border-gray-100 dark:border-gray-700 rounded-xl overflow-hidden">
                <button onClick={() => setOpenFAQ(openFAQ === i ? null : i)}
                  className="w-full flex items-center justify-between px-5 py-4 text-left text-sm font-semibold text-gray-900 dark:text-white hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                  {item.q}
                  <span className={`text-violet-600 transition-transform ${openFAQ === i ? 'rotate-45' : ''}`}>+</span>
                </button>
                {openFAQ === i && (
                  <div className="px-5 pb-4 text-sm text-gray-500 dark:text-gray-400 leading-relaxed">{item.a}</div>
                )}
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-20 bg-[#1E1B4B] relative overflow-hidden">
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-violet-600/20 rounded-full blur-3xl pointer-events-none"/>
        <div className="max-w-3xl mx-auto px-4 text-center relative z-10">
          <h2 className="font-display font-black text-4xl sm:text-5xl text-white mb-4">Ready to transform your school?</h2>
          <p className="text-white/60 text-lg mb-8">Join thousands of students and teachers already learning on EduLink.</p>
          <div className="flex flex-wrap justify-center gap-3">
            <Link to="/register?role=school_admin" className="px-7 py-3.5 bg-amber-500 hover:bg-amber-400 text-gray-900 font-bold rounded-2xl transition-all hover:scale-105 shadow-lg shadow-amber-500/30">
              Create your school free →
            </Link>
            <Link to="/register" className="px-7 py-3.5 border border-white/30 text-white hover:bg-white/10 rounded-2xl font-semibold transition-all">
              Create student account
            </Link>
          </div>
        </div>
      </section>

      {/* FOOTER */}
      <footer className="bg-gray-950 py-10 px-4">
        <div className="max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 bg-gradient-to-br from-violet-600 to-amber-500 rounded-lg flex items-center justify-center font-black text-white text-sm font-display">E</div>
            <span className="font-display font-bold text-white">Edu<span className="text-amber-400">Link</span></span>
          </div>
          <p className="text-gray-500 text-sm">© 2026 EduLink · Made with ❤️ for Ethiopian Education</p>
          <div className="flex gap-4 text-sm text-gray-500">
            <Link to="/login"    className="hover:text-white transition-colors">Sign in</Link>
            <Link to="/register" className="hover:text-white transition-colors">Register</Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
