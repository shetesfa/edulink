/**
 * EduLink — Create Quiz
 * ─────────────────────────────────────────────────────────────
 * Teachers can build a quiz with multiple questions (MCQ,
 * True/False, Short Answer), set a time limit, pass %, etc.
 */

import React, { useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import {
  ChevronLeft, Plus, Trash2, CheckCircle2, Brain,
  Clock, Percent, Eye, Shuffle, ToggleLeft, ToggleRight,
  Loader2, GripVertical, AlertTriangle,
} from 'lucide-react';
import { quizAPI } from '@/utils/api';
import toast from 'react-hot-toast';
import clsx from 'clsx';

const TYPES = [
  { value: 'mcq',          label: 'Multiple Choice' },
  { value: 'true_false',   label: 'True / False' },
  { value: 'short_answer', label: 'Short Answer' },
];

const defaultQuestion = () => ({
  _id:           Math.random().toString(36).slice(2),
  text:          '',
  type:          'mcq',
  options:       ['', '', '', ''],
  correct_answer:'',
  points:        1,
  explanation:   '',
});

export default function QuizCreate() {
  const { classId } = useParams();
  const navigate    = useNavigate();

  // ── Quiz meta ──
  const [title,          setTitle]          = useState('');
  const [description,    setDescription]    = useState('');
  const [timeLimit,      setTimeLimit]      = useState('');
  const [passPercentage, setPassPercentage] = useState(60);
  const [showAnswers,    setShowAnswers]    = useState(true);
  const [shuffle,        setShuffle]        = useState(false);
  const [isActive,       setIsActive]       = useState(true);

  // ── Questions ──
  const [questions, setQuestions] = useState([defaultQuestion()]);
  const [saving,    setSaving]    = useState(false);

  // ──────────────────────────────────────────────────────────────
  // Question helpers
  // ──────────────────────────────────────────────────────────────
  const updateQ = (idx, patch) =>
    setQuestions(qs => qs.map((q, i) => i === idx ? { ...q, ...patch } : q));

  const addQuestion = () =>
    setQuestions(qs => [...qs, defaultQuestion()]);

  const removeQuestion = (idx) => {
    if (questions.length === 1) { toast.error('A quiz must have at least one question.'); return; }
    setQuestions(qs => qs.filter((_, i) => i !== idx));
  };

  const updateOption = (qIdx, oIdx, val) =>
    setQuestions(qs => qs.map((q, i) => {
      if (i !== qIdx) return q;
      const opts = [...q.options];
      opts[oIdx] = val;
      return { ...q, options: opts };
    }));

  // ──────────────────────────────────────────────────────────────
  // Validate & submit
  // ──────────────────────────────────────────────────────────────
  const handleSave = async () => {
    if (!title.trim()) { toast.error('Quiz title is required.'); return; }
    for (let i = 0; i < questions.length; i++) {
      const q = questions[i];
      if (!q.text.trim()) { toast.error(`Question ${i + 1}: text is required.`); return; }
      if (!q.correct_answer.trim()) { toast.error(`Question ${i + 1}: correct answer is required.`); return; }
      if (q.type === 'mcq') {
        const filled = q.options.filter(o => o.trim());
        if (filled.length < 2) { toast.error(`Question ${i + 1}: add at least 2 options.`); return; }
        if (!q.options.includes(q.correct_answer)) {
          toast.error(`Question ${i + 1}: correct answer must match one of the options exactly.`); return;
        }
      }
    }

    setSaving(true);
    try {
      const payload = {
        title,
        description: description || null,
        time_limit:  timeLimit ? parseInt(timeLimit) : null,
        pass_percentage: passPercentage,
        show_answers: showAnswers,
        shuffle,
        is_active: isActive,
        questions: questions.map(q => ({
          text:           q.text,
          type:           q.type,
          options:        q.type === 'mcq' ? q.options.filter(o => o.trim()) : null,
          correct_answer: q.correct_answer,
          points:         q.points,
          explanation:    q.explanation || null,
        })),
      };
      await quizAPI.create(classId, payload);
      toast.success('Quiz created successfully!');
      navigate(`/classes/${classId}`, { state: { tab: 'quizzes' } });
    } catch (err) {
      const msg = err?.response?.data?.message || 'Failed to create quiz.';
      toast.error(msg);
    } finally {
      setSaving(false);
    }
  };

  // ──────────────────────────────────────────────────────────────
  // Render
  // ──────────────────────────────────────────────────────────────
  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 pb-20">
      {/* ── Header ── */}
      <div className="sticky top-0 z-30 bg-white/80 dark:bg-gray-900/80 backdrop-blur border-b border-gray-200 dark:border-gray-800">
        <div className="max-w-4xl mx-auto px-4 py-3 flex items-center justify-between gap-4">
          <Link
            to={`/classes/${classId}`}
            className="flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-900 dark:hover:text-white transition-colors"
          >
            <ChevronLeft className="w-4 h-4" /> Back to class
          </Link>

          <div className="flex items-center gap-2">
            <Brain className="w-5 h-5 text-brand-500" />
            <span className="font-semibold text-gray-900 dark:text-white text-sm hidden sm:block">Create Quiz</span>
          </div>

          <button
            onClick={handleSave}
            disabled={saving}
            className="flex items-center gap-2 px-4 py-2 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white text-sm font-semibold rounded-xl transition-all"
          >
            {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <CheckCircle2 className="w-4 h-4" />}
            {saving ? 'Saving…' : 'Publish Quiz'}
          </button>
        </div>
      </div>

      <div className="max-w-4xl mx-auto px-4 pt-8 space-y-6">
        {/* ── Quiz settings card ── */}
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-200 dark:border-gray-800 p-6 shadow-sm"
        >
          <h2 className="font-bold text-lg text-gray-900 dark:text-white mb-5">Quiz Details</h2>

          <div className="space-y-4">
            {/* Title */}
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                Title <span className="text-red-500">*</span>
              </label>
              <input
                value={title}
                onChange={e => setTitle(e.target.value)}
                placeholder="e.g. Chapter 4 Review Quiz"
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>

            {/* Description */}
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Description (optional)</label>
              <textarea
                value={description}
                onChange={e => setDescription(e.target.value)}
                rows={2}
                placeholder="What should students know before taking this quiz?"
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white text-sm resize-none focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>

            {/* Settings row */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
              <div>
                <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1 flex items-center gap-1">
                  <Clock className="w-3.5 h-3.5" /> Time Limit (min)
                </label>
                <input
                  type="number"
                  min="1"
                  max="180"
                  value={timeLimit}
                  onChange={e => setTimeLimit(e.target.value)}
                  placeholder="None"
                  className="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1 flex items-center gap-1">
                  <Percent className="w-3.5 h-3.5" /> Pass %
                </label>
                <input
                  type="number"
                  min="1"
                  max="100"
                  value={passPercentage}
                  onChange={e => setPassPercentage(parseInt(e.target.value) || 60)}
                  className="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
                />
              </div>
              <div className="flex flex-col gap-2 pt-1">
                <Toggle label="Show Answers" value={showAnswers} onChange={setShowAnswers} icon={<Eye className="w-3.5 h-3.5" />} />
                <Toggle label="Shuffle Q's"  value={shuffle}     onChange={setShuffle}     icon={<Shuffle className="w-3.5 h-3.5" />} />
              </div>
              <div className="flex flex-col gap-2 pt-1">
                <Toggle label="Active Now" value={isActive} onChange={setIsActive} icon={<CheckCircle2 className="w-3.5 h-3.5" />} />
              </div>
            </div>
          </div>
        </motion.div>

        {/* ── Questions ── */}
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="font-bold text-lg text-gray-900 dark:text-white">
              Questions <span className="text-brand-500 ml-1">({questions.length})</span>
            </h2>
          </div>

          <AnimatePresence initial={false}>
            {questions.map((q, idx) => (
              <QuestionCard
                key={q._id}
                question={q}
                index={idx}
                total={questions.length}
                onUpdate={(patch) => updateQ(idx, patch)}
                onRemove={() => removeQuestion(idx)}
                onUpdateOption={(oIdx, val) => updateOption(idx, oIdx, val)}
              />
            ))}
          </AnimatePresence>

          <motion.button
            whileHover={{ scale: 1.01 }}
            whileTap={{ scale: 0.99 }}
            onClick={addQuestion}
            className="w-full py-3 rounded-2xl border-2 border-dashed border-brand-300 dark:border-brand-700 text-brand-600 dark:text-brand-400 hover:bg-brand-50 dark:hover:bg-brand-900/20 flex items-center justify-center gap-2 text-sm font-semibold transition-all"
          >
            <Plus className="w-4 h-4" /> Add Question
          </motion.button>
        </div>
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────
// Question Card
// ──────────────────────────────────────────────────────────────
function QuestionCard({ question: q, index, onUpdate, onRemove, onUpdateOption }) {
  const isMCQ        = q.type === 'mcq';
  const isTrueFalse  = q.type === 'true_false';
  const isShortAns   = q.type === 'short_answer';

  return (
    <motion.div
      layout
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, scale: 0.97 }}
      className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-200 dark:border-gray-800 shadow-sm overflow-hidden"
    >
      {/* Card header */}
      <div className="flex items-center justify-between px-5 py-3 bg-gray-50 dark:bg-gray-800/50 border-b border-gray-200 dark:border-gray-700">
        <div className="flex items-center gap-3">
          <GripVertical className="w-4 h-4 text-gray-400 cursor-grab" />
          <span className="text-sm font-bold text-gray-700 dark:text-gray-300">Q{index + 1}</span>
          {/* Type selector */}
          <select
            value={q.type}
            onChange={e => onUpdate({ type: e.target.value, options: ['', '', '', ''], correct_answer: '' })}
            className="text-xs font-medium bg-brand-100 dark:bg-brand-900/30 text-brand-700 dark:text-brand-300 rounded-lg px-2 py-1 border-0 focus:outline-none focus:ring-2 focus:ring-brand-500 cursor-pointer"
          >
            {TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
          </select>
        </div>

        <div className="flex items-center gap-2">
          <div className="flex items-center gap-1">
            <span className="text-xs text-gray-500 dark:text-gray-400">Pts:</span>
            <input
              type="number"
              min="1"
              value={q.points}
              onChange={e => onUpdate({ points: parseInt(e.target.value) || 1 })}
              className="w-12 text-xs text-center rounded-lg border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-gray-900 dark:text-white py-1 focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
          </div>
          <button onClick={onRemove} className="p-1.5 rounded-lg text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors">
            <Trash2 className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Card body */}
      <div className="p-5 space-y-4">
        {/* Question text */}
        <div>
          <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Question Text *</label>
          <textarea
            rows={2}
            value={q.text}
            onChange={e => onUpdate({ text: e.target.value })}
            placeholder="Type your question here…"
            className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white text-sm resize-none focus:outline-none focus:ring-2 focus:ring-brand-500"
          />
        </div>

        {/* MCQ Options */}
        {isMCQ && (
          <div className="space-y-2">
            <label className="block text-xs font-medium text-gray-500 dark:text-gray-400">Answer Options</label>
            {q.options.map((opt, oIdx) => (
              <div key={oIdx} className="flex items-center gap-2">
                <span className="w-6 h-6 flex-shrink-0 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400 text-xs font-bold flex items-center justify-center">
                  {String.fromCharCode(65 + oIdx)}
                </span>
                <input
                  value={opt}
                  onChange={e => onUpdateOption(oIdx, e.target.value)}
                  placeholder={`Option ${String.fromCharCode(65 + oIdx)}`}
                  className={clsx(
                    'flex-1 px-3 py-2 rounded-xl border text-sm focus:outline-none focus:ring-2 focus:ring-brand-500',
                    opt && opt === q.correct_answer
                      ? 'border-green-400 dark:border-green-600 bg-green-50 dark:bg-green-900/20 text-gray-900 dark:text-white'
                      : 'border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white'
                  )}
                />
                <button
                  onClick={() => onUpdate({ correct_answer: opt })}
                  disabled={!opt.trim()}
                  title="Mark as correct"
                  className={clsx(
                    'p-1.5 rounded-lg flex-shrink-0 transition-colors',
                    opt && opt === q.correct_answer
                      ? 'text-green-600 bg-green-100 dark:bg-green-900/30'
                      : 'text-gray-400 hover:text-green-500 hover:bg-green-50 dark:hover:bg-green-900/20'
                  )}
                >
                  <CheckCircle2 className="w-4 h-4" />
                </button>
              </div>
            ))}
            {q.correct_answer && (
              <p className="text-xs text-green-600 dark:text-green-400 flex items-center gap-1 pt-1">
                <CheckCircle2 className="w-3.5 h-3.5" /> Correct: {q.correct_answer}
              </p>
            )}
          </div>
        )}

        {/* True/False */}
        {isTrueFalse && (
          <div>
            <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-2">Correct Answer</label>
            <div className="flex gap-3">
              {['True', 'False'].map(v => (
                <button
                  key={v}
                  onClick={() => onUpdate({ correct_answer: v })}
                  className={clsx(
                    'flex-1 py-2 rounded-xl text-sm font-semibold border-2 transition-all',
                    q.correct_answer === v
                      ? 'border-brand-500 bg-brand-50 dark:bg-brand-900/30 text-brand-700 dark:text-brand-300'
                      : 'border-gray-200 dark:border-gray-700 text-gray-500 dark:text-gray-400 hover:border-brand-300'
                  )}
                >
                  {v}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Short Answer */}
        {isShortAns && (
          <div>
            <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">
              Expected Answer (exact match) *
            </label>
            <input
              value={q.correct_answer}
              onChange={e => onUpdate({ correct_answer: e.target.value })}
              placeholder="e.g. photosynthesis"
              className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
            <p className="text-xs text-amber-500 dark:text-amber-400 mt-1.5 flex items-center gap-1">
              <AlertTriangle className="w-3.5 h-3.5" /> Matching is case-insensitive but must match exactly.
            </p>
          </div>
        )}

        {/* Explanation */}
        <div>
          <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Explanation (optional, shown after submit)</label>
          <input
            value={q.explanation}
            onChange={e => onUpdate({ explanation: e.target.value })}
            placeholder="Why is this the correct answer?"
            className="w-full px-4 py-2 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
          />
        </div>
      </div>
    </motion.div>
  );
}

// ──────────────────────────────────────────────────────────────
// Toggle helper
// ──────────────────────────────────────────────────────────────
function Toggle({ label, value, onChange, icon }) {
  return (
    <button
      onClick={() => onChange(!value)}
      className={clsx(
        'flex items-center gap-1.5 text-xs font-medium px-2.5 py-1.5 rounded-lg border transition-all',
        value
          ? 'border-brand-400 bg-brand-50 dark:bg-brand-900/20 text-brand-700 dark:text-brand-300'
          : 'border-gray-200 dark:border-gray-700 text-gray-500 dark:text-gray-400 hover:border-gray-300'
      )}
    >
      {value ? <ToggleRight className="w-3.5 h-3.5" /> : <ToggleLeft className="w-3.5 h-3.5" />}
      {icon}
      {label}
    </button>
  );
}
