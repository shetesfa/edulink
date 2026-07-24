/**
 * EduLink — Assignment View
 * ─────────────────────────────────────────────────────────────
 * Student: submit text + files, see own submission date & feedback
 * Teacher: see all submissions with submitted_at date, grade panel
 */

import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import {
  ChevronLeft, Upload, FileText, CheckCircle2, Clock,
  Calendar, Users, Award, Loader2, Star, AlertTriangle,
  Download, Eye,
} from 'lucide-react';
import { assignmentAPI, fileAPI } from '@/utils/api';
import { useAuthStore } from '@/store';
import clsx from 'clsx';
import toast from 'react-hot-toast';
import { format, isPast, differenceInDays } from 'date-fns';

export default function AssignmentView() {
  const { classId, id: assignmentId } = useParams();
  const { user } = useAuthStore();
  const isTeacher = user?.role === 'teacher';


  const [assignment, setAssignment] = useState(null);
  const [submissions, setSubmissions] = useState([]);
  const [mySubmission, setMySubmission] = useState(null);
  const [loading, setLoading] = useState(true);

  // Student submission state
  const [text, setText]         = useState('');
  const [files, setFiles]       = useState([]);
  const [uploading, setUploading] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  // Teacher grading state
  const [gradingId, setGradingId]     = useState(null);  // submission.id being graded
  const [gradeScore, setGradeScore]   = useState('');
  const [gradeFeedback, setGradeFeedback] = useState('');
  const [savingGrade, setSavingGrade] = useState(false);

  useEffect(() => {
    const load = async () => {
      try {
        const { data } = await assignmentAPI.get(classId, assignmentId);
        setAssignment(data.assignment);
        if (isTeacher) {
          const subRes = await assignmentAPI.submissions(classId, assignmentId);
          setSubmissions(subRes.data.submissions || []);
        } else {
          setMySubmission(data.my_submission || null);
        }
      } catch { toast.error('Failed to load assignment'); }
      finally { setLoading(false); }
    };
    load();
  }, [classId, assignmentId]);

  // ── Student: file select ──
  const handleFileSelect = (e) => {
    const selected = Array.from(e.target.files || []);
    setFiles((prev) => [...prev, ...selected]);
    e.target.value = '';
  };

  // ── Student: submit ──
  const handleSubmit = async () => {
    if (!text.trim() && files.length === 0) {
      toast.error('Add your answer or attach a file.');
      return;
    }
    setSubmitting(true);
    try {
      const fd = new FormData();
      fd.append('text_answer', text);
      files.forEach((f) => fd.append('files[]', f));
      const { data } = await assignmentAPI.submit(classId, assignmentId, fd);
      setMySubmission(data.submission);
      toast.success('Assignment submitted! 🎉');
    } catch (err) {
      toast.error(err.response?.data?.message || 'Submission failed');
    } finally {
      setSubmitting(false);
    }
  };

  // ── Teacher: save grade ──
  const saveGrade = async (submissionId) => {
    if (!gradeScore && gradeScore !== 0) { toast.error('Enter a score'); return; }
    setSavingGrade(true);
    try {
      await assignmentAPI.grade(classId, assignmentId, submissionId, {
        score: parseFloat(gradeScore),
        feedback: gradeFeedback,
      });
      setSubmissions((prev) => prev.map((s) =>
        s.id === submissionId ? { ...s, score: parseFloat(gradeScore), feedback: gradeFeedback, status: 'graded', graded_at: new Date().toISOString() } : s
      ));
      setGradingId(null);
      toast.success('Grade saved ✓');
    } catch { toast.error('Failed to save grade'); }
    finally { setSavingGrade(false); }
  };

  if (loading) return (
    <div className="flex items-center justify-center h-64">
      <Loader2 size={32} className="animate-spin text-brand-500" />
    </div>
  );

  if (!assignment) return (
    <div className="text-center py-20 text-gray-400">Assignment not found.</div>
  );

  const overdue     = assignment.due_date && isPast(new Date(assignment.due_date));
  const daysLeft    = assignment.due_date ? differenceInDays(new Date(assignment.due_date), new Date()) : null;
  const gradedCount = submissions.filter((s) => s.status === 'graded').length;

  return (
    <div className="max-w-4xl mx-auto p-4 sm:p-6 space-y-6">
      {/* Back */}
      <Link to={`/classes/${classId}`} className="inline-flex items-center gap-1.5 text-sm text-gray-500 hover:text-brand-600 transition-colors">
        <ChevronLeft size={16} /> Back to class
      </Link>

      {/* Assignment header */}
      <div className="bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-100 dark:border-gray-700 shadow-card">
        <div className="flex items-start justify-between gap-4">
          <div className="flex-1">
            <div className="flex items-center gap-2 mb-2">
              <FileText size={18} className="text-brand-600" />
              <span className="text-xs font-semibold uppercase tracking-wide text-brand-600">Assignment</span>
            </div>
            <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white mb-2">{assignment.title}</h1>
            <p className="text-gray-500 dark:text-gray-400 text-sm leading-relaxed">{assignment.description}</p>
          </div>
          <div className="text-right flex-shrink-0">
            <p className="font-bold text-2xl text-gray-900 dark:text-white">{assignment.max_score}</p>
            <p className="text-xs text-gray-400">points</p>
          </div>
        </div>

        {/* Meta */}
        <div className="flex flex-wrap gap-4 mt-5 pt-5 border-t border-gray-100 dark:border-gray-700">
          {assignment.due_date && (
            <div className="flex items-center gap-1.5">
              <Calendar size={14} className={overdue ? 'text-red-500' : 'text-gray-400'} />
              <span className={clsx('text-sm font-medium', overdue ? 'text-red-500' : 'text-gray-600 dark:text-gray-300')}>
                {overdue
                  ? `⚠️ Overdue (was ${format(new Date(assignment.due_date), 'MMM d, h:mm a')})`
                  : daysLeft === 0 ? '⏰ Due today!'
                  : daysLeft === 1 ? '⏰ Due tomorrow'
                  : `Due ${format(new Date(assignment.due_date), 'MMM d, yyyy h:mm a')}`}
              </span>
            </div>
          )}
          {isTeacher && (
            <div className="flex items-center gap-1.5">
              <Users size={14} className="text-gray-400" />
              <span className="text-sm text-gray-600 dark:text-gray-300">{submissions.length} submissions · {gradedCount} graded</span>
            </div>
          )}
          {assignment.allow_late && (
            <span className="text-xs px-2 py-1 bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-300 rounded-full font-medium">Late submissions allowed</span>
          )}
        </div>

        {/* Attachments */}
        {(assignment.attachments?.length > 0) && (
          <div className="mt-4 space-y-2">
            <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide">Attachments</p>
            {assignment.attachments.map((att) => (
              <a key={att.id} href={att.url} target="_blank" rel="noopener noreferrer"
                className="flex items-center gap-2.5 p-3 rounded-xl border border-gray-100 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 transition-all text-sm">
                <FileText size={15} className="text-brand-500 flex-shrink-0" />
                <span className="flex-1 truncate text-gray-700 dark:text-gray-300">{att.original_name}</span>
                <Download size={14} className="text-gray-400" />
              </a>
            ))}
          </div>
        )}
      </div>

      {/* ────────── STUDENT VIEW ────────── */}
      {!isTeacher && (
        <>
          {mySubmission ? (
            // Already submitted
            <div className="bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-100 dark:border-gray-700 shadow-card space-y-5">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-green-100 dark:bg-green-900/30 rounded-xl flex items-center justify-center">
                  <CheckCircle2 size={20} className="text-green-600" />
                </div>
                <div>
                  <h3 className="font-display font-semibold text-gray-900 dark:text-white">Submitted</h3>
                  <p className="text-xs text-gray-400">
                    {mySubmission.submitted_at
                      ? `Submitted on ${format(new Date(mySubmission.submitted_at), 'MMMM d, yyyy')} at ${format(new Date(mySubmission.submitted_at), 'h:mm a')}`
                      : 'Submitted'}
                    {mySubmission.status === 'late' && ' · ⚠️ Late'}
                  </p>
                </div>
                {mySubmission.score !== null && mySubmission.score !== undefined && (
                  <div className="ml-auto text-right">
                    <p className="font-bold text-2xl text-brand-600">{mySubmission.score}<span className="text-base text-gray-400">/{assignment.max_score}</span></p>
                    <p className="text-xs text-gray-400">Your score</p>
                  </div>
                )}
              </div>

              {mySubmission.text_answer && (
                <div className="p-4 bg-gray-50 dark:bg-gray-700 rounded-xl text-sm text-gray-700 dark:text-gray-300 whitespace-pre-wrap leading-relaxed">
                  {mySubmission.text_answer}
                </div>
              )}

              {mySubmission.feedback && (
                <div className="p-4 bg-brand-50 dark:bg-brand-900/20 rounded-xl border border-brand-100 dark:border-brand-800">
                  <p className="text-xs font-semibold text-brand-600 mb-1.5">Teacher Feedback</p>
                  <p className="text-sm text-gray-700 dark:text-gray-300">{mySubmission.feedback}</p>
                  {mySubmission.graded_at && (
                    <p className="text-xs text-gray-400 mt-2">Graded {format(new Date(mySubmission.graded_at), 'MMM d, yyyy')}</p>
                  )}
                </div>
              )}

              {mySubmission.status === 'submitted' && (
                <p className="text-xs text-amber-600 dark:text-amber-400 flex items-center gap-1.5">
                  <Clock size={12} /> Waiting for teacher to grade your submission
                </p>
              )}
            </div>
          ) : (
            // Submit form
            <div className="bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-100 dark:border-gray-700 shadow-card space-y-4">
              <h3 className="font-display font-semibold text-gray-900 dark:text-white">Your Answer</h3>

              {overdue && !assignment.allow_late && (
                <div className="flex items-center gap-2 p-3 bg-red-50 dark:bg-red-900/20 rounded-xl text-sm text-red-600 dark:text-red-400">
                  <AlertTriangle size={15} /> Deadline has passed. This assignment is closed.
                </div>
              )}

              {(!overdue || assignment.allow_late) && (
                <>
                  <textarea
                    value={text}
                    onChange={(e) => setText(e.target.value)}
                    placeholder="Write your answer here…"
                    rows={8}
                    className="w-full px-4 py-3 rounded-xl border border-gray-200 dark:border-gray-600 text-sm outline-none focus:border-brand-400 focus:ring-2 focus:ring-brand-100 dark:focus:ring-brand-900/30 bg-white dark:bg-gray-700 dark:text-white resize-none transition-all"
                  />

                  {/* File attachments */}
                  <div>
                    <label className="flex items-center gap-2 cursor-pointer text-sm font-medium text-brand-600 hover:text-brand-700 transition-colors w-fit">
                      <Upload size={15} />
                      <span>Attach files</span>
                      <input type="file" multiple className="sr-only" onChange={handleFileSelect} />
                    </label>
                    {files.length > 0 && (
                      <div className="mt-2 space-y-1">
                        {files.map((f, i) => (
                          <div key={i} className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-300">
                            <FileText size={13} className="text-gray-400" />
                            <span className="truncate">{f.name}</span>
                            <button onClick={() => setFiles((prev) => prev.filter((_, idx) => idx !== i))}
                              className="ml-auto text-red-400 hover:text-red-600 text-xs">Remove</button>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>

                  <button onClick={handleSubmit} disabled={submitting}
                    className="w-full flex items-center justify-center gap-2 py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-xl text-sm transition-all shadow-md">
                    {submitting ? <><Loader2 size={15} className="animate-spin" /> Submitting…</> : 'Submit Assignment'}
                  </button>
                </>
              )}
            </div>
          )}
        </>
      )}

      {/* ────────── TEACHER VIEW ────────── */}
      {isTeacher && (
        <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-card overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-100 dark:border-gray-700 flex items-center justify-between">
            <h3 className="font-display font-semibold text-gray-900 dark:text-white">
              Submissions ({submissions.length})
            </h3>
            <div className="flex gap-2 text-xs">
              <span className="px-2 py-1 bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300 rounded-full font-medium">
                {submissions.filter((s) => s.status === 'submitted').length} pending
              </span>
              <span className="px-2 py-1 bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-300 rounded-full font-medium">
                {gradedCount} graded
              </span>
            </div>
          </div>

          {submissions.length === 0 ? (
            <div className="py-16 text-center text-gray-400">
              <FileText size={36} className="mx-auto mb-3 opacity-30" />
              <p>No submissions yet</p>
            </div>
          ) : (
            <div className="divide-y divide-gray-100 dark:divide-gray-700">
              {submissions.map((sub) => (
                <div key={sub.id} className="p-5">
                  {/* Student info row */}
                  <div className="flex items-start justify-between gap-4">
                    <div className="flex items-center gap-3 flex-1 min-w-0">
                      <div className="w-9 h-9 rounded-full bg-brand-100 dark:bg-brand-900/30 flex items-center justify-center text-brand-600 font-bold text-sm flex-shrink-0">
                        {(sub.student_name || '?')[0]?.toUpperCase()}
                      </div>
                      <div className="min-w-0">
                        <p className="font-semibold text-sm text-gray-900 dark:text-white">{sub.student_name}</p>
                        <p className="text-xs text-gray-400">{sub.student_email}</p>
                        <p className="text-xs text-gray-400 flex items-center gap-1 mt-0.5">
                          <Calendar size={11} />
                          {sub.submitted_at
                            ? `Submitted ${format(new Date(sub.submitted_at), 'MMM d, yyyy')} at ${format(new Date(sub.submitted_at), 'h:mm a')}`
                            : 'Submission time unknown'}
                          {sub.status === 'late' && <span className="text-amber-500 ml-1">· Late</span>}
                        </p>
                      </div>
                    </div>

                    {/* Score badge / grade button */}
                    <div className="flex items-center gap-2 flex-shrink-0">
                      {sub.score !== null && sub.score !== undefined ? (
                        <span className="px-3 py-1 bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-300 rounded-full text-sm font-bold">
                          {sub.score}/{assignment.max_score}
                        </span>
                      ) : null}
                      <button
                        onClick={() => {
                          setGradingId(gradingId === sub.id ? null : sub.id);
                          setGradeScore(sub.score ?? '');
                          setGradeFeedback(sub.feedback || '');
                        }}
                        className={clsx('px-3 py-1.5 rounded-xl text-xs font-semibold transition-all',
                          sub.status === 'graded'
                            ? 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600'
                            : 'bg-brand-600 text-white hover:bg-brand-700')}>
                        {sub.status === 'graded' ? 'Edit Grade' : 'Grade'}
                      </button>
                    </div>
                  </div>

                  {/* Full text answer */}
                  {sub.text_answer && (
                    <details className="mt-3 group">
                      <summary className="cursor-pointer text-xs font-semibold text-brand-600 hover:text-brand-700 flex items-center gap-1.5 list-none select-none">
                        <Eye size={13} /> View Answer
                      </summary>
                      <div className="mt-2 p-4 bg-gray-50 dark:bg-gray-700/60 rounded-xl text-sm text-gray-700 dark:text-gray-200 whitespace-pre-wrap leading-relaxed border border-gray-100 dark:border-gray-600">
                        {sub.text_answer}
                      </div>
                    </details>
                  )}

                  {/* Attached files */}
                  {sub.files && sub.files.length > 0 && (
                    <div className="mt-3">
                      <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-1.5">Attached Files</p>
                      <div className="space-y-1.5">
                        {sub.files.map((f, fi) => (
                          <a key={fi} href={f.url} target="_blank" rel="noopener noreferrer"
                            className="flex items-center gap-2.5 px-3 py-2 rounded-xl border border-gray-100 dark:border-gray-600 bg-gray-50 dark:bg-gray-700/50 hover:bg-brand-50 dark:hover:bg-brand-900/20 hover:border-brand-200 transition-all text-sm group">
                            <FileText size={14} className="text-brand-500 flex-shrink-0" />
                            <span className="flex-1 truncate text-gray-700 dark:text-gray-300 group-hover:text-brand-600">{f.original_name}</span>
                            {f.size && <span className="text-xs text-gray-400 flex-shrink-0">{(f.size / 1024).toFixed(0)} KB</span>}
                            <Download size={13} className="text-gray-400 group-hover:text-brand-500 flex-shrink-0" />
                          </a>
                        ))}
                      </div>
                    </div>
                  )}

                  {/* Existing feedback (if graded) */}
                  {sub.feedback && (
                    <div className="mt-3 p-3 bg-brand-50 dark:bg-brand-900/20 rounded-xl border border-brand-100 dark:border-brand-800 text-sm">
                      <p className="text-xs font-semibold text-brand-600 mb-1">Your Feedback</p>
                      <p className="text-gray-700 dark:text-gray-300">{sub.feedback}</p>
                    </div>
                  )}

                  {/* Grading panel */}
                  <AnimatePresence>
                    {gradingId === sub.id && (
                      <motion.div
                        initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }}
                        className="mt-4 space-y-3 pt-4 border-t border-gray-100 dark:border-gray-700"
                      >
                        <div className="grid grid-cols-2 gap-3">
                          <div>
                            <label className="block text-xs font-semibold text-gray-500 mb-1">Score (max {assignment.max_score})</label>
                            <input
                              type="number" value={gradeScore} onChange={(e) => setGradeScore(e.target.value)}
                              min={0} max={assignment.max_score} step={0.5}
                              className="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-600 text-sm outline-none focus:border-brand-400 bg-white dark:bg-gray-700 dark:text-white"
                              placeholder="0"
                            />
                          </div>
                          <div className="flex items-end">
                            <button onClick={() => saveGrade(sub.id)} disabled={savingGrade}
                              className="w-full flex items-center justify-center gap-1.5 py-2 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-xl text-sm transition-all">
                              {savingGrade ? <Loader2 size={13} className="animate-spin" /> : <CheckCircle2 size={13} />}
                              Save Grade
                            </button>
                          </div>
                        </div>
                        <div>
                          <label className="block text-xs font-semibold text-gray-500 mb-1">Feedback (optional)</label>
                          <textarea value={gradeFeedback} onChange={(e) => setGradeFeedback(e.target.value)}
                            rows={3} placeholder="Write feedback for the student…"
                            className="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-600 text-sm outline-none focus:border-brand-400 bg-white dark:bg-gray-700 dark:text-white resize-none transition-all"
                          />
                        </div>
                      </motion.div>
                    )}
                  </AnimatePresence>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
