import React, { useEffect } from 'react';
import { Outlet, NavLink, useNavigate, useLocation } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import {
  LayoutDashboard, BookOpen, MessageSquare, Video,
  Bot, Bell, Search, Settings, LogOut, Menu, X,
  Users, BarChart2, ChevronRight, GraduationCap,
} from 'lucide-react';
import { useAuthStore, useNotificationStore, useUIStore } from '@/store';
import { authAPI, notificationAPI } from '@/utils/api';
import Avatar from '@/components/shared/Avatar';
import NotificationPanel from '@/components/shared/NotificationPanel';
import clsx from 'clsx';

const navItems = [
  { to: '/dashboard', icon: LayoutDashboard, label: 'Dashboard',    roles: ['student','teacher','school_admin'] },
  { to: '/classes',   icon: BookOpen,        label: 'My Classes',   roles: ['student','teacher','school_admin'] },
  { to: '/chat',      icon: MessageSquare,   label: 'Chat',         roles: ['student','teacher','school_admin'] },
  { to: '/meetings',  icon: Video,           label: 'Meetings',     roles: ['student','teacher','school_admin'] },
  { to: '/ai',        icon: Bot,             label: 'AI Assistant', roles: ['student','teacher','school_admin'] },
  { to: '/admin',     icon: BarChart2,       label: 'Admin Panel',  roles: ['school_admin'] },
];

export default function AppLayout() {
  const { user, logout, connectSocket } = useAuthStore();
  const { unreadCount, setNotifications } = useNotificationStore();
  const { sidebarOpen, mobileSidebarOpen, toggleSidebar, toggleMobileSidebar, closeMobileSidebar } = useUIStore();
  const navigate  = useNavigate();
  const location  = useLocation();
  const [showNotifications, setShowNotifications] = React.useState(false);

  // Connect socket on mount
  useEffect(() => { connectSocket(); }, []);

  // Load notifications
  useEffect(() => {
    notificationAPI.list().then(({ data }) => setNotifications(data.notifications || []));
  }, []);

  // Close mobile sidebar on route change
  useEffect(() => { closeMobileSidebar(); }, [location.pathname]);

  const handleLogout = async () => {
    await authAPI.logout().catch(() => {});
    logout();
    navigate('/login');
  };

  const filteredNav = navItems.filter((n) => n.roles.includes(user?.role));

  const Sidebar = ({ mobile = false }) => (
    <div className={clsx(
      'flex flex-col h-full bg-brand-950 text-white',
      !mobile && 'w-64 transition-all duration-300',
      mobile && 'w-72'
    )}>
      {/* Logo */}
      <div className="flex items-center gap-3 px-5 py-5 border-b border-white/10">
        <div className="w-9 h-9 bg-gradient-to-br from-brand-600 to-amber-500 rounded-xl flex items-center justify-center font-black text-lg font-display">E</div>
        <span className="font-display font-bold text-xl">Edu<span className="text-amber-400">Link</span></span>
        {mobile && (
          <button onClick={closeMobileSidebar} className="ml-auto p-1 rounded-lg hover:bg-white/10">
            <X size={18} />
          </button>
        )}
      </div>

      {/* Nav */}
      <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
        {filteredNav.map(({ to, icon: Icon, label }) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) => clsx(
              'flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all',
              isActive
                ? 'bg-brand-600 text-white shadow-glow'
                : 'text-white/60 hover:text-white hover:bg-white/8'
            )}
          >
            <Icon size={18} />
            <span>{label}</span>
          </NavLink>
        ))}
      </nav>

      {/* User card */}
      <div className="px-3 pb-4 border-t border-white/10 pt-3">
        <NavLink to="/profile" className="flex items-center gap-3 px-3 py-2 rounded-xl hover:bg-white/8 transition-all group">
          <Avatar user={user} size="sm" />
          <div className="flex-1 min-w-0">
            <p className="text-sm font-semibold text-white truncate">{user?.full_name}</p>
            <p className="text-xs text-white/50 capitalize">{user?.role?.replace('_', ' ')}</p>
          </div>
          <ChevronRight size={14} className="text-white/30 group-hover:text-white/60" />
        </NavLink>
        <button
          onClick={handleLogout}
          className="flex items-center gap-3 w-full px-3 py-2 mt-1 rounded-xl text-sm text-white/50 hover:text-red-400 hover:bg-red-400/10 transition-all"
        >
          <LogOut size={16} />
          Sign out
        </button>
      </div>
    </div>
  );

  return (
    <div className="flex h-screen bg-gray-50 dark:bg-gray-900 overflow-hidden">
      {/* Desktop sidebar */}
      <div className="hidden lg:flex flex-col flex-shrink-0">
        <Sidebar />
      </div>

      {/* Mobile sidebar overlay */}
      <AnimatePresence>
        {mobileSidebarOpen && (
          <>
            <motion.div
              initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              className="fixed inset-0 bg-black/50 z-40 lg:hidden"
              onClick={closeMobileSidebar}
            />
            <motion.div
              initial={{ x: -280 }} animate={{ x: 0 }} exit={{ x: -280 }}
              transition={{ type: 'spring', damping: 25, stiffness: 300 }}
              className="fixed left-0 top-0 bottom-0 z-50 lg:hidden shadow-2xl"
            >
              <Sidebar mobile />
            </motion.div>
          </>
        )}
      </AnimatePresence>

      {/* Main content */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        {/* Top bar */}
        <header className="flex items-center gap-3 px-4 h-14 bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 flex-shrink-0 z-30">
          <button
            onClick={toggleMobileSidebar}
            className="lg:hidden p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
          >
            <Menu size={20} />
          </button>

          {/* Search bar */}
          <NavLink
            to="/search"
            className="flex items-center gap-2 flex-1 max-w-md px-3 py-1.5 bg-gray-100 dark:bg-gray-700 rounded-xl text-sm text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-600 transition-all"
          >
            <Search size={15} />
            <span>Search anything...</span>
            <kbd className="ml-auto text-xs bg-white dark:bg-gray-600 px-1.5 py-0.5 rounded border border-gray-200 dark:border-gray-500 font-mono hidden sm:block">⌘K</kbd>
          </NavLink>

          <div className="flex items-center gap-1 ml-auto">
            {/* Notifications */}
            <div className="relative">
              <button
                onClick={() => setShowNotifications(!showNotifications)}
                className="relative p-2 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-700 transition-all"
              >
                <Bell size={20} className="text-gray-500 dark:text-gray-400" />
                {unreadCount > 0 && (
                  <span className="absolute top-1 right-1 w-4 h-4 bg-red-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center">
                    {unreadCount > 9 ? '9+' : unreadCount}
                  </span>
                )}
              </button>
              <AnimatePresence>
                {showNotifications && (
                  <NotificationPanel onClose={() => setShowNotifications(false)} />
                )}
              </AnimatePresence>
            </div>

            {/* Settings */}
            <NavLink to="/settings" className="p-2 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-700 transition-all">
              <Settings size={20} className="text-gray-500 dark:text-gray-400" />
            </NavLink>

            {/* Avatar */}
            <NavLink to="/profile" className="ml-1">
              <Avatar user={user} size="sm" className="ring-2 ring-brand-500 ring-offset-2" />
            </NavLink>
          </div>
        </header>

        {/* Page content */}
        <main className="flex-1 overflow-y-auto">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
