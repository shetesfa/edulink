import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Video, Plus, Clock, Users, Calendar, Play, Square, Loader2 } from 'lucide-react';
import { meetingAPI } from '@/utils/api';
import { useAuthStore } from '@/store';
import { format, formatDistanceToNow } from 'date-fns';
import toast from 'react-hot-toast';
import clsx from 'clsx';

export default function Meetings() {
  const { user }            = useAuthStore();
  const [meetings, setMeetings] = useState([]);
  const [loading, setLoading]   = useState(true);
  const [showCreate, setCreate] = useState(false);
  const [form, setForm]         = useState({ title: '', scheduled_at: '' });
  const [creating, setCreating] = useState(false);

  const isTeacher = user?.role === 'teacher' || user?.role === 'school_admin';

  useEffect(() => {
    meetingAPI.list()
      .then(({ data }) => setMeetings(data.meetings || []))
      .finally(() => setLoading(false));
  }, []);

  const createMeeting = async (e) => {
    e.preventDefault();
    if (!form.title.trim()) return toast.error('Meeting title is required');
    setCreating(true);
    try {
      const { data } = await meetingAPI.create(form);
      setMeetings((p) => [data.meeting, ...p]);
      setForm({ title: '', scheduled_at: '' });
      setCreate(false);
      toast.success('Meeting created!');
    } catch { toast.error('Failed to create meeting'); }
    finally { setCreating(false); }
  };

  const statusBadge = (status) => ({
    scheduled: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300',
    live:      'bg-red-100 text-red-600 dark:bg-red-900/30 dark:text-red-400',
    ended:     'bg-gray-100 text-gray-500 dark:bg-gray-700 dark:text-gray-400',
  }[status] || 'bg-gray-100 text-gray-500');

  return (
    <div className="max-w-4xl mx-auto p-4 sm:p-6">
      <div className="flex items-center justify-between mb-6 flex-wrap gap-3">
        <div>
          <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white">Video Meetings</h1>
          <p className="text-gray-400 text-sm">{meetings.length} meeting{meetings.length !== 1 ? 's' : ''}</p>
        </div>
        {isTeacher && (
          <button onClick={() => setCreate(!showCreate)}
            className="flex items-center gap-2 px-4 py-2 bg-violet-600 hover:bg-violet-700 text-white rounded-xl text-sm font-semibold transition-all">
            <Plus size={15}/> {showCreate ? 'Cancel' : 'New Meeting'}
          </button>
        )}
      </div>

      {/* Create form */}
      {showCreate && (
        <motion.form initial={{ opacity:0, height:0 }} animate={{ opacity:1, height:'auto' }} exit={{ opacity:0, height:0 }}
          onSubmit={createMeeting}
          className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-200 dark:border-gray-700 p-5 mb-5 space-y-3">
          <h3 className="font-semibold text-gray-900 dark:text-white">Schedule a Meeting</h3>
          <input value={form.title} onChange={(e) => setForm({...form,title:e.target.value})}
            placeholder="Meeting title *" required
            className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-sm outline-none focus:ring-2 focus:ring-violet-400 dark:text-white"/>
          <div>
            <label className="block text-xs text-gray-500 mb-1">Schedule for (optional)</label>
            <input type="datetime-local" value={form.scheduled_at} onChange={(e) => setForm({...form,scheduled_at:e.target.value})}
              className="w-full px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-sm outline-none focus:ring-2 focus:ring-violet-400 dark:text-white"/>
          </div>
          <button type="submit" disabled={creating}
            className="flex items-center gap-2 px-5 py-2.5 bg-violet-600 hover:bg-violet-700 disabled:opacity-60 text-white rounded-xl text-sm font-semibold transition-all">
            {creating ? <Loader2 size={14} className="animate-spin"/> : <Video size={14}/>}
            {creating ? 'Creating…' : 'Create Meeting'}
          </button>
        </motion.form>
      )}

      {/* Meetings list */}
      {loading ? (
        <div className="space-y-3">
          {[...Array(3)].map((_,i) => <div key={i} className="h-24 bg-gray-200 dark:bg-gray-700 rounded-2xl animate-pulse"/>)}
        </div>
      ) : meetings.length === 0 ? (
        <div className="text-center py-16">
          <div className="w-16 h-16 bg-gray-100 dark:bg-gray-700 rounded-2xl flex items-center justify-center mx-auto mb-4">
            <Video size={28} className="text-gray-300 dark:text-gray-500"/>
          </div>
          <h2 className="font-display font-semibold text-gray-700 dark:text-gray-300 mb-1">No meetings yet</h2>
          <p className="text-sm text-gray-400">{isTeacher ? 'Create your first meeting above.' : 'No meetings scheduled yet.'}</p>
        </div>
      ) : (
        <div className="space-y-3">
          {meetings.map((m, i) => (
            <motion.div key={m.id} initial={{ opacity:0, y:10 }} animate={{ opacity:1, y:0 }} transition={{ delay:i*0.05 }}>
              <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 p-4 flex items-center gap-4 hover:border-violet-200 transition-all">
                <div className={clsx('w-12 h-12 rounded-xl flex items-center justify-center flex-shrink-0',
                  m.status === 'live' ? 'bg-red-100 dark:bg-red-900/30' : 'bg-violet-100 dark:bg-violet-900/30')}>
                  <Video size={20} className={m.status === 'live' ? 'text-red-500' : 'text-violet-600'}/>
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <h3 className="font-semibold text-gray-900 dark:text-white truncate">{m.title}</h3>
                    <span className={clsx('text-xs font-semibold px-2 py-0.5 rounded-full capitalize', statusBadge(m.status))}>
                      {m.status === 'live' ? '🔴 Live' : m.status}
                    </span>
                  </div>
                  <div className="flex items-center gap-3 mt-1 text-xs text-gray-400 flex-wrap">
                    {m.host && <span>Host: {m.host.full_name}</span>}
                    {m.class && <span>· {m.class.name}</span>}
                    {m.scheduled_at && <span className="flex items-center gap-1"><Calendar size={11}/> {format(new Date(m.scheduled_at), 'MMM d, HH:mm')}</span>}
                    {m.started_at && m.status === 'live' && <span className="flex items-center gap-1 text-red-400"><Clock size={11}/> Started {formatDistanceToNow(new Date(m.started_at), { addSuffix: true })}</span>}
                  </div>
                </div>
                <Link to={`/meetings/${m.id}`}
                  className={clsx('flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold transition-all flex-shrink-0',
                    m.status === 'live'
                      ? 'bg-red-600 hover:bg-red-700 text-white'
                      : m.status === 'ended'
                        ? 'bg-gray-100 dark:bg-gray-700 text-gray-500 cursor-not-allowed'
                        : 'bg-violet-600 hover:bg-violet-700 text-white')}>
                  {m.status === 'live' ? <><Play size={14}/> Join</> : m.status === 'scheduled' ? <><Video size={14}/> Open</> : 'Ended'}
                </Link>
              </div>
            </motion.div>
          ))}
        </div>
      )}
    </div>
  );
}
