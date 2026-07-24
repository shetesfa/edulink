import React, { useState, useEffect, useRef, useCallback } from 'react';
import { createPortal } from 'react-dom';
import { useParams, useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Send, Paperclip, Smile, Search,
  MoreVertical, Reply, Trash2, Edit3,
  Check, CheckCheck, X, Plus,
  ArrowLeft, MessageSquare, UserPlus, Loader,
} from 'lucide-react';
import EmojiPicker, { Theme } from 'emoji-picker-react';
import { useAuthStore, useChatStore } from '@/store';
import { chatAPI, fileAPI } from '@/utils/api';
import api from '@/utils/api';
import Avatar from '@/components/shared/Avatar';
import FileMessage from '@/components/chat/FileMessage';
import toast from 'react-hot-toast';
import clsx from 'clsx';
import { format, isToday, isYesterday } from 'date-fns';

// ─────────────────────────────────────────────────────────────
// MAIN CHAT PAGE
// ─────────────────────────────────────────────────────────────
export default function Chat() {
  const { type, id } = useParams();
  const { user, socket } = useAuthStore();
  const {
    conversations, groups, activeChat, messages,
    typingUsers, onlineUsers, unreadCounts,
    setActiveChat, setConversations, setGroups,
    addMessages, pushMessage, editMessage, deleteMessage,
    updateReaction, setTyping, setOnline, setOffline,
    incrementUnread, clearUnread,
  } = useChatStore();

  const [loading, setLoading]     = useState(false);
  const [sidebarOpen, setSidebar] = useState(true);

  // Load conversations and groups
  useEffect(() => {
    chatAPI.conversations().then(({ data }) => setConversations(data.conversations || []));
    chatAPI.groups().then(({ data }) => setGroups(data.groups || []));
  }, []);

  // Open chat from URL params
  useEffect(() => {
    if (type && id) {
      setActiveChat({ type, id: parseInt(id) });
    }
  }, [type, id]);

  // Socket listeners
  useEffect(() => {
    if (!socket) return;

    const onPrivate = (msg) => {
      const key = `private_${msg.sender.id}`;
      if (activeChat?.type === 'private' && activeChat?.id === msg.sender.id) {
        pushMessage(key, msg);
        socket.emit('message:read', { messageId: msg.id });
      } else {
        incrementUnread(key);
        showBrowserNotification(msg.sender.name, msg.body);
      }
    };

    const onGroup = (msg) => {
      const key = `group_${msg.group_id}`;
      if (activeChat?.type === 'group' && activeChat?.id === msg.group_id) {
        pushMessage(key, msg);
      } else {
        incrementUnread(key);
      }
    };

    const onEdited = ({ messageId, body }) => Object.keys(messages).forEach((key) => editMessage(key, messageId, body));
    const onDeleted = ({ messageId }) => Object.keys(messages).forEach((key) => deleteMessage(key, messageId));
    const onReacted = ({ messageId, emoji, userId }) => Object.keys(messages).forEach((key) => updateReaction(key, messageId, emoji, userId));
    const onTypingStart = ({ userId, name }) => setTyping(activeChat?.type === 'group' ? `group_${activeChat.id}` : `private_${userId}`, name, true);
    const onTypingStop = ({ userId }) => setTyping(activeChat?.type === 'group' ? `group_${activeChat.id}` : `private_${userId}`, '', false);
    const onOnline = ({ userId }) => setOnline(userId);
    const onOffline = ({ userId }) => setOffline(userId);

    socket.on('message:private', onPrivate);
    socket.on('message:group', onGroup);
    socket.on('message:edited', onEdited);
    socket.on('message:deleted', onDeleted);
    socket.on('message:reacted', onReacted);
    socket.on('typing:start', onTypingStart);
    socket.on('typing:stop', onTypingStop);
    socket.on('user:online', onOnline);
    socket.on('user:offline', onOffline);

    return () => {
      socket.off('message:private', onPrivate);
      socket.off('message:group', onGroup);
      socket.off('message:edited', onEdited);
      socket.off('message:deleted', onDeleted);
      socket.off('message:reacted', onReacted);
      socket.off('typing:start', onTypingStart);
      socket.off('typing:stop', onTypingStop);
      socket.off('user:online', onOnline);
      socket.off('user:offline', onOffline);
    };
  }, [socket, activeChat, messages]);

  const openChat = (chat) => {
    setActiveChat(chat);
    clearUnread(chat.type === 'group' ? `group_${chat.id}` : `private_${chat.id}`);
    if (window.innerWidth < 768) setSidebar(false);
  };

  return (
    <div className="flex h-full bg-white dark:bg-gray-800">
      {/* Sidebar */}
      <div className={clsx(
        'flex flex-col border-r border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800',
        'w-full md:w-80 flex-shrink-0',
        !sidebarOpen && 'hidden md:flex',
        sidebarOpen && 'flex'
      )}>
        <ChatSidebar
          conversations={conversations}
          groups={groups}
          activeChat={activeChat}
          onlineUsers={onlineUsers}
          unreadCounts={unreadCounts}
          onSelect={openChat}
          currentUser={user}
          onConversationStarted={(conv) => {
            const exists = conversations.find((c) => c.id === conv.id);
            if (!exists) setConversations([conv, ...conversations]);
            openChat({ type: 'private', id: conv.id, name: conv.full_name, avatar: conv.profile_photo });
          }}
        />
      </div>

      {/* Chat area */}
      <div className={clsx(
        'flex-1 flex flex-col',
        sidebarOpen && 'hidden md:flex',
        !sidebarOpen && 'flex'
      )}>
        {activeChat ? (
          <ChatWindow
            chat={activeChat}
            messages={messages}
            onBack={() => setSidebar(true)}
            socket={socket}
            currentUser={user}
            onlineUsers={onlineUsers}
            typingUsers={typingUsers}
          />
        ) : (
          <EmptyChat />
        )}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// NEW CONVERSATION MODAL — students & teachers talk freely
// ─────────────────────────────────────────────────────────────
function NewConversationModal({ onClose, onSelect, currentUser }) {
  const [query, setQuery]     = useState('');
  const [roleTab, setRoleTab] = useState(currentUser?.role === 'teacher' ? 'student' : 'teacher');
  const [users, setUsers]     = useState([]);
  const [loading, setLoading] = useState(false);
  const inputRef = useRef(null);

  useEffect(() => { inputRef.current?.focus(); }, []);

  useEffect(() => {
    if (!query.trim()) {
      setUsers([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    const timer = setTimeout(() => {
      const params = { type: 'users', q: query.trim() };
      if (roleTab !== 'all') params.role = roleTab;
      api.get('/search', { params })
        .then(({ data }) => {
          const results = (data.results?.users || data.users || [])
            .filter((u) => u.id !== currentUser?.id);
          setUsers(results);
        })
        .catch(() => setUsers([]))
        .finally(() => setLoading(false));
    }, 300);
    return () => clearTimeout(timer);
  }, [query, roleTab, currentUser?.id]);

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-sm" onClick={onClose}>
      <motion.div
        initial={{ opacity: 0, y: 40 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: 40 }}
        onClick={(e) => e.stopPropagation()}
        className="bg-white dark:bg-gray-800 rounded-t-3xl sm:rounded-3xl shadow-2xl w-full max-w-md mx-0 sm:mx-4 overflow-hidden max-h-[85vh] flex flex-col"
      >
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100 dark:border-gray-700">
          <div>
            <h3 className="font-display font-bold text-lg text-gray-900 dark:text-white">New message</h3>
            <p className="text-xs text-gray-400 mt-0.5">Students & teachers can talk freely</p>
          </div>
          <button onClick={onClose} className="p-2 rounded-full hover:bg-gray-100 dark:hover:bg-gray-700">
            <X size={18} />
          </button>
        </div>

        <div className="px-4 pt-3">
          <div className="flex gap-1 p-1 bg-gray-100 dark:bg-gray-700/80 rounded-xl mb-3">
            {[
              { id: 'teacher', label: 'Teachers' },
              { id: 'student', label: 'Students' },
              { id: 'all', label: 'Everyone' },
            ].map((t) => (
              <button
                key={t.id}
                type="button"
                onClick={() => setRoleTab(t.id)}
                className={clsx(
                  'flex-1 py-2 text-xs font-bold rounded-lg transition-all',
                  roleTab === t.id
                    ? 'bg-white dark:bg-gray-600 text-brand-700 dark:text-white shadow-sm'
                    : 'text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'
                )}
              >
                {t.label}
              </button>
            ))}
          </div>
          <div className="relative">
            <Search size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              ref={inputRef}
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search by name…"
              className="w-full pl-10 pr-4 py-3 text-sm bg-gray-50 dark:bg-gray-700/50 border border-gray-200 dark:border-gray-600 rounded-2xl outline-none focus:ring-2 focus:ring-brand-500 dark:text-white"
            />
          </div>
        </div>

        <div className="flex-1 overflow-y-auto px-3 py-3 space-y-1 min-h-[220px]">
          {loading && (
            <div className="flex items-center justify-center py-10">
              <Loader size={22} className="animate-spin text-brand-500" />
            </div>
          )}
          {!loading && users.length === 0 && (
            <div className="text-center py-10 px-4">
              <p className="text-sm text-gray-400">No people found</p>
              <p className="text-xs text-gray-400 mt-1">Try another name or switch tabs</p>
            </div>
          )}
          {users.map((u) => {
            const role = u.role || (u.role_id === 3 ? 'teacher' : 'student');
            return (
              <button
                key={u.id}
                type="button"
                onClick={() => onSelect(u)}
                className="w-full flex items-center gap-3 px-3 py-3 rounded-2xl hover:bg-brand-50 dark:hover:bg-brand-900/20 text-left transition-all group"
              >
                <Avatar user={u} size="md" />
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold text-gray-900 dark:text-white truncate group-hover:text-brand-700 dark:group-hover:text-brand-300">
                    {u.full_name || `${u.first_name} ${u.last_name}`}
                  </p>
                  <p className="text-xs text-gray-400 truncate capitalize">
                    {String(role).replace('_', ' ')}
                    {u.username ? ` · @${u.username}` : ''}
                  </p>
                </div>
                <span className="text-xs font-semibold text-brand-600 opacity-0 group-hover:opacity-100 transition-opacity">
                  Chat →
                </span>
              </button>
            );
          })}
        </div>
      </motion.div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// CHAT SIDEBAR
// ─────────────────────────────────────────────────────────────
function ChatSidebar({ conversations, groups, activeChat, onlineUsers, unreadCounts, onSelect, currentUser, onConversationStarted }) {
  const [search, setSearch]       = useState('');
  const [tab, setTab]             = useState('all'); // all | private | groups
  const [showNewModal, setNewModal] = useState(false);

  const allChats = [
    ...conversations.map((c) => ({ ...c, type: 'private' })),
    ...groups.map((g) => ({ ...g, type: 'group' })),
  ].sort((a, b) => new Date(b.last_message_at || 0) - new Date(a.last_message_at || 0));

  const filtered = allChats.filter((c) => {
    const name = c.type === 'group' ? c.name : c.full_name || '';
    const matchSearch = name.toLowerCase().includes(search.toLowerCase());
    if (tab === 'private') return matchSearch && c.type === 'private';
    if (tab === 'groups')  return matchSearch && c.type === 'group';
    return matchSearch;
  });

  const handleStartConversation = async (u) => {
    setNewModal(false);
    const conv = {
      id: u.id,
      full_name: u.full_name || `${u.first_name} ${u.last_name}`,
      profile_photo: u.profile_photo,
      type: 'private',
    };
    onConversationStarted(conv);
    onSelect({ type: 'private', id: u.id, name: conv.full_name, avatar: conv.profile_photo });
  };

  return (
    <>
      <AnimatePresence>
        {showNewModal && (
          <NewConversationModal
            currentUser={currentUser}
            onClose={() => setNewModal(false)}
            onSelect={handleStartConversation}
          />
        )}
      </AnimatePresence>

      {/* Header */}
      <div className="px-4 pt-5 pb-2">
        <div className="flex items-center justify-between mb-3">
          <div>
            <h2 className="font-display font-bold text-xl text-gray-900 dark:text-white">Messages</h2>
            <p className="text-xs text-gray-400 mt-0.5">Talk freely with students & teachers</p>
          </div>
          <button
            type="button"
            onClick={() => setNewModal(true)}
            className="w-10 h-10 rounded-full bg-brand-600 hover:bg-brand-700 text-white flex items-center justify-center shadow-lg shadow-brand-600/30 transition-all"
            title="New message"
          >
            <Plus size={20} />
          </button>
        </div>
        <div className="relative">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search conversations..."
            className="w-full pl-9 pr-4 py-2.5 text-sm bg-gray-100 dark:bg-gray-700 border-none rounded-2xl outline-none focus:ring-2 focus:ring-brand-500 dark:text-white"
          />
        </div>
        {/* Tabs */}
        <div className="flex gap-1 mt-3 p-1 bg-gray-100 dark:bg-gray-700/60 rounded-xl">
          {[['all','All'],['private','Direct'],['groups','Groups']].map(([v,l]) => (
            <button
              key={v}
              onClick={() => setTab(v)}
              className={clsx(
                'flex-1 py-1.5 text-xs font-bold rounded-lg transition-all',
                tab === v ? 'bg-white dark:bg-gray-600 text-brand-700 dark:text-white shadow-sm' : 'text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-700'
              )}
            >{l}</button>
          ))}
        </div>
      </div>

      {/* List */}
      <div className="flex-1 overflow-y-auto px-2">
        {filtered.map((chat) => {
          const key      = chat.type === 'group' ? `group_${chat.id}` : `private_${chat.id}`;
          const unread   = unreadCounts[key] || 0;
          const isActive = activeChat?.type === chat.type && activeChat?.id === chat.id;
          const isOnline = chat.type === 'private' && onlineUsers.has(chat.id);
          const name     = chat.type === 'group' ? chat.name : chat.full_name;
          const preview  = chat.last_message || 'Start chatting';

          return (
            <button
              key={key}
              onClick={() => onSelect({ type: chat.type, id: chat.id, name, avatar: chat.avatar || chat.profile_photo })}
              className={clsx(
                'w-full flex items-center gap-3 px-3 py-3 rounded-xl mb-1 text-left transition-all',
                isActive ? 'bg-brand-50 dark:bg-brand-900/30' : 'hover:bg-gray-50 dark:hover:bg-gray-700/50'
              )}
            >
              <div className="relative flex-shrink-0">
                {chat.type === 'group' ? (
                  <div className="w-11 h-11 rounded-full bg-brand-gradient flex items-center justify-center text-white font-bold text-sm">
                    {name?.[0]?.toUpperCase()}
                  </div>
                ) : (
                  <Avatar user={chat} size="md" />
                )}
                {isOnline && (
                  <span className="absolute bottom-0 right-0 w-3 h-3 bg-green-400 border-2 border-white dark:border-gray-800 rounded-full" />
                )}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center justify-between">
                  <p className={clsx('text-sm font-semibold truncate', isActive ? 'text-brand-700 dark:text-brand-300' : 'text-gray-900 dark:text-white')}>
                    {name}
                  </p>
                  <span className="text-[10px] text-gray-400 ml-1 flex-shrink-0">
                    {chat.last_message_at ? formatTime(chat.last_message_at) : ''}
                  </span>
                </div>
                <div className="flex items-center justify-between mt-0.5">
                  <p className="text-xs text-gray-400 truncate flex-1">{preview}</p>
                  {unread > 0 && (
                    <span className="ml-1 bg-brand-600 text-white text-[10px] font-bold w-5 h-5 rounded-full flex items-center justify-center flex-shrink-0">
                      {unread > 9 ? '9+' : unread}
                    </span>
                  )}
                </div>
              </div>
            </button>
          );
        })}

        {filtered.length === 0 && (
          <div className="flex flex-col items-center py-12 text-gray-400">
            <MessageSquare size={32} className="mb-3 opacity-40" />
            <p className="text-sm">No conversations yet</p>
            <p className="text-xs mt-1">Click below to start chatting</p>
          </div>
        )}
      </div>

      {/* New chat button */}
      <div className="px-4 pb-4 pt-2 border-t border-gray-100 dark:border-gray-700">
        <button
          onClick={() => setNewModal(true)}
          className="flex items-center justify-center gap-2 w-full py-3 px-4 bg-brand-gradient hover:opacity-90 text-white rounded-2xl text-sm font-bold transition-all shadow-md shadow-brand-glow"
        >
          <UserPlus size={16} /> Start a conversation
        </button>
      </div>
    </>
  );
}

// ─────────────────────────────────────────────────────────────
// CHAT WINDOW
// ─────────────────────────────────────────────────────────────
function ChatWindow({ chat, messages, onBack, socket, currentUser, onlineUsers, typingUsers }) {
  const key          = chat.type === 'group' ? `group_${chat.id}` : `private_${chat.id}`;
  const chatMessages = messages[key] || [];
  const typing       = typingUsers[key] || [];

  const [body, setBody]             = useState('');
  const [replyTo, setReplyTo]       = useState(null);
  const [editingId, setEditingId]   = useState(null);
  const [editBody, setEditBody]     = useState('');
  const [showEmoji, setShowEmoji]   = useState(false);
  const [contextMenu, setCtxMenu]   = useState(null);
  const [uploading, setUploading]   = useState(false);
  const [page, setPage]             = useState(1);
  const [hasMore, setHasMore]       = useState(true);
  const [loading, setLoading]       = useState(false);
  const [sending, setSending]       = useState(false);
  const [isDark, setIsDark]         = useState(() => document.documentElement.classList.contains('dark'));

  const bottomRef    = useRef(null);
  const inputRef     = useRef(null);
  const fileRef      = useRef(null);
  const typingTimer  = useRef(null);
  const emojiPickerRef = useRef(null);

  // Sync dark mode with html class
  useEffect(() => {
    const observer = new MutationObserver(() => {
      setIsDark(document.documentElement.classList.contains('dark'));
    });
    observer.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] });
    return () => observer.disconnect();
  }, []);

  const { addMessages: addMsgs, pushMessage } = useChatStore();
  const navigate    = useNavigate();

  // Load messages
  useEffect(() => {
    setLoading(true);
    setPage(1);
    const fetch = chat.type === 'group'
      ? chatAPI.groupMessages(chat.id, 1)
      : chatAPI.privateMessages(chat.id, 1);

    fetch.then(({ data }) => {
      // Replace messages for this chat (don't accumulate)
      addMsgs(key, data.messages || [], true);
      setHasMore(data.has_more || false);
    }).finally(() => setLoading(false));

    // Join socket room
    if (socket) {
      chat.type === 'group'
        ? socket.emit('join:group', chat.id)
        : null;
    }
    setTimeout(() => bottomRef.current?.scrollIntoView(), 100);
  }, [chat.id, chat.type]);

  // Scroll to bottom on new message
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [chatMessages.length]);

  // Send message
  const send = async () => {
    const text = body.trim();
    if (!text && !editingId) return;

    if (editingId) {
      socket?.emit('message:edit', { messageId: editingId, body: text, groupId: chat.type === 'group' ? chat.id : null, receiverId: chat.type === 'private' ? chat.id : null });
      setEditingId(null);
      setEditBody('');
      setBody('');
      return;
    }

    setSending(true);

    try {
      let res;
      const payload = { body: text, type: 'text', reply_to_id: replyTo?.id || null };

      if (chat.type === 'private') {
        res = await chatAPI.sendPrivate(chat.id, payload);
      } else {
        res = await chatAPI.sendGroup(chat.id, payload);
      }

      const message = res.data.message;
      const key = chat.type === 'private' ? `private_${chat.id}` : `group_${chat.id}`;

      // Add to UI immediately (optimistic)
      pushMessage(key, message);

      // Notify socket so the OTHER user gets the real-time delivery
      if (chat.type === 'private') {
        socket?.emit('message:notify_private', { receiverId: chat.id, message });
      } else {
        socket?.emit('message:notify_group', { groupId: chat.id, message });
      }

      setBody('');
      setReplyTo(null);
      stopTyping();
    } catch (err) {
      const msg = err?.response?.data?.message || 'Failed to send message';
      toast.error(msg);
    } finally {
      setSending(false);
    }
  };

  // Listen for real-time messages from OTHER users (not sent by us)
  useEffect(() => {
    if (!socket) return;

    const onError = ({ error }) => {
      toast.error(error || 'Failed to send message');
    };

    socket.on('message:error', onError);

    return () => {
      socket.off('message:error', onError);
    };
  }, [socket]);

  const onKeyDown = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); }
  };

  const handleTyping = (val) => {
    setBody(val);
    if (!socket) return;
    socket.emit('typing:start', { targetId: chat.id, isGroup: chat.type === 'group' });
    clearTimeout(typingTimer.current);
    typingTimer.current = setTimeout(stopTyping, 2000);
  };

  const stopTyping = () => {
    socket?.emit('typing:stop', { targetId: chat.id, isGroup: chat.type === 'group' });
    clearTimeout(typingTimer.current);
  };

  // File upload
  const handleFile = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    try {
      const fd = new FormData();
      fd.append('file', file);
      fd.append('related_type', 'message');
      const { data } = await fileAPI.upload(fd);
      const payload = { body: file.name, type: file.type.startsWith('image') ? 'image' : 'file', file_id: data.file.id };
      
      let res;
      if (chat.type === 'private') {
        res = await chatAPI.sendPrivate(chat.id, payload);
      } else {
        res = await chatAPI.sendGroup(chat.id, payload);
      }

      const message = res.data.message;
      const key = chat.type === 'private' ? `private_${chat.id}` : `group_${chat.id}`;
      
      pushMessage(key, message);
      
      if (chat.type === 'private') {
        socket?.emit('message:notify_private', { receiverId: chat.id, message });
      } else {
        socket?.emit('message:notify_group', { groupId: chat.id, message });
      }
    } catch {
      toast.error('File upload failed');
    } finally {
      setUploading(false);
      e.target.value = '';
    }
  };

  const react = (messageId, emoji) => {
    socket?.emit('message:react', {
      messageId, emoji,
      groupId: chat.type === 'group' ? chat.id : null,
      receiverId: chat.type === 'private' ? chat.id : null,
    });
    setCtxMenu(null);
  };

  const deleteMsg = (messageId) => {
    socket?.emit('message:delete', {
      messageId,
      groupId: chat.type === 'group' ? chat.id : null,
      receiverId: chat.type === 'private' ? chat.id : null,
    });
    setCtxMenu(null);
  };

  const startEdit = (msg) => {
    setEditingId(msg.id);
    setEditBody(msg.body);
    setBody(msg.body);
    inputRef.current?.focus();
    setCtxMenu(null);
  };

  const isOnline = chat.type === 'private' && onlineUsers.has(chat.id);

  // Group messages by date
  const grouped = groupByDate(chatMessages);

  return (
    <div className="flex flex-col h-full" onClick={() => { setShowEmoji(false); setCtxMenu(null); }}>
      {/* Header */}
      <div className="flex items-center gap-3 px-4 py-3 border-b border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 flex-shrink-0">
        <button onClick={onBack} className="md:hidden p-1 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 mr-1">
          <ArrowLeft size={20} />
        </button>
        <div className="relative">
          {chat.type === 'group' ? (
            <div className="w-10 h-10 rounded-full bg-brand-gradient flex items-center justify-center text-white font-bold">
              {chat.name?.[0]?.toUpperCase()}
            </div>
          ) : (
            <Avatar user={{ full_name: chat.name, profile_photo: chat.avatar }} size="md" />
          )}
          {isOnline && <span className="absolute bottom-0 right-0 w-3 h-3 bg-green-400 border-2 border-white dark:border-gray-800 rounded-full" />}
        </div>
        <div className="flex-1 min-w-0">
          <p className="font-semibold text-gray-900 dark:text-white truncate">{chat.name}</p>
          <p className="text-xs text-gray-400">
            {chat.type === 'group'
              ? `${chat.members_count || ''} members`
              : isOnline ? '🟢 Online' : 'Last seen recently'}
          </p>
        </div>
        <div className="flex items-center gap-1">
          <button className="p-2 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-700"><Search size={18} className="text-gray-500" /></button>
          <button className="p-2 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-700"><MoreVertical size={18} className="text-gray-500" /></button>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-1" style={{ backgroundImage: 'radial-gradient(circle at 1px 1px, rgba(124,58,237,0.04) 1px, transparent 0)', backgroundSize: '40px 40px' }}>
        {loading && <div className="text-center text-sm text-gray-400 py-4">Loading messages…</div>}

        {grouped.map(({ date, messages: dayMsgs }) => (
          <div key={date}>
            <div className="flex items-center gap-3 my-4">
              <div className="flex-1 h-px bg-gray-200 dark:bg-gray-700" />
              <span className="text-xs text-gray-400 font-medium px-2">{date}</span>
              <div className="flex-1 h-px bg-gray-200 dark:bg-gray-700" />
            </div>

            {dayMsgs.map((msg) => (
              <MessageBubble
                key={msg.id}
                message={msg}
                isOwn={msg.sender_id === currentUser.id || msg.sender?.id === currentUser.id}
                onReply={() => { setReplyTo(msg); inputRef.current?.focus(); }}
                onEdit={startEdit}
                onDelete={deleteMsg}
                onReact={react}
                contextMenu={contextMenu}
                setContextMenu={setCtxMenu}
              />
            ))}
          </div>
        ))}

        {/* Typing indicator */}
        {typing.length > 0 && (
          <div className="flex items-center gap-2 px-2 py-1">
            <div className="flex gap-1 items-center">
              {[0,1,2].map((i) => (
                <span key={i} className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: `${i*0.15}s` }} />
              ))}
            </div>
            <span className="text-xs text-gray-400">{typing.join(', ')} {typing.length === 1 ? 'is' : 'are'} typing…</span>
          </div>
        )}

        <div ref={bottomRef} />
      </div>

      {/* Reply bar */}
      <AnimatePresence>
        {replyTo && (
          <motion.div
            initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }}
            className="px-4 py-2 border-t border-gray-100 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 flex items-center gap-3"
          >
            <div className="flex-1 border-l-4 border-brand-500 pl-3">
              <p className="text-xs font-semibold text-brand-600">Replying to {replyTo.sender?.name || 'message'}</p>
              <p className="text-xs text-gray-500 truncate">{replyTo.body}</p>
            </div>
            <button onClick={() => setReplyTo(null)} className="p-1 rounded-full hover:bg-gray-200 dark:hover:bg-gray-600"><X size={14} /></button>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Input bar */}
      <div className="px-4 py-3 border-t border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 flex-shrink-0">
        <div className="flex items-end gap-2">
          {/* Emoji */}
          <div className="relative" ref={emojiPickerRef}>
            <button
              id="emoji-toggle-btn"
              onClick={(e) => {
                e.stopPropagation();
                setShowEmoji((v) => !v);
              }}
              className={clsx(
                'p-2 rounded-xl transition-colors',
                showEmoji
                  ? 'bg-amber-100 dark:bg-amber-900/30 text-amber-500'
                  : 'hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-400 hover:text-amber-400'
              )}
              title="Emoji"
            >
              <Smile size={20} />
            </button>
            <AnimatePresence>
              {showEmoji && (() => {
                const rect = emojiPickerRef.current?.getBoundingClientRect();
                const pickerWidth = 320;
                const pickerHeight = 400;
                const margin = 8;
                const left = rect ? Math.min(rect.left, window.innerWidth - pickerWidth - margin) : 0;
                const top  = rect ? rect.top - pickerHeight - margin : 0;
                return createPortal(
                  <motion.div
                    initial={{ opacity: 0, scale: 0.95, y: 8 }}
                    animate={{ opacity: 1, scale: 1, y: 0 }}
                    exit={{ opacity: 0, scale: 0.95, y: 8 }}
                    transition={{ duration: 0.15 }}
                    style={{
                      position: 'fixed',
                      top: Math.max(margin, top),
                      left: Math.max(margin, left),
                      zIndex: 9999,
                      filter: 'drop-shadow(0 8px 32px rgba(0,0,0,0.22))',
                    }}
                    onClick={(e) => e.stopPropagation()}
                  >
                    <EmojiPicker
                      onEmojiClick={(emojiData) => {
                        setBody((b) => b + emojiData.emoji);
                        setShowEmoji(false);
                        inputRef.current?.focus();
                      }}
                      theme={isDark ? Theme.DARK : Theme.LIGHT}
                      width={pickerWidth}
                      height={pickerHeight}
                      lazyLoadEmojis
                      searchPlaceholder="Search emoji…"
                      previewConfig={{ showPreview: false }}
                    />
                  </motion.div>,
                  document.body
                );
              })()}
            </AnimatePresence>
          </div>

          {/* Attach file */}
          <button
            onClick={() => fileRef.current?.click()}
            className="p-2 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-400 hover:text-brand-500 transition-colors"
            disabled={uploading}
          >
            {uploading ? <span className="animate-spin text-brand-500">⏳</span> : <Paperclip size={20} />}
          </button>
          <input ref={fileRef} type="file" className="hidden" onChange={handleFile}
            accept="image/*,.pdf,.doc,.docx,.ppt,.pptx,.xls,.xlsx,.zip,.mp3,.mp4" />

          {/* Text input */}
          <div className="flex-1 relative">
            <textarea
              ref={inputRef}
              value={body}
              onChange={(e) => handleTyping(e.target.value)}
              onKeyDown={onKeyDown}
              placeholder={editingId ? 'Edit message…' : 'Type a message…'}
              rows={1}
              className={clsx(
                'w-full resize-none rounded-2xl border px-4 py-2.5 text-sm outline-none transition-all',
                'bg-gray-100 dark:bg-gray-700 border-transparent focus:border-brand-400 focus:bg-white dark:focus:bg-gray-600',
                'text-gray-900 dark:text-white placeholder-gray-400 overflow-y-auto'
              )}
              style={{ minHeight: '42px', maxHeight: '128px' }}
              onInput={(e) => {
                e.target.style.height = 'auto';
                e.target.style.height = Math.min(e.target.scrollHeight, 128) + 'px';
              }}
            />
            {editingId && (
              <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-1">
                <button onClick={() => { setEditingId(null); setBody(''); }} className="text-xs text-gray-400 hover:text-red-500">Cancel</button>
              </div>
            )}
          </div>

          {/* Send */}
          <button
            onClick={send}
            disabled={!body.trim() || sending}
            className={clsx(
              'p-2.5 rounded-2xl transition-all',
              body.trim() && !sending
                ? 'bg-brand-600 hover:bg-brand-700 text-white shadow-md'
                : 'bg-gray-100 dark:bg-gray-700 text-gray-400 cursor-not-allowed'
            )}
          >
            {sending ? <span className="animate-spin w-4 h-4 rounded-full border-2 border-brand-500 border-t-transparent" /> : <Send size={18} />}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// MESSAGE BUBBLE
