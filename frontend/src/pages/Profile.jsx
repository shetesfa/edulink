import React, { useState, useEffect, useRef } from 'react';
import { useParams, Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import {
  Camera, Edit3, BookOpen, Award, Calendar, Mail,
  Phone, School, Save, X, Loader2, CheckCircle2,
  BarChart2, Clock, MessageSquare,
} from 'lucide-react';
import { authAPI, progressAPI } from '@/utils/api';
import { useAuthStore } from '@/store';
import { format } from 'date-fns';
import toast from 'react-hot-toast';
import clsx from 'clsx';

export default function Profile() {
  const { username }    = useParams();
  const { user, updateUser } = useAuthStore();
  const isOwn           = !username || username === user?.username;

  const [profile, setProfile]   = useState(null);
  const [progress, setProgress] = useState(null);
  const [loading, setLoading]   = useState(true);
  const [editing, setEditing]   = useState(false);
  const [saving, setSaving]     = useState(false);
  const [form, setForm]         = useState({});

  const avatarRef = useRef();
  const coverRef  = useRef();

  useEffect(() => {
    const fetchProfile = isOwn
      ? authAPI.me()
      : fetch(`/api/users/${username}`, { headers: { Authorization: `Bearer ${localStorage.getItem('token')}` } }).then((r) => r.json());

    Promise.all([
      authAPI.me(),
      progressAPI.myProgress(),
    ]).then(([{ data: ud }, { data: pd }]) => {
      setProfile(ud.user);
      setProgress(pd);
      setForm({
        first_name: ud.user.first_name,
        last_name:  ud.user.last_name,
        bio:        ud.user.bio || '',
        phone:      ud.user.phone || '',
        grade:      ud.user.grade || '',
      });
    }).finally(() => setLoading(false));
  }, [username]);

  const saveProfile = async () => {
    setSaving(true);
    try {
      const fd = new FormData();
      Object.entries(form).forEach(([k,v]) => v && fd.append(k, v));
      const { data } = await authAPI.updateProfile(fd);
      setProfile(data.user);
      updateUser(data.user);
      setEditing(false);
      toast.success('Profile updated!');
    } catch { toast.error('Failed to update profile'); }
    finally { setSaving(false); }
  };

  const uploadPhoto = async (file, type) => {
    if (!file) return;
    const fd = new FormData();
    fd.append(type, file);
    try {
      const { data } = await authAPI.updateProfile(fd);
      setProfile(data.user);
      updateUser(data.user);
      toast.success('Photo updated!');
    } catch { toast.error('Upload failed'); }
  };

  if (loading) return (
    <div className="flex items-center justify-center h-full">
      <div className="w-8 h-8 border-4 border-brand-600 border-t-transparent rounded-full animate-spin"/>
    </div>
  );

  if (!profile) return <div className="p-8 text-center text-gray-400">Profile not found.</div>;

  const stats = progress?.overall || {};

  return (
    <div className="max-w-3xl mx-auto p-4 sm:p-6 space-y-5">
      {/* Cover + Avatar */}
      <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-card overflow-hidden">
        {/* Cover photo */}
        <div
          className="relative h-36 sm:h-48 cursor-pointer group"
          style={{
            background: profile.cover_photo
              ? `url(${profile.cover_photo}) center/cover`
              : 'linear-gradient(135deg, #1E1B4B, #7C3AED)',
          }}
          onClick={() => isOwn && coverRef.current?.click()}
        >
          {isOwn && (
            <div className="absolute inset-0 bg-black/0 group-hover:bg-black/30 transition-all flex items-center justify-center opacity-0 group-hover:opacity-100">
              <div className="flex items-center gap-2 bg-black/50 text-white text-sm px-3 py-1.5 rounded-xl">
                <Camera size={14}/> Change Cover
              </div>
            </div>
          )}
          <input ref={coverRef} type="file" accept="image/*" className="hidden"
            onChange={(e) => uploadPhoto(e.target.files[0], 'cover_photo')}/>
        </div>

        {/* Avatar row */}
        <div className="px-5 pb-5">
          <div className="flex items-end justify-between -mt-10 sm:-mt-14 mb-4">
            {/* Avatar */}
            <div className="relative group cursor-pointer" onClick={() => isOwn && avatarRef.current?.click()}>
              {profile.profile_photo ? (
                <img src={profile.profile_photo} alt={profile.full_name}
                  className="w-20 h-20 sm:w-28 sm:h-28 rounded-2xl object-cover border-4 border-white dark:border-gray-800 shadow-lg"/>
              ) : (
                <div className="w-20 h-20 sm:w-28 sm:h-28 rounded-2xl border-4 border-white dark:border-gray-800 shadow-lg bg-gradient-to-br from-brand-500 to-brand-700 flex items-center justify-center font-display font-bold text-3xl text-white">
                  {profile.first_name?.[0]}{profile.last_name?.[0]}
                </div>
              )}
              {isOwn && (
                <div className="absolute inset-0 rounded-2xl bg-black/0 group-hover:bg-black/30 transition-all flex items-center justify-center opacity-0 group-hover:opacity-100">
                  <Camera size={20} className="text-white"/>
                </div>
              )}
              <input ref={avatarRef} type="file" accept="image/*" className="hidden"
                onChange={(e) => uploadPhoto(e.target.files[0], 'profile_photo')}/>
            </div>

            {/* Actions */}
            {isOwn && (
              <div className="flex gap-2">
                {editing ? (
                  <>
                    <button onClick={() => setEditing(false)} className="flex items-center gap-1.5 px-3 py-2 border border-gray-200 dark:border-gray-600 rounded-xl text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 transition-all">
                      <X size={14}/> Cancel
                    </button>
                    <button onClick={saveProfile} disabled={saving} className="flex items-center gap-1.5 px-4 py-2 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white rounded-xl text-sm font-semibold transition-all">
                      {saving ? <Loader2 size={14} className="animate-spin"/> : <Save size={14}/>}
                      {saving ? 'Saving…' : 'Save'}
                    </button>
                  </>
                ) : (
                  <button onClick={() => setEditing(true)} className="flex items-center gap-1.5 px-4 py-2 border border-gray-200 dark:border-gray-600 rounded-xl text-sm font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 transition-all">
                    <Edit3 size={14}/> Edit Profile
                  </button>
                )}
              </div>
            )}
          </div>

          {/* Name + info */}
          {editing ? (
            <div className="space-y-3">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs text-gray-500 mb-1">First name</label>
                  <input value={form.first_name} onChange={(e) => setForm({...form, first_name:e.target.value})}
                    className="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-sm outline-none focus:ring-2 focus:ring-brand-400 dark:text-white"/>
                </div>
                <div>
                  <label className="block text-xs text-gray-500 mb-1">Last name</label>
                  <input value={form.last_name} onChange={(e) => setForm({...form, last_name:e.target.value})}
                    className="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-sm outline-none focus:ring-2 focus:ring-brand-400 dark:text-white"/>
                </div>
              </div>
              <div>
                <label className="block text-xs text-gray-500 mb-1">Bio</label>
                <textarea value={form.bio} onChange={(e) => setForm({...form, bio:e.target.value})} rows={3} placeholder="Tell people about yourself…"
                  className="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-sm outline-none focus:ring-2 focus:ring-brand-400 resize-none dark:text-white"/>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs text-gray-500 mb-1">Phone</label>
                  <input value={form.phone} onChange={(e) => setForm({...form, phone:e.target.value})} placeholder="+251…"
                    className="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-sm outline-none focus:ring-2 focus:ring-brand-400 dark:text-white"/>
                </div>
                <div>
                  <label className="block text-xs text-gray-500 mb-1">Grade</label>
                  <input value={form.grade} onChange={(e) => setForm({...form, grade:e.target.value})} placeholder="Grade 10"
                    className="w-full px-3 py-2 rounded-xl border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-sm outline-none focus:ring-2 focus:ring-brand-400 dark:text-white"/>
                </div>
              </div>
            </div>
          ) : (
            <div>
              <div className="flex items-center gap-2 flex-wrap">
                <h1 className="font-display font-bold text-xl text-gray-900 dark:text-white">{profile.full_name}</h1>
                <span className={clsx('text-xs font-semibold px-2 py-0.5 rounded-full capitalize',
                  profile.role==='teacher'?'bg-green-100 text-green-700':
                  profile.role==='school_admin'?'bg-brand-100 text-brand-700':'bg-blue-100 text-blue-700')}>
                  {profile.role?.replace('_',' ')}
                </span>
              </div>
              <p className="text-gray-400 text-sm mt-0.5">@{profile.username}</p>
              {profile.bio && <p className="text-gray-600 dark:text-gray-300 text-sm mt-3 leading-relaxed">{profile.bio}</p>}

              {/* Meta info */}
              <div className="flex flex-wrap gap-4 mt-4 text-sm text-gray-500 dark:text-gray-400">
                {profile.school && <span className="flex items-center gap-1.5"><School size={13}/> {profile.school.name}</span>}
                {profile.grade  && <span className="flex items-center gap-1.5"><BookOpen size={13}/> {profile.grade}</span>}
                {profile.email  && <span className="flex items-center gap-1.5"><Mail size={13}/> {profile.email}</span>}
                {profile.phone  && <span className="flex items-center gap-1.5"><Phone size={13}/> {profile.phone}</span>}
                <span className="flex items-center gap-1.5"><Calendar size={13}/> Joined {format(new Date(profile.created_at),'MMM yyyy')}</span>
                <span className={clsx('flex items-center gap-1.5', profile.is_online ? 'text-green-500' : '')}>
                  <div className={clsx('w-2 h-2 rounded-full', profile.is_online ? 'bg-green-500' : 'bg-gray-300')}/>
                  {profile.is_online ? 'Online now' : 'Offline'}
                </span>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Stats */}
      {isOwn && progress && (
        <motion.div initial={{ opacity:0,y:12 }} animate={{ opacity:1,y:0 }} transition={{ delay:0.1 }}>
          <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-card p-5">
            <h2 className="font-display font-semibold text-gray-900 dark:text-white mb-4 flex items-center gap-2">
              <BarChart2 size={16} className="text-brand-600"/> Learning Stats
            </h2>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
              {[
                { label:'Classes',      value: stats.total_classes    || 0, icon: BookOpen,     color:'violet' },
                { label:'Lessons Done', value: stats.lessons_viewed   || 0, icon: CheckCircle2, color:'green'  },
                { label:'Assignments',  value: stats.assignments_done || 0, icon: Award,        color:'orange' },
                { label:'Quiz Avg',     value: `${stats.avg_quiz||0}%`,     icon: BarChart2,    color:'blue'   },
              ].map((s) => (
                <div key={s.label} className="text-center p-3 bg-gray-50 dark:bg-gray-700 rounded-xl">
                  <div className={clsx('w-8 h-8 rounded-xl flex items-center justify-center mx-auto mb-2',
                    s.color==='violet'?'bg-brand-100 dark:bg-brand-900/30':
                    s.color==='green' ?'bg-green-100 dark:bg-green-900/30':
                    s.color==='orange'?'bg-orange-100 dark:bg-orange-900/30':'bg-blue-100 dark:bg-blue-900/30')}>
                    <s.icon size={16} className={clsx(
                      s.color==='violet'?'text-brand-600':s.color==='green'?'text-green-600':s.color==='orange'?'text-orange-500':'text-blue-600')}/>
                  </div>
                  <p className="font-display font-bold text-gray-900 dark:text-white">{s.value}</p>
                  <p className="text-xs text-gray-400 mt-0.5">{s.label}</p>
                </div>
              ))}
            </div>
          </div>
        </motion.div>
      )}

      {/* Quick actions (own profile) */}
      {isOwn && (
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
          {[
            { to:'/chat',     icon: MessageSquare, label:'Messages',  color:'violet' },
            { to:'/classes',  icon: BookOpen,      label:'My Classes',color:'blue'   },
            { to:'/settings', icon: Edit3,         label:'Settings',  color:'gray'   },
          ].map((a) => (
            <Link key={a.to} to={a.to}
              className="flex items-center gap-3 p-4 bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-card hover:shadow-card-hover hover:border-brand-200 group transition-all">
              <div className={clsx('w-9 h-9 rounded-xl flex items-center justify-center',
                a.color==='violet'?'bg-brand-100 dark:bg-brand-900/30 group-hover:bg-brand-600':
                a.color==='blue'  ?'bg-blue-100 dark:bg-blue-900/30 group-hover:bg-blue-600':'bg-gray-100 dark:bg-gray-700 group-hover:bg-gray-500','transition-all')}>
                <a.icon size={16} className={clsx('transition-colors',
                  a.color==='violet'?'text-brand-600 group-hover:text-white':
                  a.color==='blue'  ?'text-blue-600 group-hover:text-white':'text-gray-500 group-hover:text-white')}/>
              </div>
              <span className="text-sm font-medium text-gray-700 dark:text-gray-300">{a.label}</span>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
