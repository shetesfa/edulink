import React, { useState, useEffect, useRef, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { Clock, ChevronLeft, ChevronRight, Send, AlertTriangle, CheckCircle2, Loader2 } from 'lucide-react';
import { quizAPI } from '@/utils/api';
import toast from 'react-hot-toast';
import clsx from 'clsx';

export default function QuizTake() {
  const { classId, quizId } = useParams();
  const navigate = useNavigate();

  const [quiz, setQuiz]         = useState(null);
  const [answers, setAnswers]   = useState({});
  const [current, setCurrent]   = useState(0);
  const [timeLeft, setTimeLeft] = useState(null);
  const [loading, setLoading]   = useState(true);
  const [submitting, setSub]    = useState(false);
  const [startedAt]             = useState(Date.now());
  const [showConfirm, setConf]  = useState(false);
  const timerRef                = useRef(null);

  useEffect(() => {
    quizAPI.take(classId, quizId)
      .then(({ data }) => {
        setQuiz(data.quiz);
        if (data.quiz.time_limit) setTimeLeft(data.quiz.time_limit * 60);
      })
      .catch(() => { toast.error('Unable to load quiz'); navigate(-1); })
      .finally(() => setLoading(false));
  }, [classId, quizId]);

  // Countdown timer
  useEffect(() => {
    if (timeLeft === null) return;
    if (timeLeft <= 0) { submitQuiz(true); return; }
    timerRef.current = setTimeout(() => setTimeLeft((t) => t - 1), 1000);
    return () => clearTimeout(timerRef.current);
  }, [timeLeft]);

  const submitQuiz = useCallback(async (auto = false) => {
    if (submitting) return;
    setSub(true);
    const timeTaken = Math.round((Date.now() - startedAt) / 1000);
    try {
      const { data } = await quizAPI.submit(classId, quizId, {
        answers,
        time_taken_seconds: timeTaken,
      });
      toast.success(auto ? 'Time up! Quiz submitted.' : 'Quiz submitted!');
      navigate(`/classes/${classId}/quizzes/${quizId}/result`, { state: { result: data.result, quiz } });
    } catch (e) {
      toast.error(e.response?.data?.message || 'Submission failed');
      setSub(false);
    }
  }, [answers, classId, quizId, startedAt, submitting]);

  if (loading) return (
    <div className="flex items-center justify-center h-full">
      <div className="flex flex-col items-center gap-3">
        <div className="w-10 h-10 border-4 border-brand-600 border-t-transparent rounded-full animate-spin"/>
        <p className="text-sm text-gray-500">Loading quiz…</p>
      </div>
    </div>
  );

  if (!quiz) return null;

  const questions  = quiz.questions || [];
  const q          = questions[current];
  const answered   = Object.keys(answers).length;
  const total      = questions.length;
  const progress   = (answered / total) * 100;
  const isLast     = current === total - 1;
  const isAnswered = answers[q?.id] !== undefined;

  const formatTime = (s) => {
    const m = Math.floor(s / 60);
    const sec = s % 60;
    return `${m}:${sec.toString().padStart(2,'0')}`;
  };

  const timeWarning = timeLeft !== null && timeLeft < 60;
  const timeCritical = timeLeft !== null && timeLeft < 30;

  return (
    <div className="min-h-full bg-gray-50 dark:bg-gray-900 flex flex-col">
      {/* Header */}
      <div className="bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 px-4 py-3 flex items-center justify-between sticky top-0 z-20">
        <div className="flex-1 min-w-0">
          <h1 className="font-display font-bold text-gray-900 dark:text-white text-sm sm:text-base truncate">{quiz.title}</h1>
          <p className="text-xs text-gray-400">{answered}/{total} answered</p>
        </div>
        {timeLeft !== null && (
          <div className={clsx(
            'flex items-center gap-2 px-4 py-2 rounded-xl font-mono font-bold text-sm transition-all',
            timeCritical ? 'bg-red-100 text-red-600 dark:bg-red-900/30 animate-pulse' :
            timeWarning  ? 'bg-orange-100 text-orange-600 dark:bg-orange-900/30' :
            'bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300'
          )}>
            <Clock size={14}/> {formatTime(timeLeft)}
          </div>
        )}
        <button onClick={() => setConf(true)}
          disabled={submitting}
          className="ml-3 flex items-center gap-2 px-4 py-2 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white rounded-xl text-sm font-semibold transition-all">
          {submitting ? <Loader2 size={14} className="animate-spin"/> : <Send size={14}/>}
          <span className="hidden sm:inline">{submitting ? 'Submitting…' : 'Submit'}</span>
        </button>
      </div>

      {/* Progress bar */}
      <div className="h-1.5 bg-gray-200 dark:bg-gray-700">
        <motion.div className="h-full bg-brand-600 rounded-full" animate={{ width: `${progress}%` }} transition={{ type:'spring', stiffness:100 }}/>
      </div>

      {/* Question navigator dots */}
      <div className="bg-white dark:bg-gray-800 border-b border-gray-100 dark:border-gray-700 px-4 py-3">
        <div className="flex flex-wrap gap-1.5 justify-center">
          {questions.map((_, i) => (
            <button key={i} onClick={() => setCurrent(i)}
              className={clsx(
                'w-8 h-8 rounded-lg text-xs font-bold transition-all',
                i === current
                  ? 'bg-brand-600 text-white scale-110 shadow-md'
                  : answers[questions[i]?.id] !== undefined
                    ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400'
                    : 'bg-gray-100 dark:bg-gray-700 text-gray-500 hover:bg-gray-200 dark:hover:bg-gray-600'
              )}>
              {i + 1}
            </button>
          ))}
        </div>
      </div>

      {/* Question area */}
      <div className="flex-1 flex items-start justify-center p-4 sm:p-8">
        <div className="w-full max-w-2xl">
          <AnimatePresence mode="wait">
            <motion.div key={q?.id} initial={{ opacity:0, x:30 }} animate={{ opacity:1, x:0 }} exit={{ opacity:0, x:-30 }} transition={{ duration:0.2 }}>
              {q && (
                <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-card p-6">
                  {/* Q number + type badge */}
                  <div className="flex items-center justify-between mb-4">
                    <span className="text-sm font-semibold text-brand-600">Question {current + 1} of {total}</span>
                    <span className="text-xs bg-gray-100 dark:bg-gray-700 text-gray-500 px-2 py-1 rounded-lg capitalize">
                      {q.question_type?.replace('_',' ')}
                    </span>
                  </div>

                  {/* Question text */}
                  <h2 className="text-lg font-semibold text-gray-900 dark:text-white leading-relaxed mb-6">{q.question_text}</h2>

                  {/* Multiple choice */}
                  {q.question_type === 'multiple_choice' && q.options && (
                    <div className="space-y-3">
                      {q.options.map((opt, oi) => (
                        <button key={oi} onClick={() => setAnswers((a) => ({ ...a, [q.id]: opt }))}
                          className={clsx(
                            'w-full text-left px-4 py-3.5 rounded-xl border-2 text-sm font-medium transition-all',
                            answers[q.id] === opt
                              ? 'border-brand-500 bg-brand-50 dark:bg-brand-900/20 text-brand-700 dark:text-brand-300'
                              : 'border-gray-200 dark:border-gray-600 text-gray-700 dark:text-gray-300 hover:border-brand-300 hover:bg-brand-50/50 dark:hover:bg-brand-900/10'
                          )}>
                          <span className={clsx('inline-flex w-6 h-6 rounded-full border-2 mr-3 items-center justify-center text-xs font-bold flex-shrink-0',
                            answers[q.id] === opt ? 'border-brand-500 bg-brand-500 text-white' : 'border-gray-300 dark:border-gray-500')}>
                            {answers[q.id] === opt ? '✓' : String.fromCharCode(65 + oi)}
                          </span>
                          {opt}
                        </button>
                      ))}
                    </div>
                  )}

                  {/* True / False */}
                  {q.question_type === 'true_false' && (
                    <div className="flex gap-4">
                      {['True','False'].map((opt) => (
                        <button key={opt} onClick={() => setAnswers((a) => ({ ...a, [q.id]: opt }))}
                          className={clsx(
                            'flex-1 py-4 rounded-2xl border-2 text-base font-bold transition-all',
                            answers[q.id] === opt
                              ? opt === 'True'
                                ? 'border-green-500 bg-green-50 dark:bg-green-900/20 text-green-700 dark:text-green-300'
                                : 'border-red-500 bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-300'
                              : 'border-gray-200 dark:border-gray-600 text-gray-500 hover:border-gray-300'
                          )}>
                          {opt === 'True' ? '✓ True' : '✗ False'}
                        </button>
                      ))}
                    </div>
                  )}

                  {/* Fill in blank */}
                  {q.question_type === 'fill_blank' && (
                    <input
                      value={answers[q.id] || ''}
                      onChange={(e) => setAnswers((a) => ({ ...a, [q.id]: e.target.value }))}
                      placeholder="Type your answer here…"
                      className="w-full px-4 py-3 rounded-xl border-2 border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-white text-sm outline-none focus:border-brand-500 focus:ring-2 focus:ring-brand-100 transition-all"
                    />
                  )}

                  {/* Essay */}
                  {q.question_type === 'essay' && (
                    <textarea
                      value={answers[q.id] || ''}
                      onChange={(e) => setAnswers((a) => ({ ...a, [q.id]: e.target.value }))}
                      placeholder="Write your answer here…"
                      rows={6}
                      className="w-full px-4 py-3 rounded-xl border-2 border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-white text-sm outline-none focus:border-brand-500 focus:ring-2 focus:ring-brand-100 resize-none transition-all"
                    />
                  )}

                  {/* Points */}
                  <p className="text-xs text-gray-400 mt-4 text-right">{q.points} point{q.points !== 1 ? 's' : ''}</p>
                </div>
              )}
            </motion.div>
          </AnimatePresence>

          {/* Navigation */}
          <div className="flex items-center justify-between mt-6">
            <button onClick={() => setCurrent((c) => Math.max(0, c - 1))} disabled={current === 0}
              className="flex items-center gap-2 px-4 py-2.5 border border-gray-200 dark:border-gray-700 rounded-xl text-sm font-medium text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 disabled:opacity-40 disabled:cursor-not-allowed transition-all">
              <ChevronLeft size={16}/> Previous
            </button>
            <span className="text-sm text-gray-400">{answered} of {total} answered</span>
            {isLast ? (
              <button onClick={() => setConf(true)}
                className="flex items-center gap-2 px-5 py-2.5 bg-green-600 hover:bg-green-700 text-white rounded-xl text-sm font-semibold transition-all">
                <Send size={15}/> Submit Quiz
              </button>
            ) : (
              <button onClick={() => setCurrent((c) => Math.min(total - 1, c + 1))}
                className="flex items-center gap-2 px-4 py-2.5 bg-brand-600 hover:bg-brand-700 text-white rounded-xl text-sm font-semibold transition-all">
                Next <ChevronRight size={16}/>
              </button>
            )}
          </div>

          {/* Unanswered warning */}
          {answered < total && (
            <div className="mt-4 flex items-center gap-2 text-xs text-orange-500 justify-center">
              <AlertTriangle size={13}/> {total - answered} question{total-answered>1?'s':''} unanswered
            </div>
          )}
        </div>
      </div>

      {/* Confirm submit modal */}
      <AnimatePresence>
        {showConfirm && (
          <motion.div initial={{ opacity:0 }} animate={{ opacity:1 }} exit={{ opacity:0 }}
            className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
            <motion.div initial={{ scale:0.9, opacity:0 }} animate={{ scale:1, opacity:1 }} exit={{ scale:0.9, opacity:0 }}
              className="bg-white dark:bg-gray-800 rounded-2xl p-6 max-w-sm w-full shadow-2xl">
              <div className="text-center mb-5">
                <div className="w-14 h-14 rounded-full bg-brand-100 dark:bg-brand-900/30 flex items-center justify-center mx-auto mb-3">
                  <Send size={24} className="text-brand-600"/>
                </div>
                <h3 className="font-display font-bold text-lg text-gray-900 dark:text-white">Submit Quiz?</h3>
                <p className="text-sm text-gray-500 mt-1">
                  You've answered <strong>{answered}</strong> of <strong>{total}</strong> questions.
                  {answered < total && <span className="text-orange-500"> {total-answered} unanswered.</span>}
                </p>
              </div>
              <div className="flex gap-3">
                <button onClick={() => setConf(false)} className="flex-1 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl text-sm font-semibold text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 transition-all">
                  Continue
                </button>
                <button onClick={() => { setConf(false); submitQuiz(); }} disabled={submitting}
                  className="flex-1 py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white rounded-xl text-sm font-semibold transition-all flex items-center justify-center gap-2">
                  {submitting ? <Loader2 size={14} className="animate-spin"/> : null} Submit
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
