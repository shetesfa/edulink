import React, { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import {
  BookOpen, Bookmark, BookmarkCheck, Download, MessageSquare,
  ArrowLeft, Send, Loader2, FileText, Eye,
} from 'lucide-react';
import { lessonAPI } from '@/utils/api';
import { useAuthStore } from '@/store';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { formatDistanceToNow } from 'date-fns';
import toast from 'react-hot-toast';
import clsx from 'clsx';

export default function LessonView() {
  const { classId, lessonId } = useParams();
  const { user }              = useAuthStore();
  const navigate              = useNavigate();

  const [lesson, setLesson]         = useState(null);
  const [comments, setComments]     = useState([]);
  const [bookmarked, setBookmarked] = useState(false);
  const [comment, setComment]       = useState('');
  const [posting, setPosting]       = useState(false);
  const [loading, setLoading]       = useState(true);
  const [showComments, setShowC]    = useState(false);

  useEffect(() => {
    Promise.all([
      lessonAPI.get(classId, lessonId),
      lessonAPI.getComments(classId, lessonId),
    ]).then(([{ data: ld }, { data: cd }]) => {
      setLesson(ld.lesson);
      setBookmarked(ld.lesson.is_bookmarked ?? false);
      setComments(cd.comments || []);
    }).catch(() => { toast.error('Failed to load lesson'); navigate(-1); })
      .finally(() => setLoading(false));
  }, [classId, lessonId]);

  const toggleBookmark = async () => {
    try {
      const { data } = await lessonAPI.bookmark(classId, lessonId);
      setBookmarked(data.bookmarked);
      toast.success(data.bookmarked ? 'Bookmarked!' : 'Bookmark removed');
    } catch { toast.error('Failed to update bookmark'); }
  };

  const postComment = async (e) => {
    e.preventDefault();
    if (!comment.trim()) return;
    setPosting(true);
    try {
      const { data } = await lessonAPI.addComment(classId, lessonId, { body: comment });
      setComments((p) => [data.comment, ...p]);
      setComment('');
    } catch { toast.error('Failed to post comment'); }
    finally { setPosting(false); }
  };

  if (loading) return (
    <div className="flex items-center justify-center h-full">
      <div className="w-8 h-8 border-4 border-violet-600 border-t-transparent rounded-full animate-spin"/>
    </div>
  );
  if (!lesson) return null;

  return (
    <div className="max-w-3xl mx-auto p-4 sm:p-6 space-y-5">
      <button onClick={() => navigate(-1)} className="flex items-center gap-2 text-sm text-gray-500 hover:text-violet-600 transition-colors">
        <ArrowLeft size={15}/> Back to class
      </button>

      <motion.div initial={{ opacity:0, y:16 }} animate={{ opacity:1, y:0 }}
        className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-sm overflow-hidden">
        <div className="bg-gradient-to-r from-violet-600 to-violet-800 px-6 py-5">
          <div className="flex items-start justify-between gap-4">
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-xl bg-white/20 flex items-center justify-center flex-shrink-0">
                <BookOpen size={20} className="text-white"/>
              </div>
              <div>
                <h1 className="font-display font-bold text-xl text-white">{lesson.title}</h1>
                <p className="text-white/70 text-sm mt-0.5">
                  by {lesson.teacher?.full_name} · {formatDistanceToNow(new Date(lesson.created_at), { addSuffix: true })}
                </p>
              </div>
            </div>
            <button onClick={toggleBookmark} className="p-2 bg-white/20 hover:bg-white/30 rounded-xl transition-all flex-shrink-0">
              {bookmarked
                ? <BookmarkCheck size={18} className="text-amber-300"/>
                : <Bookmark size={18} className="text-white"/>}
            </button>
          </div>
        </div>

        {lesson.description && (
          <div className="px-6 py-4 border-b border-gray-100 dark:border-gray-700 bg-gray-50 dark:bg-gray-700/40">
            <p className="text-sm text-gray-600 dark:text-gray-300">{lesson.description}</p>
          </div>
        )}

        {lesson.content && (
          <div className="px-6 py-5">
            <div className="prose prose-sm dark:prose-invert max-w-none">
              <ReactMarkdown remarkPlugins={[remarkGfm]}>{lesson.content}</ReactMarkdown>
            </div>
          </div>
        )}

        {lesson.files?.length > 0 && (
          <div className="px-6 pb-5">
            <h3 className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">Attached Files</h3>
            <div className="space-y-2">
              {lesson.files.map((file) => (
                <a key={file.id} href={file.url} download target="_blank" rel="noreferrer"
                  className="flex items-center gap-3 p-3 bg-gray-50 dark:bg-gray-700 hover:bg-violet-50 dark:hover:bg-violet-900/20 rounded-xl border border-gray-200 dark:border-gray-600 hover:border-violet-300 group transition-all">
                  <div className="w-9 h-9 rounded-lg bg-violet-100 dark:bg-violet-900/30 flex items-center justify-center flex-shrink-0">
                    <FileText size={16} className="text-violet-600"/>
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-800 dark:text-white truncate">{file.name}</p>
                    <p className="text-xs text-gray-400">{file.size ? (file.size / 1024).toFixed(0) + ' KB' : ''}</p>
                  </div>
                  <Download size={15} className="text-gray-400 group-hover:text-violet-500 transition-colors"/>
                </a>
              ))}
            </div>
          </div>
        )}
      </motion.div>

      {lesson.allow_comments && (
        <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-sm p-5">
          <button onClick={() => setShowC(!showComments)}
            className="flex items-center gap-2 text-sm font-semibold text-gray-700 dark:text-gray-300 mb-4 hover:text-violet-600 transition-colors">
            <MessageSquare size={16}/> Comments ({comments.length}) {showComments ? '▲' : '▼'}
          </button>
          {showComments && (
            <>
              <form onSubmit={postComment} className="flex gap-3 mb-5">
                <div className="w-8 h-8 rounded-full bg-gradient-to-br from-violet-400 to-violet-600 flex items-center justify-center text-white text-xs font-bold flex-shrink-0">
                  {user?.first_name?.[0]}
                </div>
                <div className="flex-1 flex gap-2">
                  <input value={comment} onChange={(e) => setComment(e.target.value)}
                    placeholder="Write a comment…"
                    className="flex-1 px-4 py-2 rounded-xl border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-sm outline-none focus:ring-2 focus:ring-violet-400 dark:text-white"/>
                  <button type="submit" disabled={posting || !comment.trim()}
                    className="px-3 py-2 bg-violet-600 hover:bg-violet-700 disabled:opacity-50 text-white rounded-xl transition-all">
                    {posting ? <Loader2 size={14} className="animate-spin"/> : <Send size={14}/>}
                  </button>
                </div>
              </form>
              <div className="space-y-4">
                {comments.map((c) => (
                  <div key={c.id} className="flex gap-3">
                    <div className="w-8 h-8 rounded-full bg-gradient-to-br from-violet-400 to-violet-600 flex items-center justify-center text-white text-xs font-bold flex-shrink-0">
                      {c.user?.full_name?.[0]}
                    </div>
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-1">
                        <span className="text-sm font-semibold text-gray-800 dark:text-white">{c.user?.full_name}</span>
                        <span className="text-xs text-gray-400">{formatDistanceToNow(new Date(c.created_at), { addSuffix: true })}</span>
                      </div>
                      <p className="text-sm text-gray-600 dark:text-gray-300">{c.body}</p>
                    </div>
                  </div>
                ))}
                {comments.length === 0 && (
                  <p className="text-sm text-gray-400 text-center py-4">No comments yet. Be the first!</p>
                )}
              </div>
            </>
          )}
        </div>
      )}
    </div>
  );
}
