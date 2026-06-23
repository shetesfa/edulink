import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Plus, Search, Hash, Users, BookOpen, ChevronRight,
  Loader2, X, QrCode, Copy, Check, Video,
} from 'lucide-react';
import { classAPI } from '@/utils/api';
import { useAuthStore } from '@/store';
import { format } from 'date-fns';
import toast from 'react-hot-toast';
import clsx from 'clsx';

export default function Classes() {
  const { user }      = useAuthStore();
  const navigate      = useNavigate();
  const [classes, setClasses] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch]   = useState('');
  const [showJoin, setJoin]   = useState(false);
  const [showCreate, setCreate] = useState(false);
  const [joinCode, setJoinCode]  = useState('');
  const [joining, setJoining]    = useState(false);
  const [copied, setCopied]      = useState(null);

  const isTeacher = user?.role === 'teacher' || user?.role === 'school_admin';

  useEffect(() => {
    classAPI.list()
      .then(({ data }) => setClasses(data.classes || []))
      .finally(() => setLoading(false));
  }, []);

  const joinClass = async (e) => {
    e.preventDefault();
    if (!joinCode.trim()) return;
    setJoining(true);
    try {
      const { data } = await classAPI.join(joinCode.trim().toUpperCase());
      setClasses((p) => [...p, data.class]);
      setJoinCode(''); setJoin(false);
      toast.success(`Joined ${data.class.name}! 🎉`);
      navigate(`/classes/${data.class.id}`);
    } catch (err) {
      toast.error(err.response?.data?.message || 'Invalid join code');
    } finally { setJoining(false); }
  };

  const copyCode = (code) => {
    navigator.clipboard.writeText(code);
    setCopied(code); toast.success('Code copied!');
    setTimeout(() => setCopied(null), 2000);
  };

  const filtered = classes.filter((c) =>
    c.name.toLowerCase().includes(search.toLowerCase()) ||
    (c.subject || '').toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="max-w-6xl mx-auto p-4 sm:p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6 flex-wrap gap-3">
        <div>
          <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white">My Classes</h1>
          <p className="text-gray-400 text-sm">{classes.length} class{classes.length !== 1 ? 'es' : ''}</p>
        </div>
        <div className="flex gap-2">
          {!isTeacher && (
            <button onClick={() => setJoin(true)}
              className="flex items-center gap-2 px-4 py-2 border border-gray-200 dark:border-gray-600 rounded-xl text-sm font-semibold text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 transition-all">
              <Hash size={15}/> Join Class
            </button>
          )}
          {isTeacher && (
            <button onClick={() => setCreate(true)}
              className="flex items-center gap-2 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white rounded-xl text-sm font-semibold transition-all">
              <Plus size={15}/> Create Class
            </button>
          )}
        </div>
      </div>

      {/* Search */}
      <div className="relative mb-5">
        <Search size={16} className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400"/>
        <input
          value={search} onChange={(e) => setSearch(e.target.value)}
          placeholder="Search classes…"
          className="w-full pl-11 pr-4 py-2.5 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl text-sm outline-none focus:border-brand-400 focus:ring-2 focus:ring-brand-100 dark:text-white shadow-card"
        />
      </div>

      {/* Classes grid */}
      {loading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {[...Array(6)].map((_,i) => (
            <div key={i} className="h-44 bg-gray-200 dark:bg-gray-700 rounded-2xl animate-pulse"/>
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-20">
          <div className="w-20 h-20 bg-gray-100 dark:bg-gray-700 rounded-2xl flex items-center justify-center mx-auto mb-4">
            <BookOpen size={32} className="text-gray-300 dark:text-gray-500"/>
          </div>
          <h2 className="font-display font-semibold text-gray-700 dark:text-gray-300 mb-2">
            {search ? 'No classes found' : isTeacher ? 'Create your first class' : 'Join a class to get started'}
          </h2>
          <p className="text-sm text-gray-400 mb-5">
            {search ? 'Try different keywords' : isTeacher ? 'Click "Create Class" above' : 'Ask your teacher for the join code'}
          </p>
          {!isTeacher && !search && (
            <button onClick={() => setJoin(true)} className="px-5 py-2.5 bg-brand-600 hover:bg-brand-700 text-white rounded-xl text-sm font-semibold transition-all">
              Join a Class
            </button>
          )}
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map((cls, i) => (
            <motion.div key={cls.id} initial={{ opacity:0, y:16 }} animate={{ opacity:1, y:0 }} transition={{ delay:i*0.05 }}>
              <Link to={`/classes/${cls.id}`}
                className="group block bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-card hover:shadow-card-hover hover:border-brand-200 dark:hover:border-brand-700 overflow-hidden transition-all">
                {/* Color bar */}
                <div className="h-2" style={{ background: cls.color || '#7C3AED' }}/>

                <div className="p-4">
                  {/* Class icon + name */}
                  <div className="flex items-start justify-between gap-2 mb-3">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 rounded-xl flex items-center justify-center text-white font-bold font-display text-lg flex-shrink-0"
                        style={{ background: `linear-gradient(135deg,${cls.color||'#7C3AED'},${cls.color||'#7C3AED'}88)` }}>
                        {cls.name?.[0]?.toUpperCase()}
                      </div>
                      <div className="min-w-0">
                        <h3 className="font-display font-bold text-gray-900 dark:text-white group-hover:text-brand-600 transition-colors truncate">{cls.name}</h3>
                        {cls.grade && <p className="text-xs text-gray-400">{cls.grade.name}</p>}
                      </div>
                    </div>
                    <ChevronRight size={16} className="text-gray-300 group-hover:text-brand-500 transition-colors flex-shrink-0 mt-1"/>
                  </div>

                  {/* Teacher */}
                  {cls.teacher && (
                    <p className="text-xs text-gray-400 mb-3 flex items-center gap-1">
                      <span className="w-4 h-4 rounded-full bg-brand-100 dark:bg-brand-900/40 text-brand-600 flex items-center justify-center text-[9px] font-bold flex-shrink-0">
                        T
                      </span>
                      {cls.teacher.full_name}
                    </p>
                  )}

                  {/* Stats row */}
                  <div className="flex items-center justify-between text-xs text-gray-400">
                    <span className="flex items-center gap-1"><Users size={11}/> {cls.enrollments_count || 0}</span>
                    <span className="flex items-center gap-1"><BookOpen size={11}/> {cls.lessons_count || 0} lessons</span>
                  </div>

                  {/* Join code (teacher view) */}
                  {isTeacher && cls.join_code && (
                    <div className="mt-3 flex items-center justify-between bg-gray-50 dark:bg-gray-700 rounded-xl px-3 py-2">
                      <span className="font-mono text-sm font-semibold text-gray-700 dark:text-gray-200 tracking-wider">{cls.join_code}</span>
                      <button
                        onClick={(e) => { e.preventDefault(); copyCode(cls.join_code); }}
                        className="p-1 text-gray-400 hover:text-brand-600 transition-colors"
                      >
                        {copied === cls.join_code ? <Check size={14} className="text-green-500"/> : <Copy size={14}/>}
                      </button>
                    </div>
                  )}
                </div>
              </Link>
            </motion.div>
          ))}
        </div>
      )}

      {/* Join class modal */}
      <AnimatePresence>
        {showJoin && (
          <Modal onClose={() => { setJoin(false); setJoinCode(''); }}>
            <div className="text-center mb-5">
              <div className="w-14 h-14 bg-brand-100 dark:bg-brand-900/40 rounded-2xl flex items-center justify-center mx-auto mb-3">
                <Hash size={26} className="text-brand-600"/>
              </div>
              <h2 className="font-display font-bold text-xl text-gray-900 dark:text-white">Join a Class</h2>
              <p className="text-gray-400 text-sm mt-1">Enter the code your teacher shared with you</p>
            </div>
            <form onSubmit={joinClass} className="space-y-4">
              <input
                value={joinCode} onChange={(e) => setJoinCode(e.target.value.toUpperCase())}
                placeholder="e.g. ABCD1234" maxLength={8} autoFocus
                className="w-full px-4 py-3 text-center font-mono text-xl font-bold tracking-widest rounded-xl border-2 border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 outline-none focus:border-brand-500 focus:ring-2 focus:ring-brand-100 dark:text-white uppercase transition-all"
              />
              <button type="submit" disabled={joining || joinCode.length < 6}
                className="w-full flex items-center justify-center gap-2 py-3 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-xl transition-all">
                {joining ? <Loader2 size={16} className="animate-spin"/> : <Hash size={16}/>}
                {joining ? 'Joining…' : 'Join Class'}
              </button>
            </form>
          </Modal>
        )}
      </AnimatePresence>

      {/* Create class modal (teacher) */}
      <AnimatePresence>
        {showCreate && (
          <CreateClassModal
            onClose={() => setCreate(false)}
            onCreate={(cls) => { setClasses((p) => [...p, cls]); setCreate(false); navigate(`/classes/${cls.id}`); }}
          />
        )}
      </AnimatePresence>
    </div>
  );
}

