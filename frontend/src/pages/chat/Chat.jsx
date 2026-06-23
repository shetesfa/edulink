import React, { useState, useEffect, useRef, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Send, Paperclip, Smile, Mic, Phone, Video, Search,
  MoreVertical, Reply, Forward, Trash2, Edit3, Pin,
  Check, CheckCheck, Image, FileText, X, Plus,
  Hash, Lock, Users, ArrowLeft, Circle,
} from 'lucide-react';
import EmojiPicker from 'emoji-picker-react';
import { useAuthStore, useChatStore } from '@/store';
import { chatAPI, fileAPI } from '@/utils/api';
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

    socket.on('message:private', (msg) => {
      const key = `private_${msg.sender.id}`;
      if (activeChat?.type === 'private' && activeChat?.id === msg.sender.id) {
        pushMessage(key, msg);
        socket.emit('message:read', { messageId: msg.id });
      } else {
        incrementUnread(key);
        showBrowserNotification(msg.sender.name, msg.body);
      }
    });

    socket.on('message:group', (msg) => {
      const key = `group_${msg.group_id}`;
      if (activeChat?.type === 'group' && activeChat?.id === msg.group_id) {
        pushMessage(key, msg);
      } else {
        incrementUnread(key);
      }
    });

    socket.on('message:edited',  ({ messageId, body }) => {
      // Update in all message lists
      Object.keys(messages).forEach((key) => editMessage(key, messageId, body));
    });

    socket.on('message:deleted', ({ messageId }) => {
      Object.keys(messages).forEach((key) => deleteMessage(key, messageId));
    });

    socket.on('message:reacted', ({ messageId, emoji, userId }) => {
      Object.keys(messages).forEach((key) => updateReaction(key, messageId, emoji, userId));
    });

    socket.on('typing:start', ({ userId, name }) => {
      const key = activeChat?.type === 'group' ? `group_${activeChat.id}` : `private_${userId}`;
      setTyping(key, name, true);
    });

    socket.on('typing:stop', ({ userId }) => {
      const key = activeChat?.type === 'group' ? `group_${activeChat.id}` : `private_${userId}`;
      setTyping(key, '', false);
    });

    socket.on('user:online',  ({ userId }) => setOnline(userId));
    socket.on('user:offline', ({ userId }) => setOffline(userId));

    return () => {
      socket.off('message:private');
      socket.off('message:group');
      socket.off('message:edited');
      socket.off('message:deleted');
      socket.off('message:reacted');
      socket.off('typing:start');
      socket.off('typing:stop');
      socket.off('user:online');
      socket.off('user:offline');
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
// CHAT SIDEBAR
// ─────────────────────────────────────────────────────────────
function ChatSidebar({ conversations, groups, activeChat, onlineUsers, unreadCounts, onSelect }) {
  const [search, setSearch]   = useState('');
  const [tab, setTab]         = useState('all'); // all | private | groups

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

  return (
    <>
      {/* Header */}
      <div className="px-4 pt-4 pb-2">
        <h2 className="font-display font-bold text-lg text-gray-900 dark:text-white mb-3">Messages</h2>
        <div className="relative">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search conversations..."
            className="w-full pl-9 pr-4 py-2 text-sm bg-gray-100 dark:bg-gray-700 border-none rounded-xl outline-none focus:ring-2 focus:ring-brand-500"
          />
        </div>
        {/* Tabs */}
        <div className="flex gap-1 mt-3">
          {[['all','All'],['private','Private'],['groups','Groups']].map(([v,l]) => (
            <button
              key={v}
              onClick={() => setTab(v)}
              className={clsx(
                'flex-1 py-1.5 text-xs font-semibold rounded-lg transition-all',
                tab === v ? 'bg-brand-600 text-white' : 'text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700'
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
                  <div className="w-11 h-11 rounded-full bg-gradient-to-br from-brand-500 to-brand-700 flex items-center justify-center text-white font-bold text-sm">
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
          <div className="text-center py-12 text-gray-400 text-sm">No conversations found</div>
        )}
      </div>

      {/* New chat button */}
      <div className="px-4 pb-4 pt-2 border-t border-gray-100 dark:border-gray-700">
        <button className="flex items-center gap-2 w-full py-2.5 px-4 bg-brand-600 hover:bg-brand-700 text-white rounded-xl text-sm font-semibold transition-all">
          <Plus size={16} /> New Conversation
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

  const bottomRef   = useRef(null);
  const inputRef    = useRef(null);
  const fileRef     = useRef(null);
  const typingTimer = useRef(null);
  const { addMessages: addMsgs, pushMessage } = useChatStore();

  // Load messages
  useEffect(() => {
    setLoading(true);
    setPage(1);
    const fetch = chat.type === 'group'
      ? chatAPI.groupMessages(chat.id, 1)
      : chatAPI.privateMessages(chat.id, 1);

    fetch.then(({ data }) => {
      addMsgs(key, (data.messages || []).reverse());
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
  const send = () => {
    const text = body.trim();
    if (!text && !editingId) return;

    if (editingId) {
      socket?.emit('message:edit', { messageId: editingId, body: text, groupId: chat.type === 'group' ? chat.id : null, receiverId: chat.type === 'private' ? chat.id : null });
      setEditingId(null);
      setEditBody('');
      setBody('');
      return;
    }

    const payload = { body: text, type: 'text', replyToId: replyTo?.id || null };

    if (chat.type === 'private') {
      socket?.emit('message:private', { receiverId: chat.id, ...payload });
    } else {
      socket?.emit('message:group', { groupId: chat.id, ...payload });
    }

    setBody('');
    setReplyTo(null);
    stopTyping();
  };

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
      const payload = { body: file.name, type: file.type.startsWith('image') ? 'image' : 'file', fileId: data.file.id };
      if (chat.type === 'private') socket?.emit('message:private', { receiverId: chat.id, ...payload });
      else socket?.emit('message:group', { groupId: chat.id, ...payload });
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
            <div className="w-10 h-10 rounded-full bg-gradient-to-br from-brand-500 to-brand-700 flex items-center justify-center text-white font-bold">
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
          <button className="p-2 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-700"><Video size={18} className="text-gray-500" /></button>
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
          <div className="relative">
            <button
              onClick={(e) => { e.stopPropagation(); setShowEmoji(!showEmoji); }}
              className="p-2 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-400 hover:text-amber-400 transition-colors"
            >
              <Smile size={20} />
            </button>
            {showEmoji && (
              <div className="absolute bottom-12 left-0 z-50" onClick={(e) => e.stopPropagation()}>
                <EmojiPicker
                  onEmojiClick={(e) => { setBody((b) => b + e.emoji); setShowEmoji(false); inputRef.current?.focus(); }}
                  width={300} height={380}
                />
              </div>
            )}
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
                'dark:text-white placeholder-gray-400 max-h-32 overflow-y-auto'
              )}
              style={{ height: 'auto' }}
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
            disabled={!body.trim()}
            className={clsx(
              'p-2.5 rounded-2xl transition-all',
              body.trim()
                ? 'bg-brand-600 hover:bg-brand-700 text-white shadow-md'
                : 'bg-gray-100 dark:bg-gray-700 text-gray-400 cursor-not-allowed'
            )}
          >
            <Send size={18} />
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
        <div className="w-8 h-8 rounded-full bg-gradient-to-br from-brand-400 to-brand-600 flex items-center justify-center text-white text-xs font-bold mr-2 mt-auto mb-1 flex-shrink-0">
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
    <div className="flex-1 flex flex-col items-center justify-center text-center p-8">
      <div className="w-20 h-20 bg-brand-100 dark:bg-brand-900/30 rounded-full flex items-center justify-center mb-4">
        <MessageSquare size={36} className="text-brand-500" />
      </div>
      <h3 className="font-display font-bold text-xl text-gray-900 dark:text-white mb-2">Your Messages</h3>
      <p className="text-gray-400 max-w-sm">Select a conversation from the sidebar or start a new one to begin chatting.</p>
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