// ─────────────────────────────────────────────────────────────
function MessageBubble({ message: msg, isOwn, onReply, onEdit, onDelete, onReact, contextMenu, setContextMenu }) {
  const [showActions, setShowActions] = useState(false);
  const quickEmojis = ['❤️','👍','😂','😮','👏','🔥'];

  if (msg.is_deleted) {
    return (
      <div className={clsx('flex mb-1', isOwn ? 'justify-end' : 'justify-start')}>
        <span className="text-xs text-gray-400 italic px-4 py-1">Message deleted</span>
      </div>
    );
  }

  return (
    <div
      className={clsx('flex mb-1 group', isOwn ? 'justify-end' : 'justify-start')}
      onMouseEnter={() => setShowActions(true)}
      onMouseLeave={() => setShowActions(false)}
    >
      {!isOwn && (
        <div className="w-8 h-8 rounded-full bg-brand-gradient flex items-center justify-center text-white text-xs font-bold mr-2 mt-auto mb-1 flex-shrink-0">
          {(msg.sender?.name || 'U')[0].toUpperCase()}
        </div>
      )}

      <div className={clsx('max-w-xs lg:max-w-md xl:max-w-lg relative', isOwn ? 'items-end' : 'items-start', 'flex flex-col')}>
        {/* Reply quote */}
        {msg.reply_to && (
          <div className={clsx('text-xs px-3 py-1 mb-1 rounded-lg border-l-2 border-brand-400 bg-brand-50 dark:bg-brand-900/30 text-gray-500 max-w-full')}>
            <span className="font-semibold text-brand-600">{msg.reply_to.sender_name}</span>
            <p className="truncate">{msg.reply_to.body}</p>
          </div>
        )}

        {/* Sender name (groups) */}
        {!isOwn && msg.sender?.name && (
          <p className="text-xs font-semibold text-brand-600 mb-0.5 ml-1">{msg.sender.name}</p>
        )}

        <div className={clsx(
          'relative rounded-2xl px-4 py-2 text-sm shadow-sm max-w-full',
          isOwn
            ? 'bg-brand-600 text-white rounded-br-sm'
            : 'bg-white dark:bg-gray-700 text-gray-900 dark:text-white rounded-bl-sm border border-gray-100 dark:border-gray-600'
        )}>
          {/* File/Image */}
          {['image','file','voice','audio'].includes(msg.message_type) && (
            <FileMessage message={msg} isOwn={isOwn} />
          )}

          {/* Text body */}
          {msg.body && msg.message_type === 'text' && (
            <p className="whitespace-pre-wrap break-words leading-relaxed">{msg.body}</p>
          )}

          {/* Edited */}
          {msg.is_edited && (
            <span className={clsx('text-[10px] ml-1', isOwn ? 'text-brand-200' : 'text-gray-400')}>edited</span>
          )}

          {/* Time + read receipt */}
          <div className={clsx('flex items-center gap-1 mt-1 justify-end', isOwn ? 'text-brand-200' : 'text-gray-400')}>
            <span className="text-[10px]">{formatTime(msg.created_at)}</span>
            {isOwn && (msg.read_count > 0 ? <CheckCheck size={12} /> : <Check size={12} />)}
          </div>
        </div>

        {/* Reactions */}
        {msg.reactions && Object.keys(msg.reactions).length > 0 && (
          <div className="flex flex-wrap gap-1 mt-1">
            {Object.entries(msg.reactions).map(([emoji, users]) =>
              users.length > 0 ? (
                <button
                  key={emoji}
                  onClick={() => onReact(msg.id, emoji)}
                  className="flex items-center gap-1 bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-full px-2 py-0.5 text-xs hover:bg-gray-50 dark:hover:bg-gray-600 transition-all"
                >
                  {emoji} <span className="text-gray-500">{users.length}</span>
                </button>
              ) : null
            )}
          </div>
        )}
      </div>

      {/* Action buttons */}
      <AnimatePresence>
        {showActions && (
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.9 }}
            className={clsx(
              'flex items-center gap-1 mx-2 self-center',
              isOwn ? 'order-first' : 'order-last'
            )}
          >
            <button onClick={() => onReply(msg)} className="p-1.5 rounded-full bg-white dark:bg-gray-700 shadow hover:bg-gray-50 dark:hover:bg-gray-600 text-gray-500">
              <Reply size={13} />
            </button>
            {/* Emoji quick react */}
            {quickEmojis.slice(0,3).map((e) => (
              <button key={e} onClick={() => onReact(msg.id, e)} className="p-1 rounded-full bg-white dark:bg-gray-700 shadow hover:bg-gray-50 text-sm">
                {e}
              </button>
            ))}
            {isOwn && (
              <>
                <button onClick={() => onEdit(msg)} className="p-1.5 rounded-full bg-white dark:bg-gray-700 shadow hover:bg-gray-50 text-gray-500">
                  <Edit3 size={13} />
                </button>
                <button onClick={() => onDelete(msg.id)} className="p-1.5 rounded-full bg-white dark:bg-gray-700 shadow hover:bg-red-50 text-gray-500 hover:text-red-500">
                  <Trash2 size={13} />
                </button>
              </>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

// ─── Empty state ──────────────────────────────────────────────
function EmptyChat() {
  return (
    <div className="flex-1 flex flex-col items-center justify-center text-center p-8 relative overflow-hidden">
      <div className="absolute inset-0 opacity-[0.35] dark:opacity-20"
        style={{ backgroundImage: 'radial-gradient(circle at 1px 1px, rgb(124 58 237 / 0.15) 1px, transparent 0)', backgroundSize: '28px 28px' }}
      />
      <div className="relative z-10 max-w-sm">
        <div className="w-24 h-24 mx-auto mb-6 rounded-[2rem] bg-brand-gradient flex items-center justify-center shadow-2xl shadow-brand-glow">
          <MessageSquare size={40} className="text-white" />
        </div>
        <h3 className="font-display font-bold text-2xl text-gray-900 dark:text-white mb-2">
          Talk freely
        </h3>
        <p className="text-gray-500 dark:text-gray-400 text-sm leading-relaxed mb-6">
          Message any student or teacher instantly — like Telegram, built for learning.
          Pick a chat on the left or start a new one.
        </p>
        <div className="flex flex-wrap justify-center gap-2 text-xs text-gray-400">
          <span className="px-3 py-1 rounded-full bg-gray-100 dark:bg-gray-700">Direct messages</span>
          <span className="px-3 py-1 rounded-full bg-gray-100 dark:bg-gray-700">Class groups</span>
          <span className="px-3 py-1 rounded-full bg-gray-100 dark:bg-gray-700">Files & reactions</span>
        </div>
      </div>
    </div>
  );
}

// ─── Helpers ──────────────────────────────────────────────────
function formatTime(dateStr) {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  if (isToday(d))     return format(d, 'HH:mm');
  if (isYesterday(d)) return 'Yesterday';
  return format(d, 'dd MMM');
}

function groupByDate(messages) {
  const groups = {};
  messages.forEach((msg) => {
    const d    = new Date(msg.created_at);
    const label = isToday(d) ? 'Today' : isYesterday(d) ? 'Yesterday' : format(d, 'MMMM d, yyyy');
    if (!groups[label]) groups[label] = [];
    groups[label].push(msg);
  });
  return Object.entries(groups).map(([date, messages]) => ({ date, messages }));
}

function showBrowserNotification(sender, body) {
  if ('Notification' in window && Notification.permission === 'granted') {
    new Notification(`EduLink - ${sender}`, { body, icon: '/icons/icon-192.png' });
  }
}