/* ── Create Class Modal ─────────────────────────────────────── */
function CreateClassModal({ onClose, onCreate }) {
  const { user }   = useAuthStore();
  const [form, setForm] = useState({ name:'', subject:'', description:'', color:'#7C3AED' });
  const [saving, setSaving] = useState(false);

  const COLORS = ['#7C3AED','#3B82F6','#10B981','#F59E0B','#EF4444','#EC4899','#6366F1','#0EA5E9'];

  const submit = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) return toast.error('Class name is required');
    setSaving(true);
    try {
      const fd = new FormData();
      Object.entries(form).forEach(([k,v]) => v && fd.append(k, v));
      const { data } = await classAPI.create(fd);
      toast.success(`Class "${data.class.name}" created!`);
      onCreate(data.class);
    } catch (err) { toast.error(err.response?.data?.message || 'Failed to create class'); }
    finally { setSaving(false); }
  };

  return (
    <Modal onClose={onClose} wide>
      <h2 className="font-display font-bold text-xl text-gray-900 dark:text-white mb-5">Create New Class</h2>
      <form onSubmit={submit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">Class name *</label>
          <input value={form.name} onChange={(e) => setForm({...form,name:e.target.value})} placeholder="e.g. Grade 10 Biology" required
            className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-sm outline-none focus:border-brand-400 focus:ring-2 focus:ring-brand-100 dark:text-white"/>
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">Subject</label>
          <input value={form.subject} onChange={(e) => setForm({...form,subject:e.target.value})} placeholder="e.g. Biology"
            className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-sm outline-none focus:border-brand-400 focus:ring-2 focus:ring-brand-100 dark:text-white"/>
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">Description</label>
          <textarea value={form.description} onChange={(e) => setForm({...form,description:e.target.value})} rows={3} placeholder="What will students learn?"
            className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-sm outline-none focus:border-brand-400 focus:ring-2 focus:ring-brand-100 resize-none dark:text-white"/>
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Class color</label>
          <div className="flex gap-2 flex-wrap">
            {COLORS.map((c) => (
              <button key={c} type="button" onClick={() => setForm({...form,color:c})}
                className={clsx('w-9 h-9 rounded-xl flex items-center justify-center transition-all',form.color===c&&'ring-2 ring-offset-2 ring-brand-500 scale-110')}
                style={{ background:c }}>
                {form.color===c && <Check size={14} className="text-white"/>}
              </button>
            ))}
          </div>
        </div>
        <div className="flex gap-3 pt-2">
          <button type="button" onClick={onClose} className="flex-1 py-2.5 border border-gray-200 dark:border-gray-600 rounded-xl text-sm font-semibold text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 transition-all">
            Cancel
          </button>
          <button type="submit" disabled={saving} className="flex-1 flex items-center justify-center gap-2 py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white rounded-xl text-sm font-semibold transition-all">
            {saving ? <Loader2 size={14} className="animate-spin"/> : <Plus size={14}/>}
            {saving ? 'Creating…' : 'Create Class'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

/* ── Generic Modal wrapper ──────────────────────────────────── */
function Modal({ children, onClose, wide = false }) {
  return (
    <motion.div initial={{ opacity:0 }} animate={{ opacity:1 }} exit={{ opacity:0 }}
      className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
      onClick={onClose}>
      <motion.div initial={{ scale:0.95, opacity:0 }} animate={{ scale:1, opacity:1 }} exit={{ scale:0.95, opacity:0 }}
        className={clsx('bg-white dark:bg-gray-800 rounded-2xl shadow-2xl p-6 w-full', wide ? 'max-w-md' : 'max-w-sm')}
        onClick={(e) => e.stopPropagation()}>
        <button onClick={onClose} className="absolute top-4 right-4 p-1 text-gray-400 hover:text-gray-600 dark:hover:text-gray-200">
          <X size={18}/>
        </button>
        {children}
      </motion.div>
    </motion.div>
  );
}
