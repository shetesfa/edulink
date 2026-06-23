import React, { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import {
  BookOpen, FileText, Brain, Megaphone, Users, Video,
  Plus, Copy, Check, ArrowLeft, ChevronRight, Clock,
  Award, Eye, Trash2, Send, Loader2, Bell, Pin, MessageSquare,
} from 'lucide-react';
import { classAPI, lessonAPI, assignmentAPI, quizAPI } from '@/utils/api';
import axios from 'axios';
import { useAuthStore } from '@/store';
import { format, formatDistanceToNow } from 'date-fns';
import toast from 'react-hot-toast';
import clsx from 'clsx';

const TABS = [
  { id: 'lessons',       icon: BookOpen,  label: 'Lessons' },
  { id: 'assignments',   icon: FileText,  label: 'Assignments' },
  { id: 'quizzes',       icon: Brain,     label: 'Quizzes' },
  { id: 'announcements', icon: Megaphone, label: 'Announcements' },
  { id: 'students',      icon: Users,     label: 'Students' },
];

const apiBase = axios.create({ baseURL: import.meta.env.VITE_API_URL || '/api' });
apiBase.interceptors.request.use((cfg) => {
  const s = localStorage.getItem('edulink-auth');
  if (s) { const { state } = JSON.parse(s); if (state?.token) cfg.headers.Authorization = `Bearer ${state.token}`; }
  return cfg;
});

export default function ClassDetail() {
  const { classId } = useParams();
  const { user }    = useAuthStore();
  const navigate    = useNavigate();

  const [cls, setCls]           = useState(null);
  const [tab, setTab]           = useState('lessons');
  const [lessons, setLessons]   = useState([]);
  const [assignments, setAsgns] = useState([]);
  const [quizzes, setQuizzes]   = useState([]);
  const [announcements, setAnns]= useState([]);
  const [students, setStudents] = useState([]);
  const [loading, setLoading]   = useState(true);
  const [codeCopied, setCode]   = useState(false);

  const isTeacher = user?.role === 'teacher' || user?.role === 'school_admin';

  useEffect(() => {
    classAPI.get(classId).then(({ data }) => setCls(data.class)).finally(() => setLoading(false));
  }, [classId]);

  useEffect(() => {
    if (!classId) return;
    if (tab === 'lessons')       lessonAPI.list(classId).then(({ data }) => setLessons(data.lessons || []));
    if (tab === 'assignments')   assignmentAPI.list(classId).then(({ data }) => setAsgns(data.assignments || []));
    if (tab === 'quizzes')       quizAPI.list(classId).then(({ data }) => setQuizzes(data.quizzes || []));
    if (tab === 'announcements') apiBase.get(`/classes/${classId}/announcements`).then(({ data }) => setAnns(data.announcements || []));
    if (tab === 'students')      classAPI.students(classId).then(({ data }) => setStudents(data.students || []));
  }, [tab, classId]);

  const copyCode = () => {
    navigator.clipboard.writeText(cls?.join_code);
    setCode(true); toast.success('Join code copied!');
    setTimeout(() => setCode(false), 2000);
  };

  if (loading) return <ClassSkeleton />;
  if (!cls)    return <div className="p-8 text-center text-gray-400">Class not found.</div>;

  return (
    <div className="flex flex-col h-full">
      {/* Banner */}
      <div className="relative overflow-hidden flex-shrink-0"
        style={{ background: cls.cover_photo ? `url(${cls.cover_photo}) center/cover` : `linear-gradient(135deg,${cls.color||'#7C3AED'},#1E1B4B)` }}>
        <div className="absolute inset-0 bg-black/45" />
        <div className="relative z-10 px-4 sm:px-6 py-5">
          <button onClick={() => navigate('/classes')} className="flex items-center gap-1.5 text-white/70 hover:text-white text-sm mb-4 transition-colors">
            <ArrowLeft size={15} /> All Classes
          </button>
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h1 className="font-display font-bold text-2xl text-white">{cls.name}</h1>
              <p className="text-white/65 text-sm mt-0.5">{cls.subject}{cls.grade ? ` · ${cls.grade.name}` : ''} · by {cls.teacher?.full_name}</p>
              <p className="text-white/50 text-xs mt-1">{cls.enrollments_count || 0} students enrolled</p>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <button onClick={copyCode} className="flex items-center gap-1.5 bg-white/15 hover:bg-white/25 backdrop-blur border border-white/20 text-white text-sm font-mono px-3 py-1.5 rounded-xl transition-all">
                {codeCopied ? <Check size={13}/> : <Copy size={13}/>} {cls.join_code}
              </button>
              <Link to={`/chat/group/${classId}`} className="flex items-center gap-1.5 bg-white/15 hover:bg-white/25 backdrop-blur border border-white/20 text-white text-sm px-3 py-1.5 rounded-xl transition-all">
                <MessageSquare size={13}/> Chat
              </Link>
              <Link to="/meetings" className="flex items-center gap-1.5 bg-white/15 hover:bg-white/25 backdrop-blur border border-white/20 text-white text-sm px-3 py-1.5 rounded-xl transition-all">
                <Video size={13}/> Meet
              </Link>
            </div>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 flex-shrink-0">
        <div className="flex overflow-x-auto">
          {TABS.map((t) => (
            <button key={t.id} onClick={() => setTab(t.id)}
              className={clsx('flex items-center gap-2 px-4 sm:px-5 py-3.5 text-sm font-medium border-b-2 transition-all whitespace-nowrap',
                tab === t.id ? 'border-brand-600 text-brand-600 dark:text-brand-400' : 'border-transparent text-gray-500 hover:text-gray-700 dark:hover:text-gray-300')}>
              <t.icon size={15}/> <span className="hidden sm:inline">{t.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto p-4 sm:p-6">
        <AnimatePresence mode="wait">
          <motion.div key={tab} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.15 }}>
            {tab === 'lessons'       && <LessonsTab       lessons={lessons}           classId={classId} isTeacher={isTeacher} setLessons={setLessons}/>}
            {tab === 'assignments'   && <AssignmentsTab   assignments={assignments}   classId={classId} isTeacher={isTeacher} user={user}/>}
            {tab === 'quizzes'       && <QuizzesTab       quizzes={quizzes}           classId={classId} isTeacher={isTeacher}/>}
            {tab === 'announcements' && <AnnouncementsTab announcements={announcements} classId={classId} isTeacher={isTeacher} setAnns={setAnns}/>}
            {tab === 'students'      && <StudentsTab      students={students}         classId={classId} isTeacher={isTeacher}/>}
          </motion.div>
        </AnimatePresence>
      </div>
    </div>
  );
}

/* ── LESSONS ─────────────────────────────────────────────── */
function LessonsTab({ lessons, classId, isTeacher, setLessons }) {
  const [form, setForm]       = useState({ title: '', description: '', files: [] });
  const [showForm, setShow]   = useState(false);
  const [uploading, setUpl]   = useState(false);
  const fileRef               = useRef();

  const submit = async (e) => {
    e.preventDefault();
    if (!form.title.trim()) return toast.error('Title is required');
    setUpl(true);
    try {
      const fd = new FormData();
      fd.append('title', form.title);
      fd.append('description', form.description);
      form.files.forEach((f) => fd.append('files[]', f));
      const { data } = await lessonAPI.create(classId, fd);
      setLessons((p) => [...p, data.lesson]);
      setForm({ title: '', description: '', files: [] }); setShow(false);
      toast.success('Lesson created!');
    } catch { toast.error('Upload failed'); } finally { setUpl(false); }
  };

  const del = async (id) => {
    if (!confirm('Delete this lesson?')) return;
    await lessonAPI.delete(classId, id);
    setLessons((p) => p.filter((l) => l.id !== id));
    toast.success('Deleted');
  };

  return (
    <div className="max-w-3xl space-y-4">
      {isTeacher && (
        <div className="flex justify-end">
          <button onClick={() => setShow(!showForm)} className="flex items-center gap-2 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white rounded-xl text-sm font-semibold transition-all">
            <Plus size={15}/> {showForm ? 'Cancel' : 'Upload Lesson'}
          </button>
        </div>
      )}
      <AnimatePresence>
        {showForm && (
          <motion.form initial={{ opacity:0, height:0 }} animate={{ opacity:1, height:'auto' }} exit={{ opacity:0, height:0 }}
            onSubmit={submit} className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-200 dark:border-gray-700 p-5 space-y-3 overflow-hidden">
            <h3 className="font-semibold text-gray-900 dark:text-white">New Lesson</h3>
            <input value={form.title} onChange={(e) => setForm({...form,title:e.target.value})} placeholder="Title *" required
              className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-sm outline-none focus:ring-2 focus:ring-brand-400 dark:text-white"/>
            <textarea value={form.description} onChange={(e) => setForm({...form,description:e.target.value})} placeholder="Description" rows={3}
              className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-sm outline-none focus:ring-2 focus:ring-brand-400 resize-none dark:text-white"/>
            <div>
              <input ref={fileRef} type="file" multiple className="hidden" onChange={(e) => setForm({...form,files:[...e.target.files]})}/>
              <button type="button" onClick={() => fileRef.current?.click()} className="text-sm text-brand-600 font-medium">
                + Attach files {form.files.length > 0 && `(${form.files.length} selected)`}
              </button>
            </div>
            <button type="submit" disabled={uploading} className="flex items-center gap-2 px-5 py-2 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white text-sm font-semibold rounded-xl">
              {uploading ? <Loader2 size={14} className="animate-spin"/> : <Plus size={14}/>} {uploading ? 'Uploading…' : 'Create'}
            </button>
          </motion.form>
        )}
      </AnimatePresence>
      {lessons.length === 0 ? <Empty icon={BookOpen} title="No lessons yet" desc={isTeacher ? 'Upload your first lesson.' : 'No lessons posted yet.'}/> :
        lessons.map((l, i) => (
          <motion.div key={l.id} initial={{ opacity:0,x:-10 }} animate={{ opacity:1,x:0 }} transition={{ delay:i*0.04 }}>
            <Link to={`/classes/${classId}/lessons/${l.id}`}
              className="flex items-center gap-4 p-4 bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 hover:border-brand-300 hover:shadow-card-hover group transition-all">
              <div className="w-12 h-12 rounded-xl bg-brand-100 dark:bg-brand-900/30 flex items-center justify-center flex-shrink-0">
                <BookOpen size={20} className="text-brand-600"/>
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <h3 className="font-semibold text-gray-900 dark:text-white group-hover:text-brand-600 transition-colors truncate">{l.title}</h3>
                  {!l.is_published && <span className="text-xs bg-orange-100 text-orange-600 px-2 py-0.5 rounded-full font-medium flex-shrink-0">Draft</span>}
                </div>
                {l.description && <p className="text-sm text-gray-400 mt-0.5 truncate">{l.description}</p>}
                <div className="flex items-center gap-3 mt-1 text-xs text-gray-400">
                  <span className="flex items-center gap-1"><Eye size={11}/> {l.views}</span>
                  {l.files?.length > 0 && <span className="flex items-center gap-1"><FileText size={11}/> {l.files.length} files</span>}
                  <span>{formatDistanceToNow(new Date(l.created_at),{addSuffix:true})}</span>
                </div>
              </div>
              <div className="flex items-center gap-1">
                {isTeacher && <button onClick={(e)=>{e.preventDefault();del(l.id);}} className="p-1.5 text-gray-300 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg opacity-0 group-hover:opacity-100 transition-all"><Trash2 size={14}/></button>}
                <ChevronRight size={18} className="text-gray-300 group-hover:text-brand-500 transition-colors"/>
              </div>
            </Link>
          </motion.div>
        ))
      }
    </div>
  );
}

/* ── ASSIGNMENTS ─────────────────────────────────────────── */
function AssignmentsTab({ assignments, classId, isTeacher }) {
  return (
    <div className="max-w-3xl space-y-4">
      {isTeacher && (
        <div className="flex justify-end">
          <Link to={`/classes/${classId}/assignments/new`} className="flex items-center gap-2 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white rounded-xl text-sm font-semibold transition-all">
            <Plus size={15}/> New Assignment
          </Link>
        </div>
      )}
      {assignments.length === 0 ? <Empty icon={FileText} title="No assignments" desc={isTeacher ? 'Create your first assignment.' : 'No assignments posted yet.'}/> :
        assignments.map((a, i) => {
          const isOverdue   = a.due_date && new Date(a.due_date) < new Date() && !a.my_submission;
          const isSubmitted = ['submitted','late'].includes(a.my_submission?.status);
          const isGraded    = a.my_submission?.status === 'graded';
          return (
            <motion.div key={a.id} initial={{ opacity:0,x:-10 }} animate={{ opacity:1,x:0 }} transition={{ delay:i*0.04 }}>
              <Link to={`/classes/${classId}/assignments/${a.id}`}
                className="flex items-start gap-4 p-4 bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 hover:border-brand-300 hover:shadow-card-hover group transition-all">
                <div className={clsx('w-12 h-12 rounded-xl flex items-center justify-center flex-shrink-0 mt-0.5',
                  isGraded?'bg-green-100 dark:bg-green-900/30':isSubmitted?'bg-blue-100 dark:bg-blue-900/30':isOverdue?'bg-red-100 dark:bg-red-900/30':'bg-orange-100 dark:bg-orange-900/30')}>
                  <FileText size={20} className={clsx(isGraded?'text-green-600':isSubmitted?'text-blue-600':isOverdue?'text-red-500':'text-orange-500')}/>
                </div>
                <div className="flex-1 min-w-0">
                  <h3 className="font-semibold text-gray-900 dark:text-white group-hover:text-brand-600 transition-colors">{a.title}</h3>
                  <p className="text-sm text-gray-400 mt-0.5 line-clamp-1">{a.description}</p>
                  <div className="flex items-center gap-3 mt-2 flex-wrap text-xs">
                    {a.due_date && <span className={clsx('flex items-center gap-1 font-medium',isOverdue?'text-red-500':'text-gray-400')}><Clock size={11}/> Due {format(new Date(a.due_date),'MMM d, HH:mm')}</span>}
                    <span className="text-gray-400 flex items-center gap-1"><Award size={11}/> {a.max_score} pts</span>
                    {isGraded && <span className="bg-green-100 text-green-700 font-semibold px-2 py-0.5 rounded-full">{a.my_submission.score}/{a.max_score}</span>}
                    {isSubmitted && !isGraded && <span className="bg-blue-100 text-blue-700 font-semibold px-2 py-0.5 rounded-full">Submitted</span>}
                    {!a.my_submission && isOverdue && <span className="bg-red-100 text-red-600 font-medium px-2 py-0.5 rounded-full">Overdue</span>}
                  </div>
                </div>
                <ChevronRight size={18} className="text-gray-300 group-hover:text-brand-500 transition-colors flex-shrink-0 mt-1"/>
              </Link>
            </motion.div>
          );
        })
      }
    </div>
  );
}

/* ── QUIZZES ─────────────────────────────────────────────── */
function QuizzesTab({ quizzes, classId, isTeacher }) {
  return (
    <div className="max-w-3xl space-y-4">
      {isTeacher && (
        <div className="flex justify-end">
          <Link to={`/classes/${classId}/quizzes/new`} className="flex items-center gap-2 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white rounded-xl text-sm font-semibold transition-all">
            <Plus size={15}/> Create Quiz
          </Link>
        </div>
      )}
      {quizzes.length === 0 ? <Empty icon={Brain} title="No quizzes" desc={isTeacher ? 'Create your first quiz.' : 'No quizzes posted yet.'}/> :
        quizzes.map((q, i) => {
          const attempt = q.my_attempt;
          const canTake = (q.attempts_used||0) < q.max_attempts;
          const isOpen  = (!q.opens_at||new Date(q.opens_at)<=new Date())&&(!q.closes_at||new Date(q.closes_at)>=new Date());
          return (
            <motion.div key={q.id} initial={{ opacity:0,x:-10 }} animate={{ opacity:1,x:0 }} transition={{ delay:i*0.04 }}>
              <div className="flex items-start gap-4 p-4 bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 hover:border-brand-200 transition-all">
                <div className={clsx('w-12 h-12 rounded-xl flex items-center justify-center flex-shrink-0',
                  attempt?.passed?'bg-green-100 dark:bg-green-900/30':attempt?'bg-orange-100 dark:bg-orange-900/30':'bg-brand-100 dark:bg-brand-900/30')}>
                  <Brain size={20} className={clsx(attempt?.passed?'text-green-600':attempt?'text-orange-500':'text-brand-600')}/>
                </div>
                <div className="flex-1 min-w-0">
                  <h3 className="font-semibold text-gray-900 dark:text-white">{q.title}</h3>
                  <div className="flex flex-wrap items-center gap-3 mt-1 text-xs text-gray-400">
                    <span>{q.questions_count} questions</span>
                    {q.time_limit && <span className="flex items-center gap-1"><Clock size={11}/> {q.time_limit} min</span>}
                    <span>{q.attempts_used||0}/{q.max_attempts} attempts</span>
                    {attempt && <span className={clsx('font-semibold px-2 py-0.5 rounded-full',attempt.passed?'bg-green-100 text-green-700':'bg-red-100 text-red-600')}>{attempt.percentage}% {attempt.passed?'✓ Passed':'✗ Failed'}</span>}
                  </div>
                </div>
                <div className="flex-shrink-0">
                  {isTeacher
                    ? <Link to={`/classes/${classId}/quizzes/${q.id}/analytics`} className="text-xs text-brand-600 hover:text-brand-700 font-medium">Analytics →</Link>
                    : canTake && isOpen
                      ? <Link to={`/classes/${classId}/quizzes/${q.id}/take`} className="px-3 py-1.5 bg-brand-600 hover:bg-brand-700 text-white text-sm font-semibold rounded-xl transition-all">{attempt?'Retry':'Start'}</Link>
                      : <span className="px-3 py-1.5 bg-gray-100 dark:bg-gray-700 text-gray-400 text-sm rounded-xl">{!isOpen?'Closed':'Done'}</span>
                  }
                </div>
              </div>
            </motion.div>
          );
        })
      }
    </div>
  );
}

/* ── ANNOUNCEMENTS ───────────────────────────────────────── */
function AnnouncementsTab({ announcements, classId, isTeacher, setAnns }) {
  const [title, setTitle]     = useState('');
  const [body, setBody]       = useState('');
  const [showForm, setShow]   = useState(false);
  const [posting, setPosting] = useState(false);

  const post = async (e) => {
    e.preventDefault();
    if (!title.trim()||!body.trim()) return toast.error('Title and message required');
    setPosting(true);
    try {
      const { data } = await apiBase.post(`/classes/${classId}/announcements`, { title, body });
      setAnns((p) => [data.announcement, ...p]);
      setTitle(''); setBody(''); setShow(false);
      toast.success('Announcement posted!');
    } catch { toast.error('Failed to post'); } finally { setPosting(false); }
  };

  const del = async (id) => {
    if (!confirm('Delete this announcement?')) return;
    await apiBase.delete(`/classes/${classId}/announcements/${id}`);
    setAnns((p) => p.filter((a) => a.id !== id));
    toast.success('Deleted');
  };

  return (
    <div className="max-w-3xl space-y-4">
      {isTeacher && (
        <div className="flex justify-end">
          <button onClick={() => setShow(!showForm)} className="flex items-center gap-2 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white rounded-xl text-sm font-semibold transition-all">
            <Plus size={15}/> {showForm ? 'Cancel' : 'New Announcement'}
          </button>
        </div>
      )}
      <AnimatePresence>
        {showForm && (
          <motion.form initial={{ opacity:0,height:0 }} animate={{ opacity:1,height:'auto' }} exit={{ opacity:0,height:0 }}
            onSubmit={post} className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-200 dark:border-gray-700 p-5 space-y-3 overflow-hidden">
            <h3 className="font-semibold text-gray-900 dark:text-white flex items-center gap-2"><Bell size={15} className="text-brand-600"/> Post Announcement</h3>
            <input value={title} onChange={(e)=>setTitle(e.target.value)} placeholder="Title *" required
              className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-sm outline-none focus:ring-2 focus:ring-brand-400 dark:text-white"/>
            <textarea value={body} onChange={(e)=>setBody(e.target.value)} placeholder="Message *" rows={4} required
              className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-sm outline-none focus:ring-2 focus:ring-brand-400 resize-none dark:text-white"/>
            <button type="submit" disabled={posting} className="flex items-center gap-2 px-5 py-2 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white text-sm font-semibold rounded-xl">
              {posting?<Loader2 size={14} className="animate-spin"/>:<Send size={14}/>} {posting?'Posting…':'Post'}
            </button>
          </motion.form>
        )}
      </AnimatePresence>
      {announcements.length === 0 ? <Empty icon={Megaphone} title="No announcements" desc={isTeacher?'Post above.':'Nothing posted yet.'}/> :
        announcements.map((ann, i) => (
          <motion.div key={ann.id} initial={{ opacity:0,y:8 }} animate={{ opacity:1,y:0 }} transition={{ delay:i*0.05 }}>
            <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 p-5 group">
              <div className="flex items-start justify-between gap-3">
                <div className="flex items-start gap-3 flex-1 min-w-0">
                  <div className="w-9 h-9 rounded-xl bg-amber-100 dark:bg-amber-900/30 flex items-center justify-center flex-shrink-0">
                    <Megaphone size={16} className="text-amber-600"/>
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <h3 className="font-semibold text-gray-900 dark:text-white">{ann.title}</h3>
                      {ann.is_pinned && <Pin size={12} className="text-amber-500"/>}
                    </div>
                    <p className="text-sm text-gray-600 dark:text-gray-300 mt-2 whitespace-pre-wrap leading-relaxed">{ann.body}</p>
                    <div className="flex items-center gap-3 mt-3 text-xs text-gray-400">
                      <span>{ann.author?.full_name}</span><span>·</span>
                      <span>{formatDistanceToNow(new Date(ann.created_at),{addSuffix:true})}</span>
                    </div>
                  </div>
                </div>
                {isTeacher && (
                  <button onClick={() => del(ann.id)} className="p-1.5 text-gray-300 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg opacity-0 group-hover:opacity-100 transition-all flex-shrink-0">
                    <Trash2 size={14}/>
                  </button>
                )}
              </div>
            </div>
          </motion.div>
        ))
      }
    </div>
  );
}

/* ── STUDENTS ────────────────────────────────────────────── */
function StudentsTab({ students, classId, isTeacher }) {
  const [search, setSearch] = useState('');
  const filtered = students.filter((s) => s.full_name.toLowerCase().includes(search.toLowerCase()));
  return (
    <div className="max-w-3xl space-y-3">
      <input value={search} onChange={(e)=>setSearch(e.target.value)} placeholder="Search students…"
        className="w-full px-4 py-2.5 text-sm bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl outline-none focus:ring-2 focus:ring-brand-400 dark:text-white"/>
      {filtered.length === 0 ? <Empty icon={Users} title="No students" desc="No one joined yet."/> :
        filtered.map((s, i) => (
          <motion.div key={s.id} initial={{ opacity:0,x:-8 }} animate={{ opacity:1,x:0 }} transition={{ delay:i*0.03 }}>
            <div className="flex items-center gap-3 p-3 bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 group">
              <div className="relative flex-shrink-0">
                <div className="w-10 h-10 rounded-full bg-gradient-to-br from-brand-400 to-brand-700 flex items-center justify-center text-white font-bold text-sm">
                  {s.full_name?.[0]?.toUpperCase()}
                </div>
                {s.is_online && <span className="absolute bottom-0 right-0 w-3 h-3 bg-green-400 border-2 border-white dark:border-gray-800 rounded-full"/>}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <p className="font-medium text-sm text-gray-900 dark:text-white">{s.full_name}</p>
                  {s.is_class_leader && <span className="text-xs bg-amber-100 text-amber-700 px-1.5 py-0.5 rounded-full font-medium">Leader</span>}
                </div>
                <div className="flex items-center gap-2 mt-1">
                  <div className="flex-1 h-1.5 bg-gray-100 dark:bg-gray-700 rounded-full overflow-hidden max-w-28">
                    <div className="h-full bg-brand-500 rounded-full" style={{ width:`${s.progress||0}%` }}/>
                  </div>
                  <span className="text-xs text-gray-400">{s.progress||0}%</span>
                </div>
              </div>
              {isTeacher && (
                <button onClick={() => { if(confirm('Remove?')) classAPI.removeStudent(classId,s.id).then(()=>window.location.reload()); }}
                  className="p-1.5 text-gray-300 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg opacity-0 group-hover:opacity-100 transition-all">
                  <Trash2 size={14}/>
                </button>
              )}
            </div>
          </motion.div>
        ))
      }
    </div>
  );
}

function Empty({ icon: Icon, title, desc }) {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center">
      <div className="w-16 h-16 rounded-2xl bg-gray-100 dark:bg-gray-700 flex items-center justify-center mb-4">
        <Icon size={28} className="text-gray-300 dark:text-gray-500"/>
      </div>
      <h3 className="font-display font-semibold text-gray-600 dark:text-gray-300 mb-1">{title}</h3>
      <p className="text-sm text-gray-400 max-w-xs">{desc}</p>
    </div>
  );
}

function ClassSkeleton() {
  return (
    <div className="animate-pulse">
      <div className="h-40 bg-gray-200 dark:bg-gray-700"/>
      <div className="flex gap-4 px-6 py-4 border-b border-gray-200 dark:border-gray-700">
        {[...Array(5)].map((_,i)=><div key={i} className="h-8 w-20 bg-gray-200 dark:bg-gray-700 rounded-lg"/>)}
      </div>
      <div className="p-6 space-y-3">
        {[...Array(4)].map((_,i)=><div key={i} className="h-20 bg-gray-200 dark:bg-gray-700 rounded-2xl"/>)}
      </div>
    </div>
  );
}
