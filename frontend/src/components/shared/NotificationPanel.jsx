import React from 'react';
import { motion } from 'framer-motion';
import { Bell, Check, Trash2, BookOpen, FileText, Brain, MessageSquare, Video, X } from 'lucide-react';
import { useNotificationStore } from '@/store';
import { notificationAPI } from '@/utils/api';
import { formatDistanceToNow } from 'date-fns';
import { useNavigate } from 'react-router-dom';
import clsx from 'clsx';

const ICON_MAP = {
  new_lesson:           { icon: BookOpen,     color: 'bg-violet-100 text-violet-600' },
  new_assignment:       { icon: FileText,     color: 'bg-orange-100 text-orange-600' },
  new_quiz:             { icon: Brain,        color: 'bg-green-100 text-green-600'   },
  new_message:          { icon: MessageSquare,color: 'bg-blue-100 text-blue-600'     },
  assignment_graded:    { icon: Check,        color: 'bg-green-100 text-green-600'   },
  assignment_submitted: { icon: FileText,     color: 'bg-purple-100 text-purple-600' },
  meeting_scheduled:    { icon: Video,        color: 'bg-red-100 text-red-600'       },
  student_joined:       { icon: Bell,         color: 'bg-amber-100 text-amber-600'   },
};

export default function NotificationPanel({ onClose }) {
  const { notifications, markRead, markAllRead, unreadCount } = useNotificationStore();
  const navigate = useNavigate();

  const handleClick = async (n) => {
    if (!n.is_read) {
      await notificationAPI.markRead(n.id).catch(() => {});
      markRead(n.id);
    }
    if (n.action_url) navigate(n.action_url);
    onClose();
  };

  const handleMarkAll = async () => {
    await notificationAPI.markAllRead().catch(() => {});
    markAllRead();
  };

  return (
    <motion.div
      initial={{ opacity:0, y:8, scale:0.97 }}
      animate={{ opacity:1, y:0, scale:1 }}
      exit={{ opacity:0, y:8, scale:0.97 }}
      transition={{ duration:0.15 }}
      className="absolute right-0 top-12 w-80 sm:w-96 bg-white dark:bg-gray-800 rounded-2xl shadow-2xl border border-gray-200 dark:border-gray-700 z-50 overflow-hidden"
      onClick={(e) => e.stopPropagation()}
    >
      <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100 dark:border-gray-700">
        <div className="flex items-center gap-2">
          <Bell size={16} className="text-violet-600"/>
          <h3 className="font-semibold text-gray-900 dark:text-white text-sm">Notifications</h3>
          {unreadCount > 0 && (
            <span className="bg-violet-600 text-white text-xs font-bold w-5 h-5 rounded-full flex items-center justify-center">{unreadCount}</span>
          )}
        </div>
        <div className="flex items-center gap-2">
          {unreadCount > 0 && (
            <button onClick={handleMarkAll} className="text-xs text-violet-600 hover:text-violet-700 font-medium">Mark all read</button>
          )}
          <button onClick={onClose} className="p-1 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-400">
            <X size={14}/>
          </button>
        </div>
      </div>

      <div className="max-h-96 overflow-y-auto divide-y divide-gray-50 dark:divide-gray-700">
        {notifications.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-10 text-gray-400">
            <Bell size={28} className="mb-2 opacity-40"/>
            <p className="text-sm">No notifications yet</p>
          </div>
        ) : (
          notifications.slice(0, 20).map((n) => {
            const cfg  = ICON_MAP[n.type] || { icon: Bell, color: 'bg-gray-100 text-gray-600' };
            const Icon = cfg.icon;
            return (
              <button key={n.id} onClick={() => handleClick(n)}
                className={clsx('w-full flex items-start gap-3 px-4 py-3 text-left hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-all',
                  !n.is_read && 'bg-violet-50/40 dark:bg-violet-900/10')}>
                <div className={clsx('w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0', cfg.color)}>
                  <Icon size={15}/>
                </div>
                <div className="flex-1 min-w-0">
                  <p className={clsx('text-sm leading-snug', !n.is_read ? 'font-semibold text-gray-900 dark:text-white' : 'text-gray-700 dark:text-gray-300')}>
                    {n.title}
                  </p>
                  {n.body && <p className="text-xs text-gray-400 mt-0.5 truncate">{n.body}</p>}
                  <p className="text-xs text-gray-400 mt-1">
                    {formatDistanceToNow(new Date(n.created_at), { addSuffix: true })}
                  </p>
                </div>
                {!n.is_read && <div className="w-2 h-2 bg-violet-500 rounded-full flex-shrink-0 mt-1.5"/>}
              </button>
            );
          })
        )}
      </div>
    </motion.div>
  );
}
