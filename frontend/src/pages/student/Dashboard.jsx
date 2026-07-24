import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { BookOpen, Clock, CheckCircle2, TrendingUp, Bell, Bot, ChevronRight, Play, FileText, Award } from 'lucide-react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, RadialBarChart, RadialBar } from 'recharts';
import { progressAPI, notificationAPI } from '@/utils/api';
import { useAuthStore } from '@/store';
import clsx from 'clsx';
import { format } from 'date-fns';

export default function StudentDashboard() {
  const { user } = useAuthStore();
  const [data, setData]         = useState(null);
  const [loading, setLoading]   = useState(true);

  useEffect(() => {
    progressAPI.dashboard().then(({ data: d }) => setData(d)).finally(() => setLoading(false));
  }, []);

  if (loading) return <DashboardSkeleton />;

  const stats = data?.stats || {};
  const activityData = data?.activity || [];
  const upcomingAssignments = data?.upcoming_assignments || [];
  const recentLessons = data?.recent_lessons || [];
  const notifications = data?.notifications || [];
  const pinnedItems = data?.pinned_items || [];

  return (
    <div className="p-4 sm:p-6 space-y-6 max-w-7xl mx-auto">
      {/* Welcome */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white">
            Good {getTimeOfDay()}, {user?.first_name}! 👋
          </h1>
          <p className="text-gray-500 text-sm mt-0.5">{format(new Date(), 'EEEE, MMMM d, yyyy')}</p>
        </div>
        <Link
          to="/ai"
          className="hidden sm:flex items-center gap-2 px-4 py-2 bg-brand-gradient text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md"
        >
          <Bot size={16} /> Ask AI
        </Link>
      </div>

      {/* Stat cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[
          { label: 'Classes Joined',   value: stats.classes || 0,     icon: BookOpen,     color: 'violet' },
          { label: 'Lessons Viewed',   value: stats.lessons || 0,     icon: Play,         color: 'blue' },
          { label: 'Assignments Done', value: stats.assignments || 0, icon: CheckCircle2, color: 'green' },
          { label: 'Quiz Average',     value: `${stats.avg_quiz || 0}%`, icon: Award,     color: 'amber' },
        ].map((s, i) => (
          <motion.div
            key={s.label}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.08 }}
            className="bg-white dark:bg-gray-800 rounded-2xl p-4 border border-gray-100 dark:border-gray-700 shadow-card hover:shadow-card-hover transition-all"
          >
            <div className={clsx(
              'w-10 h-10 rounded-xl flex items-center justify-center mb-3',
              s.color === 'violet' && 'bg-brand-100 dark:bg-brand-900/30',
              s.color === 'blue'   && 'bg-blue-100 dark:bg-blue-900/30',
              s.color === 'green'  && 'bg-green-100 dark:bg-green-900/30',
              s.color === 'amber'  && 'bg-amber-100 dark:bg-amber-900/30',
            )}>
              <s.icon size={20} className={clsx(
                s.color === 'violet' && 'text-brand-600',
                s.color === 'blue'   && 'text-blue-600',
                s.color === 'green'  && 'text-green-600',
                s.color === 'amber'  && 'text-amber-600',
              )} />
            </div>
            <p className="font-display font-bold text-2xl text-gray-900 dark:text-white">{s.value}</p>
            <p className="text-xs text-gray-400 mt-0.5">{s.label}</p>
          </motion.div>
        ))}
      </div>

      {/* Pinned Notice Board */}
      {pinnedItems.length > 0 && (
        <div className="bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-100 dark:border-gray-700 shadow-card relative overflow-hidden">
          <div className="absolute top-0 right-0 w-24 h-24 bg-brand-500/5 rounded-full blur-2xl pointer-events-none" />
          <div className="flex items-center gap-2 mb-5">
            <span className="text-xl animate-bounce">📌</span>
            <div>
              <h3 className="font-display font-semibold text-gray-900 dark:text-white text-lg">Notice Board & Pinned Items</h3>
              <p className="text-xs text-gray-400 dark:text-gray-500">Important notices pinned by your teachers</p>
            </div>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {pinnedItems.map((item, idx) => (
              <motion.div
                key={`${item.type}-${item.id}`}
                initial={{ opacity: 0, y: 15 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: idx * 0.05 }}
                className={clsx(
                  "p-4 rounded-xl border relative overflow-hidden transition-all hover:-translate-y-1 hover:shadow-md duration-200",
                  item.type === 'announcement' && "bg-amber-50/40 border-amber-200/60 dark:bg-amber-950/10 dark:border-amber-900/40",
                  item.type === 'assignment' && "bg-rose-50/40 border-rose-200/60 dark:bg-rose-950/10 dark:border-rose-900/40",
                  item.type === 'quiz' && "bg-indigo-50/40 border-indigo-200/60 dark:bg-indigo-950/10 dark:border-indigo-900/40"
                )}
              >
                {/* Header info */}
                <div className="flex items-center justify-between mb-2 gap-2">
                  <span className={clsx(
                    "text-[10px] font-bold px-2 py-0.5 rounded-md uppercase tracking-wider",
                    item.type === 'announcement' && "bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300",
                    item.type === 'assignment' && "bg-rose-100 text-rose-800 dark:bg-rose-900/40 dark:text-rose-300",
                    item.type === 'quiz' && "bg-indigo-100 text-indigo-800 dark:bg-indigo-900/40 dark:text-indigo-300"
                  )}>
                    {item.type}
                  </span>
                  <span className="text-[11px] font-medium text-gray-400 dark:text-gray-500 truncate max-w-[120px]">
                    {item.class_name}
                  </span>
                </div>

                {/* Title */}
                <h4 className="font-semibold text-sm text-gray-900 dark:text-white mb-1.5 line-clamp-1 group-hover:text-brand-600">
                  {item.title}
                </h4>

                {/* Body details */}
                {item.type === 'announcement' && item.body ? (
                  <p className="text-xs text-gray-500 dark:text-gray-400 line-clamp-2 leading-relaxed mb-1">
                    {item.body}
                  </p>
                ) : null}

                {/* Footer details */}
                <div className="flex items-center justify-between mt-3 pt-2.5 border-t border-gray-100 dark:border-gray-700/50 text-[11px] text-gray-400 dark:text-gray-500">
                  <span className="truncate max-w-[120px]">By {item.teacher_name}</span>
                  {item.type === 'assignment' && item.due_date && (
                    <span className="font-semibold text-rose-600 dark:text-rose-400">
                      Due {format(new Date(item.due_date), 'MMM d')}
                    </span>
                  )}
                  {item.type === 'announcement' && item.created_at && (
                    <span>
                      {format(new Date(item.created_at), 'MMM d')}
                    </span>
                  )}
                </div>

                {/* Link overlay */}
                {item.type === 'assignment' && (
                  <Link to={`/classes/${item.class_id}/assignments/${item.id}`} className="absolute inset-0 z-10" />
                )}
                {item.type === 'quiz' && (
                  <Link to={`/classes/${item.class_id}/quizzes/${item.id}/result`} className="absolute inset-0 z-10" />
                )}
              </motion.div>
            ))}
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Activity chart */}
        <div className="lg:col-span-2 bg-white dark:bg-gray-800 rounded-2xl p-5 border border-gray-100 dark:border-gray-700 shadow-card">
          <h3 className="font-display font-semibold text-gray-900 dark:text-white mb-4">Learning Activity</h3>
          <ResponsiveContainer width="100%" height={180}>
            <AreaChart data={activityData.length > 0 ? activityData : sampleActivity()}>
              <defs>
                <linearGradient id="aGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%"  stopColor="#7C3AED" stopOpacity={0.2} />
                  <stop offset="95%" stopColor="#7C3AED" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#F0EDFF" />
              <XAxis dataKey="day" tick={{ fontSize: 11, fill: '#94A3B8' }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fontSize: 11, fill: '#94A3B8' }} axisLine={false} tickLine={false} />
              <Tooltip contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 24px rgba(0,0,0,0.1)', fontSize: '12px' }} />
              <Area type="monotone" dataKey="lessons" stroke="#7C3AED" strokeWidth={2} fill="url(#aGrad)" name="Lessons" />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        {/* Upcoming assignments */}
        <div className="bg-white dark:bg-gray-800 rounded-2xl p-5 border border-gray-100 dark:border-gray-700 shadow-card">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-display font-semibold text-gray-900 dark:text-white">Due Soon</h3>
            <Link to="/classes" className="text-xs text-brand-600 hover:text-brand-700 font-medium">View all</Link>
          </div>
          <div className="space-y-3">
            {upcomingAssignments.length === 0 ? (
              <p className="text-sm text-gray-400 text-center py-4">No upcoming assignments 🎉</p>
            ) : (
              upcomingAssignments.map((a) => (
                <Link
                  key={a.id}
                  to={`/classes/${a.class_id}/assignments/${a.id}`}
                  className="flex items-start gap-3 p-3 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700 transition-all group"
                >
                  <div className="w-8 h-8 rounded-lg bg-orange-100 dark:bg-orange-900/30 flex items-center justify-center flex-shrink-0">
                    <FileText size={14} className="text-orange-600" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-800 dark:text-white truncate">{a.title}</p>
                    <p className="text-xs text-gray-400">{a.class_name}</p>
                    <p className={clsx('text-xs font-medium mt-0.5', dueColor(a.due_date))}>
                      Due {format(new Date(a.due_date), 'MMM d')}
                    </p>
                  </div>
                  <ChevronRight size={14} className="text-gray-300 group-hover:text-brand-500 mt-1" />
                </Link>
              ))
            )}
          </div>
        </div>
      </div>

      {/* Recent lessons */}
      <div className="bg-white dark:bg-gray-800 rounded-2xl p-5 border border-gray-100 dark:border-gray-700 shadow-card">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-display font-semibold text-gray-900 dark:text-white">Continue Learning</h3>
          <Link to="/classes" className="text-xs text-brand-600 hover:text-brand-700 font-medium">All classes</Link>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {recentLessons.length === 0 ? (
            <div className="col-span-3 text-center py-8">
              <BookOpen size={32} className="text-gray-300 mx-auto mb-2" />
              <p className="text-sm text-gray-400">Join a class to start learning</p>
              <Link to="/classes" className="mt-3 inline-block text-sm text-brand-600 font-medium hover:text-brand-700">Browse classes →</Link>
            </div>
          ) : (
            recentLessons.map((l) => (
              <Link
                key={l.id}
                to={`/classes/${l.class_id}/lessons/${l.id}`}
                className="group block p-4 rounded-xl border border-gray-100 dark:border-gray-700 hover:border-brand-300 hover:shadow-card-hover transition-all"
              >
                <div className="flex items-center gap-2 mb-2">
                  <div className="w-8 h-8 rounded-lg flex items-center justify-center text-sm" style={{ background: l.class_color + '22' }}>
                    📖
                  </div>
                  <span className="text-xs text-gray-400 truncate">{l.class_name}</span>
                </div>
                <p className="font-medium text-sm text-gray-800 dark:text-white group-hover:text-brand-600 transition-colors line-clamp-2">{l.title}</p>
                <div className="flex items-center gap-2 mt-2">
                  <div className="flex-1 h-1.5 bg-gray-100 dark:bg-gray-700 rounded-full overflow-hidden">
                    <div className="h-full bg-brand-500 rounded-full" style={{ width: `${l.progress || 0}%` }} />
                  </div>
                  <span className="text-xs text-gray-400">{l.progress || 0}%</span>
                </div>
              </Link>
            ))
          )}
        </div>
      </div>
    </div>
  );
}

function DashboardSkeleton() {
  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto animate-pulse">
      <div className="h-8 bg-gray-200 dark:bg-gray-700 rounded-xl w-64" />
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[...Array(4)].map((_, i) => <div key={i} className="h-28 bg-gray-200 dark:bg-gray-700 rounded-2xl" />)}
      </div>
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 h-60 bg-gray-200 dark:bg-gray-700 rounded-2xl" />
        <div className="h-60 bg-gray-200 dark:bg-gray-700 rounded-2xl" />
      </div>
    </div>
  );
}

function getTimeOfDay() {
  const h = new Date().getHours();
  if (h < 12) return 'morning';
  if (h < 17) return 'afternoon';
  return 'evening';
}

function dueColor(dateStr) {
  const d    = new Date(dateStr);
  const diff = (d - new Date()) / (1000 * 60 * 60 * 24);
  if (diff < 1)  return 'text-red-500';
  if (diff < 3)  return 'text-orange-500';
  return 'text-gray-400';
}

function sampleActivity() {
  return ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].map((day) => ({
    day, lessons: Math.floor(Math.random() * 5),
  }));
}
