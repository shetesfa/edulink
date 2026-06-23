import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Moon, Sun, Globe, Bell, Lock, Shield, Trash2,
  ChevronRight, Check, Eye, EyeOff, Loader2,
  Smartphone, Monitor, Volume2, VolumeX, User,
} from 'lucide-react';
import { authAPI } from '@/utils/api';
import { useAuthStore } from '@/store';
import toast from 'react-hot-toast';
import clsx from 'clsx';

const SECTIONS = [
  { id: 'appearance',    icon: Sun,      label: 'Appearance' },
  { id: 'language',      icon: Globe,    label: 'Language' },
  { id: 'notifications', icon: Bell,     label: 'Notifications' },
  { id: 'security',      icon: Lock,     label: 'Security' },
  { id: 'privacy',       icon: Shield,   label: 'Privacy' },
];

export default function Settings() {
  const { user, updateUser } = useAuthStore();
  const [section, setSection]   = useState('appearance');
  const [saving, setSaving]     = useState(false);
  const [settings, setSettings] = useState({
    dark_mode:              user?.settings?.dark_mode ?? false,
    language:               user?.settings?.language ?? 'en',
    notifications_enabled:  user?.settings?.notifications_enabled ?? true,
    email_notifications:    user?.settings?.email_notifications ?? true,
    sound_enabled:          user?.settings?.sound_enabled ?? true,
    show_online_status:     user?.settings?.show_online_status ?? true,
    allow_messages_from:    user?.settings?.allow_messages_from ?? 'everyone',
    theme:                  user?.settings?.theme ?? 'purple',
    font_size:              user?.settings?.font_size ?? 'medium',
  });

  // Password change state
  const [pwForm, setPwForm]     = useState({ current_password: '', password: '', password_confirmation: '' });
  const [showPws, setShowPws]   = useState({ current: false, new: false, confirm: false });
  const [pwSaving, setPwSaving] = useState(false);

  const save = async (patch = {}) => {
    const merged = { ...settings, ...patch };
    setSettings(merged);
    setSaving(true);
    try {
      const { data } = await authAPI.updateSettings(merged);
      updateUser({ settings: merged });
      // Apply dark mode immediately
      if ('dark_mode' in merged) {
        document.documentElement.classList.toggle('dark', merged.dark_mode);
      }
    } catch { toast.error('Failed to save settings'); }
    finally { setSaving(false); }
  };

  const Toggle = ({ label, desc, field, icon: Icon }) => (
    <div className="flex items-center justify-between py-4 border-b border-gray-100 dark:border-gray-700 last:border-0">
      <div className="flex items-start gap-3">
        {Icon && <Icon size={18} className="text-gray-400 mt-0.5 flex-shrink-0"/>}
        <div>
          <p className="text-sm font-medium text-gray-900 dark:text-white">{label}</p>
          {desc && <p className="text-xs text-gray-400 mt-0.5">{desc}</p>}
        </div>
      </div>
      <button
        onClick={() => save({ [field]: !settings[field] })}
        className={clsx(
          'relative w-11 h-6 rounded-full transition-all duration-300 flex-shrink-0',
          settings[field] ? 'bg-brand-600' : 'bg-gray-200 dark:bg-gray-600'
        )}
      >
        <span className={clsx(
          'absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow transition-all duration-300',
          settings[field] ? 'translate-x-5' : 'translate-x-0'
        )}/>
      </button>
    </div>
  );

  const changePassword = async (e) => {
    e.preventDefault();
    if (pwForm.password !== pwForm.password_confirmation) return toast.error('Passwords do not match');
    if (pwForm.password.length < 8) return toast.error('Password must be at least 8 characters');
    setPwSaving(true);
    try {
      await authAPI.changePassword(pwForm);
      toast.success('Password changed successfully!');
      setPwForm({ current_password: '', password: '', password_confirmation: '' });
    } catch (err) {
      toast.error(err.response?.data?.message || 'Failed to change password');
    } finally { setPwSaving(false); }
  };

  return (
    <div className="max-w-4xl mx-auto p-4 sm:p-6">
      <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white mb-6">Settings</h1>

      <div className="flex flex-col sm:flex-row gap-5">
        {/* Sidebar nav */}
        <div className="sm:w-52 flex-shrink-0">
          <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-card overflow-hidden">
            {SECTIONS.map((s) => (
              <button
                key={s.id}
                onClick={() => setSection(s.id)}
                className={clsx(
                  'w-full flex items-center gap-3 px-4 py-3 text-sm font-medium transition-all text-left',
                  section === s.id
                    ? 'bg-brand-50 dark:bg-brand-900/20 text-brand-700 dark:text-brand-300 border-r-2 border-brand-600'
                    : 'text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700'
                )}
              >
                <s.icon size={16}/>
                {s.label}
              </button>
            ))}
          </div>
        </div>

        {/* Content */}
        <div className="flex-1">
          <AnimatePresence mode="wait">
            <motion.div
              key={section}
              initial={{ opacity:0, y:8 }}
              animate={{ opacity:1, y:0 }}
              exit={{ opacity:0 }}
              transition={{ duration:0.15 }}
              className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-card overflow-hidden"
            >

              {/* ── Appearance ───────────────────────────────────── */}
              {section === 'appearance' && (
                <div className="p-5 space-y-1">
                  <h2 className="font-display font-semibold text-gray-900 dark:text-white mb-4">Appearance</h2>

                  {/* Dark mode */}
                  <Toggle label="Dark mode" desc="Use dark theme across the app" field="dark_mode" icon={settings.dark_mode ? Moon : Sun}/>

                  {/* Theme color */}
                  <div className="py-4 border-b border-gray-100 dark:border-gray-700">
                    <p className="text-sm font-medium text-gray-900 dark:text-white mb-3">Theme color</p>
                    <div className="flex gap-3 flex-wrap">
                      {[
                        { id:'purple', bg:'bg-brand-600',  label:'Purple'  },
                        { id:'blue',   bg:'bg-blue-600',   label:'Blue'    },
                        { id:'green',  bg:'bg-green-600',  label:'Green'   },
                        { id:'orange', bg:'bg-orange-500', label:'Orange'  },
                        { id:'pink',   bg:'bg-pink-600',   label:'Pink'    },
                      ].map((t) => (
                        <button
                          key={t.id}
                          onClick={() => save({ theme: t.id })}
                          className={clsx('flex items-center gap-2 px-3 py-2 rounded-xl border-2 text-xs font-medium transition-all',
                            settings.theme === t.id
                              ? 'border-brand-500 bg-brand-50 dark:bg-brand-900/20 text-brand-700 dark:text-brand-300'
                              : 'border-gray-200 dark:border-gray-600 text-gray-600 dark:text-gray-300 hover:border-gray-300'
                          )}
                        >
                          <div className={clsx('w-4 h-4 rounded-full flex-shrink-0', t.bg)}>
                            {settings.theme === t.id && <Check size={10} className="text-white m-auto mt-0.5"/>}
                          </div>
                          {t.label}
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* Font size */}
                  <div className="py-4">
                    <p className="text-sm font-medium text-gray-900 dark:text-white mb-3">Text size</p>
                    <div className="flex gap-2">
                      {['small','medium','large'].map((sz) => (
                        <button
                          key={sz}
                          onClick={() => save({ font_size: sz })}
                          className={clsx('flex-1 py-2 rounded-xl border-2 text-sm font-medium capitalize transition-all',
                            settings.font_size === sz
                              ? 'border-brand-500 bg-brand-50 dark:bg-brand-900/20 text-brand-700'
                              : 'border-gray-200 dark:border-gray-600 text-gray-600 dark:text-gray-300 hover:border-gray-300'
                          )}
                        >
                          {sz}
                        </button>
                      ))}
                    </div>
                  </div>
                </div>
              )}

              {/* ── Language ──────────────────────────────────────── */}
              {section === 'language' && (
                <div className="p-5">
                  <h2 className="font-display font-semibold text-gray-900 dark:text-white mb-4">Language</h2>
                  <div className="space-y-2">
                    {[
                      { code:'en', name:'English',  native:'English',  flag:'🇬🇧' },
                      { code:'am', name:'Amharic',  native:'አማርኛ',    flag:'🇪🇹' },
                      { code:'om', name:'Oromo',    native:'Afaan Oromoo', flag:'🇪🇹' },
                      { code:'ti', name:'Tigrinya', native:'ትግርኛ',    flag:'🇪🇹' },
                      { code:'so', name:'Somali',   native:'Soomaali', flag:'🇸🇴' },
                      { code:'ar', name:'Arabic',   native:'العربية',  flag:'🇸🇦' },
                      { code:'fr', name:'French',   native:'Français', flag:'🇫🇷' },
                    ].map((lang) => (
                      <button
                        key={lang.code}
                        onClick={() => save({ language: lang.code })}
                        className={clsx(
                          'w-full flex items-center gap-3 px-4 py-3 rounded-xl border-2 text-left transition-all',
                          settings.language === lang.code
                            ? 'border-brand-500 bg-brand-50 dark:bg-brand-900/20'
                            : 'border-gray-100 dark:border-gray-700 hover:border-gray-200 dark:hover:border-gray-600'
                        )}
                      >
                        <span className="text-2xl">{lang.flag}</span>
                        <div className="flex-1">
                          <p className={clsx('text-sm font-medium', settings.language === lang.code ? 'text-brand-700 dark:text-brand-300' : 'text-gray-900 dark:text-white')}>{lang.name}</p>
                          <p className="text-xs text-gray-400">{lang.native}</p>
                        </div>
                        {settings.language === lang.code && <Check size={16} className="text-brand-600"/>}
                      </button>
                    ))}
                  </div>
                  <p className="text-xs text-gray-400 mt-4">Note: AI responses will be automatically returned in your selected language.</p>
                </div>
              )}

              {/* ── Notifications ─────────────────────────────────── */}
              {section === 'notifications' && (
                <div className="p-5">
                  <h2 className="font-display font-semibold text-gray-900 dark:text-white mb-4">Notifications</h2>
                  <Toggle label="Push notifications" desc="Receive notifications on this device" field="notifications_enabled" icon={Bell}/>
                  <Toggle label="Email notifications" desc="Get important updates via email" field="email_notifications" icon={Bell}/>
                  <Toggle label="Sound effects" desc="Play sound when you receive messages" field="sound_enabled" icon={settings.sound_enabled ? Volume2 : VolumeX}/>

                  <div className="mt-4 p-4 bg-amber-50 dark:bg-amber-900/20 rounded-xl border border-amber-200 dark:border-amber-800">
                    <p className="text-xs text-amber-700 dark:text-amber-400 font-medium">
                      💡 You'll always receive critical notifications like assignment deadlines and grade updates, even when other notifications are off.
                    </p>
                  </div>
                </div>
              )}

              {/* ── Security ──────────────────────────────────────── */}
              {section === 'security' && (
                <div className="p-5">
                  <h2 className="font-display font-semibold text-gray-900 dark:text-white mb-4">Security</h2>
                  <form onSubmit={changePassword} className="space-y-4">
                    <h3 className="text-sm font-semibold text-gray-700 dark:text-gray-300">Change Password</h3>

                    {[
                      { key:'current_password', label:'Current password',  placeholder:'Enter current password', show: showPws.current, toggleKey:'current' },
                      { key:'password',         label:'New password',       placeholder:'At least 8 characters',  show: showPws.new,     toggleKey:'new' },
                      { key:'password_confirmation', label:'Confirm new password', placeholder:'Re-enter new password', show: showPws.confirm, toggleKey:'confirm' },
                    ].map((f) => (
                      <div key={f.key}>
                        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">{f.label}</label>
                        <div className="relative">
                          <Lock size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400"/>
                          <input
                            type={f.show ? 'text' : 'password'}
                            value={pwForm[f.key]}
                            onChange={(e) => setPwForm({ ...pwForm, [f.key]: e.target.value })}
                            placeholder={f.placeholder}
                            className="w-full pl-10 pr-10 py-2.5 rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-sm outline-none focus:border-brand-400 focus:ring-2 focus:ring-brand-100 dark:text-white transition-all"
                          />
                          <button type="button" onClick={() => setShowPws((p) => ({ ...p, [f.toggleKey]: !p[f.toggleKey] }))}
                            className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                            {f.show ? <EyeOff size={15}/> : <Eye size={15}/>}
                          </button>
                        </div>
                      </div>
                    ))}

                    <button type="submit" disabled={pwSaving || !pwForm.current_password || !pwForm.password}
                      className="flex items-center gap-2 px-5 py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white rounded-xl text-sm font-semibold transition-all">
                      {pwSaving ? <Loader2 size={14} className="animate-spin"/> : <Lock size={14}/>}
                      {pwSaving ? 'Saving…' : 'Change Password'}
                    </button>
                  </form>

                  <div className="mt-6 pt-5 border-t border-gray-100 dark:border-gray-700">
                    <h3 className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">Active Sessions</h3>
                    <div className="space-y-3">
                      {[
                        { device: 'This device', type: 'current', icon: Monitor },
                        { device: 'Mobile App',  type: 'mobile',  icon: Smartphone },
                      ].map((s) => (
                        <div key={s.device} className="flex items-center gap-3 p-3 bg-gray-50 dark:bg-gray-700 rounded-xl">
                          <div className="w-8 h-8 rounded-lg bg-white dark:bg-gray-600 flex items-center justify-center">
                            <s.icon size={15} className="text-gray-500"/>
                          </div>
                          <div className="flex-1">
                            <p className="text-sm font-medium text-gray-800 dark:text-white">{s.device}</p>
                            {s.type === 'current' && <p className="text-xs text-green-500">Current session</p>}
                          </div>
                          {s.type !== 'current' && (
                            <button className="text-xs text-red-500 hover:text-red-600 font-medium">Revoke</button>
                          )}
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              )}

              {/* ── Privacy ───────────────────────────────────────── */}
              {section === 'privacy' && (
                <div className="p-5">
                  <h2 className="font-display font-semibold text-gray-900 dark:text-white mb-4">Privacy</h2>
                  <Toggle label="Show online status" desc="Let others see when you're online" field="show_online_status" icon={Eye}/>

                  {/* Who can message me */}
                  <div className="py-4 border-b border-gray-100 dark:border-gray-700">
                    <p className="text-sm font-medium text-gray-900 dark:text-white mb-1">Who can send me messages</p>
                    <p className="text-xs text-gray-400 mb-3">Control who can start a private conversation with you</p>
                    <div className="space-y-2">
                      {[
                        { value:'everyone',   label:'Everyone',                desc:'Any EduLink user can message you' },
                        { value:'classmates', label:'Classmates only',         desc:'Only students in your classes' },
                        { value:'nobody',     label:'Nobody (teachers only)',   desc:'Disable private messages from students' },
                      ].map((opt) => (
                        <button key={opt.value} onClick={() => save({ allow_messages_from: opt.value })}
                          className={clsx('w-full text-left flex items-start gap-3 p-3 rounded-xl border-2 transition-all',
                            settings.allow_messages_from === opt.value
                              ? 'border-brand-500 bg-brand-50 dark:bg-brand-900/20'
                              : 'border-gray-100 dark:border-gray-700 hover:border-gray-200 dark:hover:border-gray-600'
                          )}>
                          <div className={clsx('w-4 h-4 rounded-full border-2 mt-0.5 flex-shrink-0 flex items-center justify-center',
                            settings.allow_messages_from === opt.value ? 'border-brand-500 bg-brand-500' : 'border-gray-300 dark:border-gray-500')}>
                            {settings.allow_messages_from === opt.value && <div className="w-2 h-2 bg-white rounded-full"/>}
                          </div>
                          <div>
                            <p className={clsx('text-sm font-medium', settings.allow_messages_from === opt.value ? 'text-brand-700 dark:text-brand-300' : 'text-gray-900 dark:text-white')}>{opt.label}</p>
                            <p className="text-xs text-gray-400">{opt.desc}</p>
                          </div>
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* Danger zone */}
                  <div className="mt-5 pt-5 border-t border-red-100 dark:border-red-900/30">
                    <h3 className="text-sm font-semibold text-red-600 mb-3">Danger Zone</h3>
                    <button
                      onClick={() => { if (confirm('Are you sure you want to delete your account? This cannot be undone.')) toast.error('Please contact your school admin to delete your account.'); }}
                      className="flex items-center gap-2 px-4 py-2 border border-red-300 dark:border-red-800 text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-xl text-sm font-medium transition-all"
                    >
                      <Trash2 size={14}/> Delete my account
                    </button>
                  </div>
                </div>
              )}
            </motion.div>
          </AnimatePresence>

          {/* Auto-save indicator */}
          <AnimatePresence>
            {saving && (
              <motion.div initial={{ opacity:0 }} animate={{ opacity:1 }} exit={{ opacity:0 }}
                className="flex items-center gap-2 text-xs text-gray-400 mt-3 justify-end">
                <Loader2 size={12} className="animate-spin"/> Saving…
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </div>
    </div>
  );
}
