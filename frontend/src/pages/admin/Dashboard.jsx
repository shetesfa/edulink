import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import {
  Users, BookOpen, MessageSquare, Brain, TrendingUp,
  Shield, Trash2, Ban, CheckCircle2, Search, Filter,
  BarChart2, Activity, Cpu, RefreshCw,
} from 'lucide-react';
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, PieChart, Pie, Cell,
} from 'recharts';
import { adminAPI } from '@/utils/api';
import { format } from 'date-fns';
import toast from 'react-hot-toast';
import clsx from 'clsx';

const PIE_COLORS = ['#7C3AED', '#F59E0B', '#10B981', '#3B82F6'];

export default function AdminDashboard() {
  const [stats, setStats]         = useState(null);
  const [users, setUsers]         = useState([]);
  const [aiStatus, setAiStatus]   = useState([]);
  const [tab, setTab]             = useState('overview');
  const [search, setSearch]       = useState('');
  const [loading, setLoading]     = useState(true);

  useEffect(() => {
    Promise.all([
      adminAPI.stats(),
      adminAPI.users({ page: 1, limit: 20 }),
      adminAPI.aiUsage(),
    ]).then(([s, u, ai]) => {
      setStats(s.data.stats);
      setUsers(u.data.users || []);
      setAiStatus(ai.data.providers || []);
    }).finally(() => setLoading(false));
  }, []);

  const toggleUser = async (id, name) => {
    try {
      await adminAPI.toggleUser(id);
      setUsers((u) => u.map((usr) => usr.id === id ? { ...usr, is_active: !usr.is_active } : usr));
      toast.success(`${name} status updated`);
    } catch { toast.error('Failed to update user'); }
  };

  const deleteUser = async (id, name) => {
    if (!confirm(`Delete ${name}? This cannot be undone.`)) return;
    try {
      await adminAPI.deleteUser(id);
      setUsers((u) => u.filter((usr) => usr.id !== id));
      toast.success(`${name} deleted`);
    } catch { toast.error('Failed to delete user'); }
  };

  const filtered = users.filter((u) =>
    `${u.first_name} ${u.last_name} ${u.email}`.toLowerCase().includes(search.toLowerCase())
  );

  if (loading) return <div className="flex items-center justify-center h-full"><div className="w-10 h-10 border-4 border-brand-600 border-t-transparent rounded-full animate-spin" /></div>;

  const roleBreakdown = [
    { name: 'Students', value: stats?.students || 0 },
    { name: 'Teachers', value: stats?.teachers || 0 },
    { name: 'Admins',   value: stats?.admins   || 0 },
  ];

  return (
    <div className="p-4 sm:p-6 space-y-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="font-display font-bold text-2xl text-gray-900 dark:text-white">Admin Panel</h1>
          <p className="text-gray-400 text-sm">{stats?.school_name || 'School'} · {format(new Date(), 'MMMM d, yyyy')}</p>
        </div>
        <div className="flex items-center gap-2 px-3 py-1.5 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-xl">
          <Activity size={14} className="text-green-500 animate-pulse" />
          <span className="text-xs text-green-700 dark:text-green-400 font-medium">{stats?.online_now || 0} online now</span>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 dark:bg-gray-700/50 rounded-xl p-1 w-fit">
        {[['overview','Overview'],['users','Users'],['ai','AI Status']].map(([v,l]) => (
          <button
            key={v}
            onClick={() => setTab(v)}
            className={clsx(
              'px-4 py-2 text-sm font-semibold rounded-lg transition-all',
              tab === v
                ? 'bg-white dark:bg-gray-800 text-gray-900 dark:text-white shadow-sm'
                : 'text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'
            )}
          >{l}</button>
        ))}
      </div>

      {/* ── Overview tab ────────────────────────────────────────── */}
      {tab === 'overview' && (
        <div className="space-y-6">
          {/* Stat cards */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            {[
              { label: 'Total Users',    value: stats?.total_users    || 0, icon: Users,        color: 'violet' },
              { label: 'Active Classes', value: stats?.total_classes  || 0, icon: BookOpen,     color: 'blue' },
              { label: 'Messages Today', value: stats?.messages_today || 0, icon: MessageSquare,color: 'green' },
              { label: 'AI Requests',    value: stats?.ai_requests    || 0, icon: Brain,        color: 'amber' },
            ].map((s, i) => (
              <motion.div
                key={s.label}
                initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.08 }}
                className="bg-white dark:bg-gray-800 rounded-2xl p-4 border border-gray-100 dark:border-gray-700 shadow-card"
              >
                <div className={clsx(
                  'w-10 h-10 rounded-xl flex items-center justify-center mb-3',
                  s.color === 'violet' && 'bg-brand-100 dark:bg-brand-900/30',
                  s.color === 'blue'   && 'bg-blue-100 dark:bg-blue-900/30',
                  s.color === 'green'  && 'bg-green-100 dark:bg-green-900/30',
                  s.color === 'amber'  && 'bg-amber-100 dark:bg-amber-900/30',
                )}>
                  <s.icon size={20} className={clsx(
                    s.color === 'violet' && 'text-brand-600',
                    s.color === 'blue'   && 'text-blue-600',
                    s.color === 'green'  && 'text-green-600',
                    s.color === 'amber'  && 'text-amber-600',
                  )} />
                </div>
                <p className="font-display font-bold text-2xl text-gray-900 dark:text-white">{s.value.toLocaleString()}</p>
                <p className="text-xs text-gray-400 mt-0.5">{s.label}</p>
              </motion.div>
            ))}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Activity chart */}
            <div className="lg:col-span-2 bg-white dark:bg-gray-800 rounded-2xl p-5 border border-gray-100 dark:border-gray-700 shadow-card">
              <h3 className="font-display font-semibold text-gray-900 dark:text-white mb-4">Platform Activity</h3>
              <ResponsiveContainer width="100%" height={200}>
                <AreaChart data={stats?.daily_activity || sampleActivity()}>
                  <defs>
                    <linearGradient id="g1" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%"  stopColor="#7C3AED" stopOpacity={0.2} />
                      <stop offset="95%" stopColor="#7C3AED" stopOpacity={0} />
                    </linearGradient>
                    <linearGradient id="g2" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%"  stopColor="#F59E0B" stopOpacity={0.2} />
                      <stop offset="95%" stopColor="#F59E0B" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#F0EDFF" />
                  <XAxis dataKey="date" tick={{ fontSize: 10, fill: '#94A3B8' }} axisLine={false} tickLine={false} />
                  <YAxis tick={{ fontSize: 10, fill: '#94A3B8' }} axisLine={false} tickLine={false} />
                  <Tooltip contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 24px rgba(0,0,0,0.1)', fontSize: '11px' }} />
                  <Area type="monotone" dataKey="users"    stroke="#7C3AED" strokeWidth={2} fill="url(#g1)" name="Active Users" />
                  <Area type="monotone" dataKey="messages" stroke="#F59E0B" strokeWidth={2} fill="url(#g2)" name="Messages" />
                </AreaChart>
              </ResponsiveContainer>
            </div>

            {/* Role breakdown pie */}
            <div className="bg-white dark:bg-gray-800 rounded-2xl p-5 border border-gray-100 dark:border-gray-700 shadow-card">
              <h3 className="font-display font-semibold text-gray-900 dark:text-white mb-4">User Roles</h3>
              <ResponsiveContainer width="100%" height={150}>
                <PieChart>
                  <Pie data={roleBreakdown} cx="50%" cy="50%" innerRadius={40} outerRadius={65} dataKey="value" paddingAngle={3}>
                    {roleBreakdown.map((_, i) => <Cell key={i} fill={PIE_COLORS[i]} />)}
                  </Pie>
                  <Tooltip contentStyle={{ borderRadius: '10px', border: 'none', fontSize: '11px' }} />
                </PieChart>
              </ResponsiveContainer>
              <div className="space-y-2 mt-2">
                {roleBreakdown.map((r, i) => (
                  <div key={r.name} className="flex items-center justify-between text-sm">
                    <div className="flex items-center gap-2">
                      <div className="w-2.5 h-2.5 rounded-full" style={{ background: PIE_COLORS[i] }} />
                      <span className="text-gray-600 dark:text-gray-300">{r.name}</span>
                    </div>
                    <span className="font-semibold text-gray-800 dark:text-white">{r.value}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ── Users tab ────────────────────────────────────────────── */}
      {tab === 'users' && (
        <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-card overflow-hidden">
          {/* Search bar */}
          <div className="p-4 border-b border-gray-100 dark:border-gray-700 flex items-center gap-3">
            <div className="relative flex-1 max-w-sm">
              <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search users..."
                className="w-full pl-9 pr-4 py-2 text-sm bg-gray-100 dark:bg-gray-700 rounded-xl outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>
            <span className="text-sm text-gray-400">{filtered.length} users</span>
          </div>

          {/* Table */}
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-100 dark:border-gray-700">
                  <th className="text-left px-5 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">User</th>
                  <th className="text-left px-5 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Role</th>
                  <th className="text-left px-5 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide hidden md:table-cell">Joined</th>
                  <th className="text-left px-5 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Status</th>
                  <th className="text-right px-5 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Actions</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((u) => (
                  <tr key={u.id} className="border-b border-gray-50 dark:border-gray-700/50 hover:bg-gray-50 dark:hover:bg-gray-700/30 transition-colors">
                    <td className="px-5 py-3">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-gradient-to-br from-brand-400 to-brand-600 flex items-center justify-center text-white text-xs font-bold flex-shrink-0">
                          {u.first_name?.[0]}{u.last_name?.[0]}
                        </div>
                        <div>
                          <p className="font-medium text-gray-900 dark:text-white">{u.first_name} {u.last_name}</p>
                          <p className="text-xs text-gray-400">{u.email}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-5 py-3">
                      <span className={clsx(
                        'px-2 py-0.5 rounded-full text-xs font-semibold capitalize',
                        u.role === 'student'      && 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300',
                        u.role === 'teacher'      && 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300',
                        u.role === 'school_admin' && 'bg-brand-100 text-brand-700 dark:bg-brand-900/30 dark:text-brand-300',
                      )}>
                        {u.role?.replace('_', ' ')}
                      </span>
                    </td>
                    <td className="px-5 py-3 text-gray-400 text-xs hidden md:table-cell">
                      {u.created_at ? format(new Date(u.created_at), 'MMM d, yyyy') : '—'}
                    </td>
                    <td className="px-5 py-3">
                      <span className={clsx(
                        'flex items-center gap-1.5 w-fit px-2 py-0.5 rounded-full text-xs font-semibold',
                        u.is_active
                          ? 'bg-green-50 dark:bg-green-900/20 text-green-600 dark:text-green-400'
                          : 'bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400'
                      )}>
                        <span className={clsx('w-1.5 h-1.5 rounded-full', u.is_active ? 'bg-green-500' : 'bg-red-500')} />
                        {u.is_active ? 'Active' : 'Banned'}
                      </span>
                    </td>
                    <td className="px-5 py-3">
                      <div className="flex items-center gap-2 justify-end">
                        <button
                          onClick={() => toggleUser(u.id, `${u.first_name} ${u.last_name}`)}
                          title={u.is_active ? 'Deactivate' : 'Activate'}
                          className={clsx(
                            'p-1.5 rounded-lg transition-all',
                            u.is_active
                              ? 'text-amber-500 hover:bg-amber-50 dark:hover:bg-amber-900/20'
                              : 'text-green-500 hover:bg-green-50 dark:hover:bg-green-900/20'
                          )}
                        >
                          {u.is_active ? <Ban size={15} /> : <CheckCircle2 size={15} />}
                        </button>
                        <button
                          onClick={() => deleteUser(u.id, `${u.first_name} ${u.last_name}`)}
                          className="p-1.5 rounded-lg text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 transition-all"
                        >
                          <Trash2 size={15} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {filtered.length === 0 && (
              <div className="text-center py-12 text-gray-400 text-sm">No users found</div>
            )}
          </div>
        </div>
      )}

      {/* ── AI Status tab ────────────────────────────────────────── */}
      {tab === 'ai' && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="font-display font-semibold text-gray-900 dark:text-white">AI Provider Status</h3>
              <p className="text-sm text-gray-400 mt-0.5">
                EduLink uses {aiStatus.filter((p) => p.available).length} active provider(s) — AI is {aiStatus.some((p) => p.available) ? '✅ operational' : '⚠️ limited'}
              </p>
            </div>
            <button
              onClick={() => adminAPI.aiUsage().then(({ data }) => setAiStatus(data.providers || []))}
              className="flex items-center gap-1.5 px-3 py-1.5 text-sm border border-gray-200 dark:border-gray-600 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-600 dark:text-gray-300 transition-all"
            >
              <RefreshCw size={13} /> Refresh
            </button>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {aiStatus.map((provider, i) => (
              <motion.div
                key={provider.provider}
                initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.07 }}
                className={clsx(
                  'bg-white dark:bg-gray-800 rounded-2xl p-5 border shadow-card',
                  provider.available
                    ? 'border-gray-100 dark:border-gray-700'
                    : 'border-orange-200 dark:border-orange-800/50'
                )}
              >
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-2">
                    <Cpu size={16} className={provider.available ? 'text-brand-500' : 'text-orange-400'} />
                    <span className="font-semibold text-gray-900 dark:text-white text-sm">{provider.name}</span>
                  </div>
                  <span className={clsx(
                    'text-xs font-semibold px-2 py-0.5 rounded-full',
                    provider.available
                      ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400'
                      : 'bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400'
                  )}>
                    {provider.available ? '✓ Available' : '⚠ Limit Reached'}
                  </span>
                </div>

                <div className="space-y-2">
                  <div className="flex justify-between text-xs text-gray-500 dark:text-gray-400">
                    <span>Daily usage</span>
                    <span className="font-medium">{provider.used_today?.toLocaleString()} / {provider.daily_limit?.toLocaleString()}</span>
                  </div>
                  <div className="w-full h-2 bg-gray-100 dark:bg-gray-700 rounded-full overflow-hidden">
                    <div
                      className={clsx(
                        'h-full rounded-full transition-all',
                        provider.percent_used > 90 ? 'bg-red-500' :
                        provider.percent_used > 70 ? 'bg-orange-400' : 'bg-green-500'
                      )}
                      style={{ width: `${Math.min(provider.percent_used || 0, 100)}%` }}
                    />
                  </div>
                  <p className="text-xs text-gray-400 text-right">{provider.percent_used || 0}% used today</p>
                </div>

                {!provider.configured && (
                  <p className="mt-3 text-xs text-orange-500 font-medium">⚠ API key not configured</p>
                )}
              </motion.div>
            ))}
          </div>

          {/* Failover explanation */}
          <div className="bg-brand-50 dark:bg-brand-900/20 border border-brand-200 dark:border-brand-800/50 rounded-2xl p-5">
            <h4 className="font-semibold text-brand-900 dark:text-brand-300 mb-2 flex items-center gap-2">
              <Shield size={16} /> How AI Failover Works
            </h4>
            <p className="text-sm text-brand-700 dark:text-brand-400 leading-relaxed">
              EduLink's AI router automatically tries providers in order of priority. When one hits its daily limit,
              it instantly switches to the next provider. Since all providers reset at midnight (on different timezones),
              students get <strong>effectively unlimited AI access 24/7</strong> — all for free.
            </p>
            <div className="flex flex-wrap gap-2 mt-3">
              {aiStatus.map((p) => (
                <span key={p.provider} className={clsx(
                  'text-xs px-2 py-1 rounded-lg font-medium',
                  p.available ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' : 'bg-gray-100 text-gray-500 line-through'
                )}>
                  {p.name}
                </span>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function sampleActivity() {
  return ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].map((date, i) => ({
    date,
    users:    Math.floor(Math.random() * 80 + 20),
    messages: Math.floor(Math.random() * 200 + 50),
  }));
}
