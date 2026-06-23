import React from 'react';
import { useLocation, useNavigate, useParams, Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { CheckCircle2, XCircle, RotateCcw, Home, Trophy, Target } from 'lucide-react';
import clsx from 'clsx';

export default function QuizResult() {
  const { classId, quizId } = useParams();
  const { state }           = useLocation();
  const navigate            = useNavigate();
  const result              = state?.result;

  if (!result) { navigate(`/classes/${classId}`); return null; }

  const { score, max_score, percentage, passed, grade, answers } = result;
  const answerList = answers ? Object.values(answers) : [];
  const correct    = answerList.filter((a) => a.is_correct === true).length;
  const total      = answerList.length;

  return (
    <div className="min-h-full bg-gray-50 dark:bg-gray-900 flex items-center justify-center p-4">
      <div className="w-full max-w-lg">
        <motion.div initial={{ scale:0.8, opacity:0 }} animate={{ scale:1, opacity:1 }} transition={{ type:'spring', stiffness:200 }}
          className="bg-white dark:bg-gray-800 rounded-3xl shadow-xl border border-gray-100 dark:border-gray-700 overflow-hidden">

          {/* Result banner */}
          <div className={clsx('p-8 text-center', passed ? 'bg-gradient-to-br from-green-500 to-emerald-600' : 'bg-gradient-to-br from-orange-500 to-red-500')}>
            <motion.div initial={{ scale:0 }} animate={{ scale:1 }} transition={{ delay:0.2, type:'spring', stiffness:200 }}>
              {passed ? <Trophy size={56} className="text-white mx-auto mb-3"/> : <Target size={56} className="text-white mx-auto mb-3"/>}
            </motion.div>
            <h1 className="font-display font-bold text-3xl text-white mb-1">{passed ? 'Passed! 🎉' : 'Keep Trying!'}</h1>
            <p className="text-white/80 text-sm">{passed ? 'Great work on this quiz.' : 'Review the material and try again.'}</p>
          </div>

          <div className="p-6 space-y-5">
            {/* Score ring */}
            <div className="flex items-center justify-center">
              <div className="relative w-32 h-32">
                <svg viewBox="0 0 100 100" className="w-full h-full -rotate-90">
                  <circle cx="50" cy="50" r="40" fill="none" stroke="#F3F4F6" strokeWidth="10"/>
                  <motion.circle cx="50" cy="50" r="40" fill="none"
                    stroke={passed ? '#10B981' : '#F59E0B'} strokeWidth="10" strokeLinecap="round"
                    strokeDasharray={`${2 * Math.PI * 40}`}
                    initial={{ strokeDashoffset: 2 * Math.PI * 40 }}
                    animate={{ strokeDashoffset: 2 * Math.PI * 40 * (1 - (percentage || 0) / 100) }}
                    transition={{ duration:1.2, ease:'easeOut', delay:0.3 }}
                  />
                </svg>
                <div className="absolute inset-0 flex flex-col items-center justify-center">
                  <span className="font-display font-bold text-2xl text-gray-900 dark:text-white">{percentage}%</span>
                  <span className="text-xs text-gray-400 font-bold">{grade}</span>
                </div>
              </div>
            </div>

            {/* Stats */}
            <div className="grid grid-cols-3 gap-3">
              {[
                { label:'Score',   value:`${score}/${max_score}`, color:'text-violet-600' },
                { label:'Correct', value:`${correct}/${total}`,   color:'text-green-600'  },
                { label:'Grade',   value:grade,                    color: passed ? 'text-green-600' : 'text-orange-500' },
              ].map((s) => (
                <div key={s.label} className="text-center p-3 bg-gray-50 dark:bg-gray-700 rounded-xl">
                  <p className={clsx('font-display font-bold text-xl', s.color)}>{s.value}</p>
                  <p className="text-xs text-gray-400 mt-0.5">{s.label}</p>
                </div>
              ))}
            </div>

            {/* Answer review */}
            {answerList.length > 0 && (
              <div className="space-y-2 max-h-60 overflow-y-auto">
                <p className="text-sm font-semibold text-gray-700 dark:text-gray-300">Answer Review</p>
                {answerList.map((a, i) => (
                  <div key={i} className={clsx('flex items-start gap-3 p-3 rounded-xl text-sm',
                    a.is_correct === true  ? 'bg-green-50 dark:bg-green-900/20' :
                    a.is_correct === false ? 'bg-red-50 dark:bg-red-900/20' : 'bg-gray-50 dark:bg-gray-700')}>
                    {a.is_correct === true  ? <CheckCircle2 size={16} className="text-green-500 flex-shrink-0 mt-0.5"/> :
                     a.is_correct === false ? <XCircle     size={16} className="text-red-500 flex-shrink-0 mt-0.5"/>    :
                     <div className="w-4 h-4 rounded-full border-2 border-gray-300 flex-shrink-0 mt-0.5"/>}
                    <div className="flex-1 min-w-0">
                      <p className="text-gray-700 dark:text-gray-300">Q{i + 1}: <span className="font-medium">{a.given || '—'}</span></p>
                      {a.correct && a.is_correct === false && <p className="text-xs text-green-600 mt-0.5">Correct: {a.correct}</p>}
                      {a.explanation && <p className="text-xs text-gray-500 mt-0.5">{a.explanation}</p>}
                    </div>
                    <span className="text-xs font-semibold text-gray-400 flex-shrink-0">{a.points}pt</span>
                  </div>
                ))}
              </div>
            )}

            {/* Actions */}
            <div className="flex gap-3 pt-2">
              <Link to={`/classes/${classId}`}
                className="flex-1 flex items-center justify-center gap-2 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl text-sm font-semibold text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 transition-all">
                <Home size={15}/> Back to Class
              </Link>
              <Link to={`/classes/${classId}/quizzes/${quizId}/take`}
                className="flex-1 flex items-center justify-center gap-2 py-2.5 bg-violet-600 hover:bg-violet-700 text-white rounded-xl text-sm font-semibold transition-all">
                <RotateCcw size={15}/> Try Again
              </Link>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
