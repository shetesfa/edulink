import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import {
  Users, BookOpen, FileText, Brain, TrendingUp,
  Plus, ChevronRight, Award, Clock, CheckCircle2,
  BarChart2, Bell, Megaphone, Video,
} from 'lucide-react';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, LineChart, Line, Legend,
} from 'recharts';
import { progressAPI, classAPI } from '@/utils/api';
import { useAuthStore } from '@/store';
import { format } from 'date-fns';
import clsx from 'clsx';

export default function TeacherDashboard() {
  const { user } = useAuthStore();
  const [data, setData]       = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    progressAPI.dashboard().then(({ data: d }) => setData(d)).finally(() => setLoading(false));
  }, []);

  if (loading) return <Skeleton />;

  const stats     = data?.stats || {};
  const classes   = data?.classes || [];
  const pending   = data?.pending_submissions || [];
  const quizStats = data?.quiz_stats || [];
  const activity  = data?.student_activity || sampleActivity();

  return (
    <div className="p-4 sm:p-6 space-y-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white">
            Teacher Dashboard
          </h1>
          <p className="text-gray-400 text-sm mt-0.5">
            {format(new Date(), 'EEEE, MMMM d, yyyy')} · Welcome back, {user?.first_name}
          </p>
        </div>
        <div className="flex gap-2">
          <Link
            to="/classes"
            className="flex items-center gap-2 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white rounded-xl text-sm font-semibold transition-all"
          >
            <Plus size={15} /> New Class
          </Link>
          <Link
            to="/meetings"
            className="flex items-center gap-2 px-4 py-2 border border-gray-200 dark:border-gray-600 text-gray-600 dark:text-gray-300 rounded-xl text-sm font-semibold hover:bg-gray-50 dark:hover:bg-gray-700 transition-all"
          >
            <Video size={15} /> Start Meeting
          </Link>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[
          { label: 'My Classes',       value: stats.total_classes || 0,   icon: BookOpen,    color: 'violet', sub: 'Active classes' },
          { label: 'Total Students',   value: stats.total_students || 0,  icon: Users,       color: 'blue',   sub: 'Enrolled students' },
          { label: 'Pending Grades',   value: stats.pending_grades || 0,  icon: Clock,       color: 'amber',  sub: 'Need grading' },
          { label: 'Avg Quiz Score',   value: `${stats.avg_quiz || 0}%`,  icon: Award,       color: 'green',  sub: 'Class average' },
        ].map((s, i) => (
          <motion.div
            key={s.label}
            initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.08 }}
            className="bg-white dark:bg-gray-800 rounded-2xl p-4 border border-gray-100 dark:border-gray-700 shadow-card hover:shadow-card-hover transition-all"
          >
            <div className={clsx(
              'w-10 h-10 rounded-xl flex items-center justify-center mb-3',
              s.color === 'violet' && 'bg-brand-100 dark:bg-brand-900/30',
              s.color === 'blue'   && 'bg-blue-100 dark:bg-blue-900/30',
              s.color === 'amber'  && 'bg-amber-100 dark:bg-amber-900/30',
              s.color === 'green'  && 'bg-green-100 dark:bg-green-900/30',
            )}>
              <s.icon size={20} className={clsx(
                s.color === 'violet' && 'text-brand-600',
                s.color === 'blue'   && 'text-blue-600',
                s.color === 'amber'  && 'text-amber-600',
                s.color === 'green'  && 'text-green-600',
              )} />
            </div>
            <p className="font-display font-bold text-2xl text-gray-900 dark:text-white">{s.value}</p>
            <p className="text-xs text-gray-400 mt-0.5">{s.label}</p>
          </motion.div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Student activity chart */}
        <div className="lg:col-span-2 bg-white dark:bg-gray-800 rounded-2xl p-5 border border-gray-100 dark:border-gray-700 shadow-card">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-display font-semibold text-gray-900 dark:text-white">Student Activity</h3>
            <span className="text-xs text-gray-400">Last 7 days</span>
          </div>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={activity} barSize={20}>
              <CartesianGrid strokeDasharray="3 3" stroke="#F0EDFF" vertical={false} />
              <XAxis dataKey="day" tick={{ fontSize: 11, fill: '#94A3B8' }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fontSize: 11, fill: '#94A3B8' }} axisLine={false} tickLine={false} />
              <Tooltip
                contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 24px rgba(0,0,0,0.1)', fontSize: '12px' }}
                cursor={{ fill: 'rgba(124,58,237,0.05)' }}
              />
              <Legend wrapperStyle={{ fontSize: '11px' }} />
              <Bar dataKey="submissions" name="Submissions" fill="#7C3AED" radius={[6,6,0,0]} />
              <Bar dataKey="logins"      name="Logins"      fill="#F59E0B" radius={[6,6,0,0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Pending submissions */}
        <div className="bg-white dark:bg-gray-800 rounded-2xl p-5 border border-gray-100 dark:border-gray-700 shadow-card">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-display font-semibold text-gray-900 dark:text-white">Needs Grading</h3>
            {pending.length > 0 && (
              <span className="text-xs bg-red-100 text-red-600 font-semibold px-2 py-0.5 rounded-full">{pending.length}</span>
            )}
          </div>
          <div className="space-y-2">
            {pending.length === 0 ? (
              <div className="text-center py-6">
                <CheckCircle2 size={28} className="text-green-400 mx-auto mb-2" />
                <p className="text-sm text-gray-400">All caught up! 🎉</p>
              </div>
            ) : (
              pending.slice(0, 5).map((s) => (
                <Link
                  key={s.id}
                  to={`/classes/${s.class_id}/assignments/${s.assignment_id}`}
                  className="flex items-center gap-3 p-2.5 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700 group transition-all"
                >
                  <div className="w-8 h-8 rounded-lg bg-orange-50 dark:bg-orange-900/20 flex items-center justify-center flex-shrink-0">
                    <FileText size={14} className="text-orange-500" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-800 dark:text-white truncate">{s.student_name}</p>
                    <p className="text-xs text-gray-400 truncate">{s.assignment_title}</p>
                  </div>
                  <ChevronRight size={14} className="text-gray-300 group-hover:text-brand-500" />
                </Link>
              ))
            )}
          </div>
        </div>
      </div>

      {/* My Classes */}
      <div className="bg-white dark:bg-gray-800 rounded-2xl p-5 border border-gray-100 dark:border-gray-700 shadow-card">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-display font-semibold text-gray-900 dark:text-white">My Classes</h3>
          <Link to="/classes" className="text-xs text-brand-600 hover:text-brand-700 font-medium">Manage all →</Link>
        </div>
        {classes.length === 0 ? (
          <div className="text-center py-10">
            <BookOpen size={36} className="text-gray-200 dark:text-gray-600 mx-auto mb-3" />
            <p className="text-gray-400 mb-3">No classes yet. Create your first class!</p>
            <Link to="/classes" className="inline-flex items-center gap-2 px-4 py-2 bg-brand-600 text-white rounded-xl text-sm font-semibold hover:bg-brand-700 transition-all">
              <Plus size={15} /> Create Class
            </Link>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {classes.map((cls) => (
              <Link
                key={cls.id}
                to={`/classes/${cls.id}`}
                className="group relative block rounded-xl border border-gray-100 dark:border-gray-700 overflow-hidden hover:shadow-card-hover transition-all"
              >
                <div className="h-2" style={{ background: cls.color || '#7C3AED' }} />
                <div className="p-4">
                  <h4 className="font-semibold text-gray-900 dark:text-white group-hover:text-brand-600 transition-colors">{cls.name}</h4>
                  <p className="text-xs text-gray-400 mb-3">{cls.grade?.name || cls.subject}</p>
                  <div className="flex items-center justify-between text-xs text-gray-500">
                    <span className="flex items-center gap-1"><Users size={12} /> {cls.enrollments_count || 0} students</span>
                    <span className="flex items-center gap-1"><BookOpen size={12} /> {cls.lessons_count || 0} lessons</span>
                  </div>
                  <div className="mt-3 flex items-center gap-2">
                    <span className="px-2 py-0.5 bg-gray-100 dark:bg-gray-700 rounded-full text-[10px] font-mono text-gray-500">{cls.join_code}</span>
                    <ChevronRight size={12} className="ml-auto text-gray-300 group-hover:text-brand-500" />
                  </div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>

      {/* Quick actions */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        {[
          { to: '/classes',  icon: BookOpen,   label: 'Upload Lesson',    color: 'violet' },
          { to: '/classes',  icon: FileText,   label: 'Create Assignment', color: 'blue' },
          { to: '/classes',  icon: Brain,      label: 'Create Quiz',      color: 'green' },
          { to: '/chat',     icon: Megaphone,  label: 'Announcement',     color: 'amber' },
        ].map((a) => (
          <Link
            key={a.label}
            to={a.to}
            className="flex flex-col items-center gap-2 p-4 bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-card hover:shadow-card-hover hover:border-brand-200 transition-all group"
          >
            <div className={clsx(
              'w-10 h-10 rounded-xl flex items-center justify-center',
              a.color === 'violet' && 'bg-brand-100 dark:bg-brand-900/30 group-hover:bg-brand-600',
              a.color === 'blue'   && 'bg-blue-100 dark:bg-blue-900/30 group-hover:bg-blue-600',
              a.color === 'green'  && 'bg-green-100 dark:bg-green-900/30 group-hover:bg-green-600',
              a.color === 'amber'  && 'bg-amber-100 dark:bg-amber-900/30 group-hover:bg-amber-500',
              'transition-all'
            )}>
              <a.icon size={18} className={clsx(
                a.color === 'violet' && 'text-brand-600 group-hover:text-white',
                a.color === 'blue'   && 'text-blue-600 group-hover:text-white',
                a.color === 'green'  && 'text-green-600 group-hover:text-white',
                a.color === 'amber'  && 'text-amber-600 group-hover:text-white',
                'transition-colors'
              )} />
            </div>
            <span className="text-xs font-medium text-gray-600 dark:text-gray-300 text-center">{a.label}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}

function Skeleton() {
  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto animate-pulse">
      <div className="h-8 bg-gray-200 dark:bg-gray-700 rounded-xl w-56" />
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[...Array(4)].map((_, i) => <div key={i} className="h-28 bg-gray-200 dark:bg-gray-700 rounded-2xl" />)}
      </div>
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 h-64 bg-gray-200 dark:bg-gray-700 rounded-2xl" />
        <div className="h-64 bg-gray-200 dark:bg-gray-700 rounded-2xl" />
      </div>
    </div>
  );
}

function sampleActivity() {
  return ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].map((day) => ({
    day,
    submissions: Math.floor(Math.random() * 15 + 2),
    logins:      Math.floor(Math.random() * 25 + 5),
  }));
}
