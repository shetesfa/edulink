import React, { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import {
  FileText, ArrowLeft, Clock, Award, Send, Loader2,
  CheckCircle2, Download,
} from 'lucide-react';
import { assignmentAPI } from '@/utils/api';
import { useAuthStore } from '@/store';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { format } from 'date-fns';
import toast from 'react-hot-toast';
import clsx from 'clsx';

export default function AssignmentView() {
  const { classId, id } = useParams();
  const { user }        = useAuthStore();
  const navigate        = useNavigate();
  const fileRef         = useRef();

  const [assignment, setAssignment] = useState(null);
  const [text, setText]             = useState('');
  const [files, setFiles]           = useState([]);
  const [submitting, setSub]        = useState(false);
  const [loading, setLoading]       = useState(true);

  const isTeacher = user?.role === 'teacher' || user?.role === 'school_admin';

  useEffect(() => {
    assignmentAPI.get(classId, id)
      .then(({ data }) => setAssignment(data.assignment))
      .catch(() => { toast.error('Assignment not found'); navigate(-1); })
      .finally(() => setLoading(false));
  }, [classId, id]);

  const submit = async (e) => {
    e.preventDefault();
    if (!text.trim() && files.length === 0) return toast.error('Add text or attach a file');
    setSub(true);
    try {
      const fd = new FormData();
      if (text) fd.append('text_answer', text);
      files.forEach((f) => fd.append('files[]', f));
      await assignmentAPI.submit(classId, id, fd);
      toast.success('Assignment submitted!');
      const { data } = await assignmentAPI.get(classId, id);
      setAssignment(data.assignment);
    } catch (e) {
      toast.error(e.response?.data?.message || 'Submission failed');
    } finally { setSub(false); }
  };

  if (loading) return (
    <div className="flex items-center justify-center h-full">
      <div className="w-8 h-8 border-4 border-violet-600 border-t-transparent rounded-full animate-spin"/>
    </div>
  );
  if (!assignment) return null;

  const sub        = assignment.my_submission;
  const isGraded   = sub?.status === 'graded';
  const isSubmitted = sub && !isGraded;
  const isOverdue  = assignment.due_date && new Date(assignment.due_date) < new Date();

  return (
    <div className="max-w-3xl mx-auto p-4 sm:p-6 space-y-5">
      <button onClick={() => navigate(-1)} className="flex items-center gap-2 text-sm text-gray-500 hover:text-violet-600 transition-colors">
        <ArrowLeft size={15}/> Back to class
      </button>

      <motion.div initial={{ opacity:0, y:16 }} animate={{ opacity:1, y:0 }}
        className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-sm overflow-hidden">
        <div className="bg-gradient-to-r from-orange-500 to-amber-500 px-6 py-5">
          <h1 className="font-display font-bold text-xl text-white">{assignment.title}</h1>
          <div className="flex items-center gap-4 mt-2 text-white/80 text-sm flex-wrap">
            {assignment.due_date && (
              <span className="flex items-center gap-1">
                <Clock size={13}/>
                Due {format(new Date(assignment.due_date), 'MMM d, yyyy HH:mm')}
              </span>
            )}
            <span className="flex items-center gap-1"><Award size={13}/> {assignment.max_score} points</span>
          </div>
        </div>
        <div className="p-6">
          <div className="prose prose-sm dark:prose-invert max-w-none">
            <ReactMarkdown remarkPlugins={[remarkGfm]}>{assignment.description}</ReactMarkdown>
          </div>
          {assignment.files?.length > 0 && (
            <div className="mt-5 space-y-2">
              <p className="text-sm font-semibold text-gray-700 dark:text-gray-300">Reference Files</p>
              {assignment.files.map((f) => (
                <a key={f.id} href={f.url} target="_blank" rel="noreferrer"
                  className="flex items-center gap-3 p-3 bg-gray-50 dark:bg-gray-700 rounded-xl hover:bg-orange-50 dark:hover:bg-orange-900/20 transition-all group">
                  <FileText size={16} className="text-orange-500 flex-shrink-0"/>
                  <span className="text-sm text-gray-700 dark:text-gray-300 flex-1 truncate">{f.name}</span>
                  <Download size={14} className="text-gray-400 group-hover:text-orange-500"/>
                </a>
              ))}
            </div>
          )}
        </div>
      </motion.div>

      {isGraded && (
        <div className="bg-white dark:bg-gray-800 rounded-2xl border border-green-200 dark:border-green-800 p-5">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-xl bg-green-100 dark:bg-green-900/30 flex items-center justify-center">
              <CheckCircle2 size={20} className="text-green-600"/>
            </div>
            <div>
              <h3 className="font-semibold text-gray-900 dark:text-white">Graded</h3>
              <p className="text-sm text-gray-500">
                Score: <strong className="text-green-600">{sub.score}/{assignment.max_score}</strong>
                {' '}({Math.round((sub.score / assignment.max_score) * 100)}%)
              </p>
            </div>
          </div>
          {sub.feedback && (
            <p className="text-sm text-gray-600 dark:text-gray-300 bg-gray-50 dark:bg-gray-700 rounded-xl p-3">{sub.feedback}</p>
          )}
        </div>
      )}

      {!isTeacher && !isGraded && (
        <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 p-5">
          <h3 className="font-semibold text-gray-900 dark:text-white mb-4">
            {isSubmitted
              ? 'Your Submission (submitted — waiting for grade)'
              : isOverdue && !assignment.allow_late
                ? 'Deadline Passed'
                : 'Submit Your Work'}
          </h3>
          {isOverdue && !assignment.allow_late && !isSubmitted ? (
            <p className="text-sm text-red-500">The deadline has passed and late submissions are not allowed.</p>
          ) : (
            <form onSubmit={submit} className="space-y-4">
              <textarea
                value={isSubmitted ? (sub?.text_answer || '') : text}
                onChange={(e) => !isSubmitted && setText(e.target.value)}
                placeholder="Type your answer here…"
                rows={6}
                disabled={isSubmitted}
                className="w-full px-4 py-3 rounded-xl border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-sm outline-none focus:ring-2 focus:ring-violet-400 resize-none dark:text-white disabled:opacity-60"
              />
              {!isSubmitted && (
                <>
                  <div>
                    <input ref={fileRef} type="file" multiple className="hidden"
                      onChange={(e) => setFiles([...e.target.files])}/>
                    <button type="button" onClick={() => fileRef.current?.click()}
                      className="text-sm text-violet-600 hover:text-violet-700 font-medium">
                      + Attach files {files.length > 0 && `(${files.length} selected)`}
                    </button>
                  </div>
                  <button type="submit" disabled={submitting || (!text.trim() && files.length === 0)}
                    className="flex items-center gap-2 px-6 py-2.5 bg-violet-600 hover:bg-violet-700 disabled:opacity-50 text-white rounded-xl text-sm font-semibold transition-all">
                    {submitting ? <Loader2 size={14} className="animate-spin"/> : <Send size={14}/>}
                    {submitting ? 'Submitting…' : 'Submit Assignment'}
                  </button>
                </>
              )}
            </form>
          )}
        </div>
      )}
    </div>
  );
}
