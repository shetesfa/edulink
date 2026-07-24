/**
 * EduLink — Create Assignment
 * ─────────────────────────────────────────────────────────────
 * Teachers can create an assignment with title, description,
 * due date, max score, late submission toggle, and file attachments.
 */

import React, { useState, useRef } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import {
  ChevronLeft, CheckCircle2, FileText, Upload, X,
  Calendar, Award, Clock, ToggleLeft, ToggleRight,
  Loader2, Paperclip, AlertTriangle,
} from 'lucide-react';
import { assignmentAPI } from '@/utils/api';
import toast from 'react-hot-toast';
import clsx from 'clsx';

export default function AssignmentCreate() {
  const { classId } = useParams();
  const navigate    = useNavigate();
  const fileRef     = useRef(null);

  // ── Form state ──
  const [title,       setTitle]       = useState('');
  const [description, setDescription] = useState('');
  const [dueDate,     setDueDate]     = useState('');
  const [maxScore,    setMaxScore]    = useState(100);
  const [allowLate,   setAllowLate]   = useState(false);
  const [files,       setFiles]       = useState([]);
  const [saving,      setSaving]      = useState(false);

  // ── File handling ──
  const handleFileSelect = (e) => {
    const selected = Array.from(e.target.files || []);
    setFiles(prev => [...prev, ...selected]);
    e.target.value = '';
  };

  const removeFile = (idx) =>
    setFiles(prev => prev.filter((_, i) => i !== idx));

  const formatSize = (bytes) => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  // ── Submit ──
  const handleSave = async () => {
    if (!title.trim()) { toast.error('Assignment title is required.'); return; }

    setSaving(true);
    try {
      const fd = new FormData();
      fd.append('title',       title.trim());
      fd.append('description', description.trim());
      fd.append('max_score',   maxScore);
      fd.append('allow_late',  allowLate ? '1' : '0');
      if (dueDate) fd.append('due_date', dueDate);
      files.forEach(f => fd.append('attachments[]', f));

      await assignmentAPI.create(classId, fd);
      toast.success('Assignment created!');
      navigate(`/classes/${classId}`, { state: { tab: 'assignments' } });
    } catch (err) {
      const msg = err?.response?.data?.message || 'Failed to create assignment.';
      toast.error(msg);
    } finally {
      setSaving(false);
    }
  };

  // ── Render ──
  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 pb-20">

      {/* ── Sticky Header ── */}
      <div className="sticky top-0 z-30 bg-white/80 dark:bg-gray-900/80 backdrop-blur border-b border-gray-200 dark:border-gray-800">
        <div className="max-w-3xl mx-auto px-4 py-3 flex items-center justify-between gap-4">
          <Link
            to={`/classes/${classId}`}
            className="flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-900 dark:hover:text-white transition-colors"
          >
            <ChevronLeft className="w-4 h-4" /> Back to class
          </Link>

          <div className="flex items-center gap-2">
            <FileText className="w-5 h-5 text-brand-500" />
            <span className="font-semibold text-gray-900 dark:text-white text-sm hidden sm:block">New Assignment</span>
          </div>

          <button
            onClick={handleSave}
            disabled={saving}
            className="flex items-center gap-2 px-4 py-2 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white text-sm font-semibold rounded-xl transition-all"
          >
            {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <CheckCircle2 className="w-4 h-4" />}
            {saving ? 'Saving…' : 'Publish'}
          </button>
        </div>
      </div>

      {/* ── Form ── */}
      <div className="max-w-3xl mx-auto px-4 pt-8 space-y-5">

        {/* Main details card */}
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-200 dark:border-gray-800 p-6 shadow-sm space-y-5"
        >
          <h2 className="font-bold text-lg text-gray-900 dark:text-white">Assignment Details</h2>

          {/* Title */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">
              Title <span className="text-red-500">*</span>
            </label>
            <input
              value={title}
              onChange={e => setTitle(e.target.value)}
              placeholder="e.g. Chapter 5 Homework"
              className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
          </div>

          {/* Description */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">
              Instructions <span className="text-gray-400 text-xs font-normal">(optional)</span>
            </label>
            <textarea
              value={description}
              onChange={e => setDescription(e.target.value)}
              rows={4}
              placeholder="Write clear instructions for students. You can describe the task, requirements, and grading criteria…"
              className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white text-sm resize-none focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
          </div>

          {/* Due date + Max score row */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5 flex items-center gap-1.5">
                <Calendar className="w-4 h-4 text-gray-400" /> Due Date <span className="text-gray-400 text-xs font-normal">(optional)</span>
              </label>
              <input
                type="datetime-local"
                value={dueDate}
                onChange={e => setDueDate(e.target.value)}
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5 flex items-center gap-1.5">
                <Award className="w-4 h-4 text-gray-400" /> Max Score
              </label>
              <input
                type="number"
                min="1"
                max="1000"
                value={maxScore}
                onChange={e => setMaxScore(parseInt(e.target.value) || 100)}
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>
          </div>

          {/* Allow late toggle */}
          <div>
            <button
              onClick={() => setAllowLate(v => !v)}
              className={clsx(
                'flex items-center gap-2.5 px-4 py-2.5 rounded-xl border-2 text-sm font-medium transition-all',
                allowLate
                  ? 'border-brand-400 bg-brand-50 dark:bg-brand-900/20 text-brand-700 dark:text-brand-300'
                  : 'border-gray-200 dark:border-gray-700 text-gray-500 dark:text-gray-400 hover:border-gray-300'
              )}
            >
              {allowLate ? <ToggleRight className="w-5 h-5" /> : <ToggleLeft className="w-5 h-5" />}
              <Clock className="w-4 h-4" />
              Allow late submissions
            </button>
            {allowLate && (
              <p className="text-xs text-amber-500 mt-1.5 flex items-center gap-1">
                <AlertTriangle className="w-3.5 h-3.5" /> Late submissions will be tagged and may affect the student's grade.
              </p>
            )}
          </div>
        </motion.div>

        {/* File attachments card */}
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.06 }}
          className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-200 dark:border-gray-800 p-6 shadow-sm space-y-4"
        >
          <h2 className="font-bold text-base text-gray-900 dark:text-white">Attachments <span className="text-gray-400 text-sm font-normal">(optional)</span></h2>

          {/* Drop zone */}
          <div
            onClick={() => fileRef.current?.click()}
            className="border-2 border-dashed border-gray-200 dark:border-gray-700 rounded-xl p-6 flex flex-col items-center gap-2 cursor-pointer hover:border-brand-400 hover:bg-brand-50/50 dark:hover:bg-brand-900/10 transition-all"
          >
            <Upload className="w-8 h-8 text-gray-300 dark:text-gray-600" />
            <p className="text-sm text-gray-500 dark:text-gray-400 text-center">
              Click to attach files <span className="text-gray-400 text-xs">(PDF, images, docs — max 20 MB each)</span>
            </p>
            <input
              ref={fileRef}
              type="file"
              multiple
              className="hidden"
              onChange={handleFileSelect}
            />
          </div>

          {/* File list */}
          <AnimatePresence>
            {files.map((file, idx) => (
              <motion.div
                key={idx}
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                exit={{ opacity: 0, height: 0 }}
                className="flex items-center gap-3 px-4 py-2.5 rounded-xl bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700"
              >
                <Paperclip className="w-4 h-4 text-gray-400 flex-shrink-0" />
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-gray-700 dark:text-gray-300 truncate">{file.name}</p>
                  <p className="text-xs text-gray-400">{formatSize(file.size)}</p>
                </div>
                <button
                  onClick={() => removeFile(idx)}
                  className="p-1 text-gray-400 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors"
                >
                  <X className="w-4 h-4" />
                </button>
              </motion.div>
            ))}
          </AnimatePresence>
        </motion.div>
      </div>
    </div>
  );
}
