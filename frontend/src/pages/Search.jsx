import React, { useState, useEffect, useRef } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { Search, Users, BookOpen, FileText, Brain, Hash, X, Loader2, ChevronRight } from 'lucide-react';
import { searchAPI } from '@/utils/api';
import { useAuthStore } from '@/store';
import { format } from 'date-fns';
import clsx from 'clsx';

const TYPES = [
  { id:'all',      label:'All',       icon: Search   },
  { id:'users',    label:'People',    icon: Users    },
  { id:'classes',  label:'Classes',   icon: Hash     },
  { id:'lessons',  label:'Lessons',   icon: BookOpen },
  { id:'assignments', label:'Assignments', icon: FileText },
  { id:'quizzes',  label:'Quizzes',   icon: Brain    },
];

export default function SearchPage() {
  const [params, setParams]   = useSearchParams();
  const [query, setQuery]     = useState(params.get('q') || '');
  const [type, setType]       = useState(params.get('type') || 'all');
  const [results, setResults] = useState(null);
  const [loading, setLoading] = useState(false);
  const inputRef              = useRef();

  useEffect(() => { inputRef.current?.focus(); }, []);

  useEffect(() => {
    if (!query.trim()) { setResults(null); return; }
    const timer = setTimeout(doSearch, 300);
    return () => clearTimeout(timer);
  }, [query, type]);

  const doSearch = async () => {
    setLoading(true);
    try {
      const { data } = await searchAPI.search(query.trim(), type);
      setResults(data.results || data);
      setParams({ q: query.trim(), type });
    } catch { setResults(null); }
    finally { setLoading(false); }
  };

  const clear = () => { setQuery(''); setResults(null); inputRef.current?.focus(); };

  const total = results ? Object.values(results).reduce((s, v) => s + (Array.isArray(v) ? v.length : 0), 0) : 0;

  return (
    <div className="max-w-3xl mx-auto p-4 sm:p-6">
      {/* Search bar */}
      <div className="relative mb-5">
        <Search size={18} className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400"/>
        <input
          ref={inputRef}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && doSearch()}
          placeholder="Search students, classes, lessons, assignments…"
          className="w-full pl-11 pr-12 py-3.5 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl text-sm outline-none focus:border-brand-400 focus:ring-2 focus:ring-brand-100 shadow-card dark:text-white transition-all"
        />
        {query && (
          <button onClick={clear} className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 transition-colors">
            <X size={16}/>
          </button>
        )}
      </div>

      {/* Type filter */}
      <div className="flex gap-2 overflow-x-auto pb-2 mb-6">
        {TYPES.map((t) => (
          <button key={t.id} onClick={() => setType(t.id)}
            className={clsx('flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-sm font-medium whitespace-nowrap transition-all flex-shrink-0',
              type === t.id
                ? 'bg-brand-600 text-white shadow-md'
                : 'bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300 hover:border-brand-300'
            )}>
            <t.icon size={14}/> {t.label}
          </button>
        ))}
      </div>

      {/* Results */}
      <AnimatePresence mode="wait">
        {!query && (
          <motion.div key="empty" initial={{ opacity:0 }} animate={{ opacity:1 }} className="text-center py-16">
            <div className="w-20 h-20 bg-gray-100 dark:bg-gray-700 rounded-2xl flex items-center justify-center mx-auto mb-4">
              <Search size={32} className="text-gray-300 dark:text-gray-500"/>
            </div>
            <h2 className="font-display font-semibold text-gray-700 dark:text-gray-300 mb-2">Search EduLink</h2>
            <p className="text-sm text-gray-400">Find students, teachers, classes, lessons and more</p>
            {/* Quick suggestions */}
            <div className="flex flex-wrap justify-center gap-2 mt-6">
              {['Biology','Mathematics','Grade 10','Quiz','Assignment'].map((s) => (
                <button key={s} onClick={() => setQuery(s)} className="px-3 py-1.5 bg-brand-50 dark:bg-brand-900/20 text-brand-600 dark:text-brand-400 text-xs font-medium rounded-xl border border-brand-200 dark:border-brand-800 hover:bg-brand-100 transition-all">
                  {s}
                </button>
              ))}
            </div>
          </motion.div>
        )}

        {query && loading && (
          <motion.div key="loading" initial={{ opacity:0 }} animate={{ opacity:1 }} className="flex items-center justify-center py-16">
            <div className="flex items-center gap-3 text-gray-400">
              <Loader2 size={20} className="animate-spin"/>
              <span className="text-sm">Searching…</span>
            </div>
          </motion.div>
        )}

        {query && !loading && results && total === 0 && (
          <motion.div key="no-results" initial={{ opacity:0 }} animate={{ opacity:1 }} className="text-center py-16">
            <p className="text-gray-400">No results for <strong className="text-gray-700 dark:text-gray-200">"{query}"</strong></p>
            <p className="text-sm text-gray-400 mt-1">Try different keywords or check the spelling</p>
          </motion.div>
        )}

        {query && !loading && results && total > 0 && (
          <motion.div key="results" initial={{ opacity:0,y:8 }} animate={{ opacity:1,y:0 }} className="space-y-6">
            <p className="text-sm text-gray-400">{total} result{total!==1?'s':''} for <strong className="text-gray-700 dark:text-gray-200">"{query}"</strong></p>

            {/* Users */}
            {results.users?.length > 0 && (
              <Section title="People" icon={Users}>
                {results.users.map((u) => (
                  <Link key={u.id} to={`/profile/${u.username}`}
                    className="flex items-center gap-3 p-3 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700 group transition-all">
                    <div className="w-10 h-10 rounded-full bg-gradient-to-br from-brand-400 to-brand-600 flex items-center justify-center text-white font-bold text-sm flex-shrink-0">
                      {u.first_name?.[0]}{u.last_name?.[0]}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-gray-900 dark:text-white group-hover:text-brand-600 transition-colors">{u.first_name} {u.last_name}</p>
                      <p className="text-xs text-gray-400 capitalize">{u.role?.replace('_',' ')} {u.school && `· ${u.school.name}`}</p>
                    </div>
                    {u.is_online && <div className="w-2.5 h-2.5 bg-green-400 rounded-full flex-shrink-0"/>}
                    <ChevronRight size={14} className="text-gray-300 group-hover:text-brand-500"/>
                  </Link>
                ))}
              </Section>
            )}

            {/* Classes */}
            {results.classes?.length > 0 && (
              <Section title="Classes" icon={Hash}>
                {results.classes.map((c) => (
                  <Link key={c.id} to={`/classes/${c.id}`}
                    className="flex items-center gap-3 p-3 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700 group transition-all">
                    <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 text-white font-bold text-sm"
                      style={{ background: `linear-gradient(135deg,${c.color||'#7C3AED'},${c.color||'#7C3AED'}99)` }}>
                      {c.name?.[0]}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-gray-900 dark:text-white group-hover:text-brand-600 transition-colors">{c.name}</p>
                      <p className="text-xs text-gray-400">{c.teacher?.full_name} · {c.enrollments_count || 0} students</p>
                    </div>
                    <ChevronRight size={14} className="text-gray-300 group-hover:text-brand-500"/>
                  </Link>
                ))}
              </Section>
            )}

            {/* Lessons */}
            {results.lessons?.length > 0 && (
              <Section title="Lessons" icon={BookOpen}>
                {results.lessons.map((l) => (
                  <Link key={l.id} to={`/classes/${l.class_id}/lessons/${l.id}`}
                    className="flex items-center gap-3 p-3 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700 group transition-all">
                    <div className="w-10 h-10 rounded-xl bg-brand-100 dark:bg-brand-900/30 flex items-center justify-center flex-shrink-0">
                      <BookOpen size={18} className="text-brand-600"/>
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-gray-900 dark:text-white group-hover:text-brand-600 transition-colors">{l.title}</p>
                      <p className="text-xs text-gray-400">{l.class_name}</p>
                    </div>
                    <ChevronRight size={14} className="text-gray-300 group-hover:text-brand-500"/>
                  </Link>
                ))}
              </Section>
            )}

            {/* Assignments */}
            {results.assignments?.length > 0 && (
              <Section title="Assignments" icon={FileText}>
                {results.assignments.map((a) => (
                  <Link key={a.id} to={`/classes/${a.class_id}/assignments/${a.id}`}
                    className="flex items-center gap-3 p-3 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700 group transition-all">
                    <div className="w-10 h-10 rounded-xl bg-orange-100 dark:bg-orange-900/30 flex items-center justify-center flex-shrink-0">
                      <FileText size={18} className="text-orange-500"/>
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-gray-900 dark:text-white group-hover:text-brand-600 transition-colors">{a.title}</p>
                      <p className="text-xs text-gray-400">
                        {a.class_name} {a.due_date && `· Due ${format(new Date(a.due_date),'MMM d')}`}
                      </p>
                    </div>
                    <ChevronRight size={14} className="text-gray-300 group-hover:text-brand-500"/>
                  </Link>
                ))}
              </Section>
            )}

            {/* Quizzes */}
            {results.quizzes?.length > 0 && (
              <Section title="Quizzes" icon={Brain}>
                {results.quizzes.map((q) => (
                  <Link key={q.id} to={`/classes/${q.class_id}/quizzes/${q.id}/take`}
                    className="flex items-center gap-3 p-3 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700 group transition-all">
                    <div className="w-10 h-10 rounded-xl bg-green-100 dark:bg-green-900/30 flex items-center justify-center flex-shrink-0">
                      <Brain size={18} className="text-green-600"/>
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-gray-900 dark:text-white group-hover:text-brand-600 transition-colors">{q.title}</p>
                      <p className="text-xs text-gray-400">{q.class_name} · {q.questions_count} questions</p>
                    </div>
                    <ChevronRight size={14} className="text-gray-300 group-hover:text-brand-500"/>
                  </Link>
                ))}
              </Section>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

function Section({ title, icon: Icon, children }) {
  return (
    <div>
      <h3 className="flex items-center gap-2 text-xs font-semibold text-gray-400 uppercase tracking-wide mb-2">
        <Icon size={13}/> {title}
      </h3>
      <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-card divide-y divide-gray-50 dark:divide-gray-700 overflow-hidden">
        {children}
      </div>
    </div>
  );
}
