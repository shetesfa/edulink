/**
 * EduLink — Quiz Result Page
 * ─────────────────────────────────────────────────────────────
 * Shows: score, percentage, time taken, SUBMITTED TIME,
 *        per-question breakdown, correct answers (if allowed),
 *        and teacher's all-student results view.
 */

import React, { useEffect, useState } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import {
  CheckCircle2, XCircle, Clock, Award, BarChart2,
  ChevronLeft, Calendar, Timer, Users, TrendingUp,
  Loader2, RefreshCw,
} from 'lucide-react';
import { quizAPI } from '@/utils/api';
import { useAuthStore } from '@/store';
import clsx from 'clsx';
import { format, formatDuration, intervalToDuration } from 'date-fns';

export default function QuizResult() {
  const { classId, quizId } = useParams();
  const { user } = useAuthStore();
  const navigate = useNavigate();

  const isTeacher = user?.role === 'teacher';


  const [loading, setLoading] = useState(true);
  const [result, setResult]   = useState(null);   // for students: my attempt
  const [analytics, setAnalytics] = useState(null); // for teachers: all results
  const [attempts, setAttempts]   = useState([]);   // teacher: per-student list
  const [tab, setTab] = useState('summary');  // 'summary' | 'questions' | 'students'

  useEffect(() => {
    const load = async () => {
      try {
        if (isTeacher) {
          const [analyticsRes, attemptsRes] = await Promise.all([
            quizAPI.analytics(classId, quizId),
            quizAPI.attempts(classId, quizId),
          ]);
          setAnalytics(analyticsRes.data);
          setAttempts(attemptsRes.data.attempts || []);
        } else {
          // Student: fetch their latest attempt
          const { data } = await quizAPI.attempts(classId, quizId);
          const myAttempt = (data.attempts || []).find((a) => a.student_id === user.id)
            || data.attempt
            || data.my_attempt;
          setResult(myAttempt);
        }
      } catch (err) {
        console.error('Failed to load quiz results', err);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [classId, quizId, isTeacher]);

  if (loading) return (
    <div className="flex items-center justify-center h-64">
      <Loader2 size={32} className="animate-spin text-brand-500" />
    </div>
  );

  // ── TEACHER VIEW ─────────────────────────────────────────────
  if (isTeacher) {
    const stats = analytics?.stats || {};
    return (
      <div className="max-w-5xl mx-auto p-4 sm:p-6 space-y-6">
        {/* Back */}
        <Link to={`/classes/${classId}`} className="inline-flex items-center gap-1.5 text-sm text-gray-500 hover:text-brand-600 transition-colors">
          <ChevronLeft size={16} /> Back to class
        </Link>

        {/* Header */}
        <div className="bg-brand-gradient-dark rounded-2xl p-6 text-white">
          <h1 className="font-display font-bold text-2xl mb-1">{analytics?.quiz?.title || 'Quiz Results'}</h1>
          <p className="text-brand-200 text-sm">{analytics?.quiz?.class_name}</p>
        </div>

        {/* Summary stats */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          {[
            { label: 'Submissions',  value: stats.total_attempts || 0,                   icon: Users,      color: 'blue' },
            { label: 'Avg Score',    value: `${Math.round(stats.avg_percentage || 0)}%`, icon: TrendingUp, color: 'violet' },
            { label: 'Pass Rate',    value: `${Math.round(stats.pass_rate || 0)}%`,      icon: Award,      color: 'green' },
            { label: 'Avg Time',     value: formatSeconds(stats.avg_time_seconds || 0),  icon: Timer,      color: 'amber' },
          ].map((s) => (
            <div key={s.label} className="bg-white dark:bg-gray-800 rounded-2xl p-4 border border-gray-100 dark:border-gray-700 shadow-card">
              <div className={clsx('w-9 h-9 rounded-xl flex items-center justify-center mb-3',
                s.color === 'blue'   && 'bg-blue-100 dark:bg-blue-900/30',
                s.color === 'violet' && 'bg-brand-100 dark:bg-brand-900/30',
                s.color === 'green'  && 'bg-green-100 dark:bg-green-900/30',
                s.color === 'amber'  && 'bg-amber-100 dark:bg-amber-900/30',
              )}>
                <s.icon size={18} className={clsx(
                  s.color === 'blue'   && 'text-blue-600',
                  s.color === 'violet' && 'text-brand-600',
                  s.color === 'green'  && 'text-green-600',
                  s.color === 'amber'  && 'text-amber-600',
                )} />
              </div>
              <p className="font-bold text-xl text-gray-900 dark:text-white">{s.value}</p>
              <p className="text-xs text-gray-400">{s.label}</p>
            </div>
          ))}
        </div>

        {/* Tabs */}
        <div className="flex gap-1 bg-gray-100 dark:bg-gray-700 rounded-xl p-1 w-fit">
          {['summary', 'questions', 'students'].map((t) => (
            <button key={t} onClick={() => setTab(t)}
              className={clsx('px-4 py-1.5 rounded-lg text-sm font-medium transition-all capitalize',
                tab === t ? 'bg-white dark:bg-gray-600 shadow text-gray-900 dark:text-white' : 'text-gray-500 hover:text-gray-700 dark:hover:text-gray-300')}>
              {t}
            </button>
          ))}
        </div>

        {/* Per-question breakdown */}
        {tab === 'questions' && (
          <div className="space-y-3">
            {(analytics?.questions || []).map((q, i) => {
              const correctPct = Math.round((q.correct_count / Math.max(q.total_answers, 1)) * 100);
              return (
                <div key={q.id} className="bg-white dark:bg-gray-800 rounded-2xl p-5 border border-gray-100 dark:border-gray-700">
                  <div className="flex items-start justify-between gap-3 mb-3">
                    <div className="flex items-start gap-3 flex-1">
                      <span className="w-6 h-6 rounded-full bg-gray-100 dark:bg-gray-700 text-xs font-bold flex items-center justify-center text-gray-600 dark:text-gray-300 flex-shrink-0 mt-0.5">{i+1}</span>
                      <p className="text-sm text-gray-800 dark:text-white font-medium">{q.question_text}</p>
                    </div>
                    <span className={clsx('text-xs font-bold px-2 py-1 rounded-full',
                      correctPct >= 70 ? 'bg-green-100 text-green-700' : correctPct >= 40 ? 'bg-amber-100 text-amber-700' : 'bg-red-100 text-red-700')}>
                      {correctPct}% correct
                    </span>
                  </div>
                  <div className="h-2 bg-gray-100 dark:bg-gray-700 rounded-full overflow-hidden">
                    <div className={clsx('h-full rounded-full transition-all',
                      correctPct >= 70 ? 'bg-green-500' : correctPct >= 40 ? 'bg-amber-500' : 'bg-red-500')}
                      style={{ width: `${correctPct}%` }} />
                  </div>
                  <p className="text-xs text-gray-400 mt-1.5">{q.correct_count} / {q.total_answers} students answered correctly</p>
                  {q.correct_answer && (
                    <p className="text-xs text-green-600 dark:text-green-400 mt-1">✓ Correct answer: <span className="font-semibold">{q.correct_answer}</span></p>
                  )}
                </div>
              );
            })}
          </div>
        )}

        {/* Per-student list */}
        {tab === 'students' && (
          <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 overflow-hidden">
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-gray-50 dark:bg-gray-700/50 border-b border-gray-100 dark:border-gray-700">
                  <th className="text-left py-3 px-4 font-semibold text-gray-600 dark:text-gray-300">Student</th>
                  <th className="text-center py-3 px-4 font-semibold text-gray-600 dark:text-gray-300">Score</th>
                  <th className="text-center py-3 px-4 font-semibold text-gray-600 dark:text-gray-300">Submitted At</th>
                  <th className="text-center py-3 px-4 font-semibold text-gray-600 dark:text-gray-300">Time Taken</th>
                  <th className="text-center py-3 px-4 font-semibold text-gray-600 dark:text-gray-300">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
                {attempts.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="text-center py-10 text-gray-400">No submissions yet</td>
                  </tr>
                ) : (
                  attempts.map((attempt) => (
                    <tr key={attempt.id} className="hover:bg-gray-50 dark:hover:bg-gray-700/30 transition-colors">
                      <td className="py-3 px-4">
                        <div className="flex items-center gap-2.5">
                          <div className="w-8 h-8 rounded-full bg-brand-100 dark:bg-brand-900/30 flex items-center justify-center text-brand-600 font-bold text-xs">
                            {(attempt.student_name || '?')[0]?.toUpperCase()}
                          </div>
                          <div>
                            <p className="font-medium text-gray-800 dark:text-white">{attempt.student_name}</p>
                            <p className="text-xs text-gray-400">{attempt.student_email}</p>
                          </div>
                        </div>
                      </td>
                      <td className="py-3 px-4 text-center">
                        <span className={clsx('font-bold', attempt.passed ? 'text-green-600' : 'text-red-500')}>
                          {Math.round(attempt.percentage || 0)}%
                        </span>
                        <p className="text-xs text-gray-400">{attempt.score}/{attempt.max_score} pts</p>
                      </td>
                      <td className="py-3 px-4 text-center">
                        {attempt.submitted_at ? (
                          <div>
                            <p className="text-gray-700 dark:text-gray-200 font-medium">
                              {format(new Date(attempt.submitted_at), 'MMM d, yyyy')}
                            </p>
                            <p className="text-xs text-gray-400">
                              {format(new Date(attempt.submitted_at), 'h:mm a')}
                            </p>
                          </div>
                        ) : (
                          <span className="text-gray-400">—</span>
                        )}
                      </td>
                      <td className="py-3 px-4 text-center text-gray-600 dark:text-gray-300">
                        {attempt.time_taken_seconds ? formatSeconds(attempt.time_taken_seconds) : '—'}
                      </td>
                      <td className="py-3 px-4 text-center">
                        <span className={clsx('px-2.5 py-1 rounded-full text-xs font-bold',
                          attempt.passed
                            ? 'bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400'
                            : 'bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400')}>
                          {attempt.passed ? 'Passed' : 'Failed'}
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>
    );
  }

  // ── STUDENT VIEW ─────────────────────────────────────────────
  if (!result) return (
    <div className="max-w-xl mx-auto p-6 text-center">
      <div className="text-5xl mb-4">📝</div>
      <h2 className="font-bold text-xl text-gray-900 dark:text-white mb-2">No result found</h2>
      <p className="text-gray-400 mb-6">You haven't submitted this quiz yet.</p>
      <Link to={`/classes/${classId}/quizzes/${quizId}/take`}
        className="inline-flex items-center gap-2 px-5 py-2.5 bg-brand-600 text-white rounded-xl font-semibold hover:bg-brand-700 transition-all">
        Take Quiz
      </Link>
    </div>
  );

  const pct     = Math.round(result.percentage || 0);
  const passed  = result.passed;
  const answers = result.answers || [];

  return (
    <div className="max-w-2xl mx-auto p-4 sm:p-6 space-y-6">
      {/* Back */}
      <Link to={`/classes/${classId}`} className="inline-flex items-center gap-1.5 text-sm text-gray-500 hover:text-brand-600 transition-colors">
        <ChevronLeft size={16} /> Back to class
      </Link>

      {/* Result card */}
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }}
        className={clsx(
          'rounded-3xl p-8 text-center text-white shadow-xl',
          passed ? 'bg-gradient-to-br from-green-500 to-emerald-600' : 'bg-gradient-to-br from-red-500 to-rose-600'
        )}
      >
        <div className="text-6xl mb-3">{passed ? '🎉' : '😔'}</div>
        <h1 className="font-display font-bold text-3xl mb-1">
          {passed ? 'Well done!' : 'Keep practicing'}
        </h1>
        <p className="text-white/80 mb-6">{passed ? 'You passed this quiz!' : "You didn't pass this time — you can do better!"}</p>

        {/* Score ring */}
        <div className="relative w-36 h-36 mx-auto mb-6">
          <svg className="w-full h-full -rotate-90" viewBox="0 0 36 36">
            <circle cx="18" cy="18" r="15.9" fill="none" stroke="rgba(255,255,255,0.2)" strokeWidth="3" />
            <circle cx="18" cy="18" r="15.9" fill="none" stroke="white" strokeWidth="3"
              strokeDasharray={`${pct} ${100 - pct}`} strokeLinecap="round" />
          </svg>
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <span className="font-display font-black text-4xl">{pct}%</span>
            <span className="text-white/70 text-xs">{result.score}/{result.max_score} pts</span>
          </div>
        </div>

        {/* Meta info */}
        <div className="flex items-center justify-center gap-6 text-sm text-white/80">
          {result.submitted_at && (
            <div className="flex items-center gap-1.5">
              <Calendar size={14} />
              <span>{format(new Date(result.submitted_at), 'MMM d, yyyy h:mm a')}</span>
            </div>
          )}
          {result.time_taken_seconds && (
            <div className="flex items-center gap-1.5">
              <Timer size={14} />
              <span>{formatSeconds(result.time_taken_seconds)}</span>
            </div>
          )}
        </div>
      </motion.div>

      {/* Per-question breakdown */}
      {answers.length > 0 && (
        <div className="space-y-4">
          <h2 className="font-display font-semibold text-gray-900 dark:text-white text-lg">Question Review</h2>
          {answers.map((a, i) => {
            const isCorrect = a.is_correct;
            return (
              <motion.div
                key={i}
                initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }}
                transition={{ delay: i * 0.05 }}
                className={clsx(
                  'rounded-2xl p-5 border-2 transition-all',
                  isCorrect
                    ? 'border-green-200 dark:border-green-800 bg-green-50/50 dark:bg-green-900/10'
                    : 'border-red-200 dark:border-red-800 bg-red-50/50 dark:bg-red-900/10'
                )}
              >
                <div className="flex items-start gap-3">
                  <div className="flex-shrink-0 mt-0.5">
                    {isCorrect
                      ? <CheckCircle2 size={20} className="text-green-500" />
                      : <XCircle size={20} className="text-red-500" />}
                  </div>
                  <div className="flex-1">
                    <p className="font-medium text-gray-800 dark:text-white text-sm mb-3">
                      <span className="text-gray-400 mr-1">Q{i+1}.</span> {a.question_text}
                    </p>

                    <div className="space-y-1.5">
                      {/* Student's answer */}
                      <div className={clsx('flex items-center gap-2 px-3 py-2 rounded-xl text-sm',
                        isCorrect ? 'bg-green-100 dark:bg-green-900/30' : 'bg-red-100 dark:bg-red-900/30')}>
                        {isCorrect ? <CheckCircle2 size={13} className="text-green-600 flex-shrink-0" /> : <XCircle size={13} className="text-red-500 flex-shrink-0" />}
                        <span className={clsx('font-medium', isCorrect ? 'text-green-700 dark:text-green-300' : 'text-red-700 dark:text-red-300')}>
                          Your answer: {a.selected_answer || 'No answer'}
                        </span>
                      </div>

                      {/* Correct answer (if show_answers_after is enabled) */}
                      {a.correct_answer && (
                        <div className="flex items-center gap-2 px-3 py-2 rounded-xl text-sm bg-green-100 dark:bg-green-900/30">
                          <CheckCircle2 size={13} className="text-green-600 flex-shrink-0" />
                          <span className="font-medium text-green-700 dark:text-green-300">
                            Correct answer: {a.correct_answer}
                          </span>
                        </div>
                      )}

                      {/* Explanation */}
                      {a.explanation && (
                        <p className="text-xs text-gray-500 dark:text-gray-400 px-1 mt-2 italic">{a.explanation}</p>
                      )}
                    </div>
                  </div>
                </div>
              </motion.div>
            );
          })}
        </div>
      )}

      {/* Actions */}
      <div className="flex gap-3">
        <Link to={`/classes/${classId}`}
          className="flex-1 flex items-center justify-center gap-2 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl text-sm font-semibold text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 transition-all">
          <ChevronLeft size={15} /> Back to Class
        </Link>
        {!passed && (
          <Link to={`/classes/${classId}/quizzes/${quizId}/take`}
            className="flex-1 flex items-center justify-center gap-2 py-2.5 bg-brand-600 text-white rounded-xl text-sm font-semibold hover:bg-brand-700 transition-all shadow-md">
            <RefreshCw size={15} /> Try Again
          </Link>
        )}
      </div>
    </div>
  );
}

// ─── Helpers ───────────────────────────────────────────────────
function formatSeconds(secs) {
  if (!secs) return '—';
  const m = Math.floor(secs / 60);
  const s = secs % 60;
  if (m === 0) return `${s}s`;
  return `${m}m ${s}s`;
}
