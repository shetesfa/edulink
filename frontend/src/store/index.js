import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { io } from 'socket.io-client';

// ─────────────────────────────────────────────────────────────
// AUTH STORE
// ─────────────────────────────────────────────────────────────
export const useAuthStore = create(
  persist(
    (set, get) => ({
      user:  null,
      token: null,
      isAuthenticated: false,

      setAuth: (user, token) => set({ user, token, isAuthenticated: true }),

      updateUser: (updates) => set((s) => ({ user: { ...s.user, ...updates } })),

      logout: () => {
        get().disconnectSocket();
        set({ user: null, token: null, isAuthenticated: false });
      },

      // Getters
      isStudent:    () => get().user?.role === 'student',
      isTeacher:    () => get().user?.role === 'teacher',
      isAdmin:      () => get().user?.role === 'school_admin',
      isDark:       () => get().user?.settings?.dark_mode ?? false,
      language:     () => get().user?.settings?.language ?? 'en',

      // Socket
      socket:        null,
      socketConnected: false,

      connectSocket: () => {
        const { token, socket } = get();
        if (!token || socket?.connected) return;

        const s = io(import.meta.env.VITE_SOCKET_URL || 'http://localhost:3001', {
          auth: { token },
          transports: ['websocket'],
          reconnection: true,
          reconnectionAttempts: 10,
          reconnectionDelay: 2000,
        });

        s.on('connect',    () => set({ socketConnected: true }));
        s.on('disconnect', () => set({ socketConnected: false }));
        s.on('connect_error', (e) => console.error('Socket error:', e.message));

        set({ socket: s });
      },

      disconnectSocket: () => {
        get().socket?.disconnect();
        set({ socket: null, socketConnected: false });
      },
    }),
    {
      name: 'edulink-auth',
      partialize: (s) => ({ user: s.user, token: s.token, isAuthenticated: s.isAuthenticated }),
    }
  )
);

// ─────────────────────────────────────────────────────────────
// CHAT STORE
// ─────────────────────────────────────────────────────────────
export const useChatStore = create((set, get) => ({
  // Conversations list
  conversations:    [],
  groups:           [],
  activeChat:       null,   // { type: 'private'|'group', id, name, avatar }
  messages:         {},     // { "private_userId" or "group_groupId": [...messages] }
  typingUsers:      {},     // { "private_userId": [name], "group_groupId": [name] }
  unreadCounts:     {},     // { "private_userId": 3, "group_groupId": 1 }
  onlineUsers:      new Set(),

  setActiveChat: (chat) => set({ activeChat: chat }),

  setConversations: (c) => set({ conversations: c }),
  setGroups:        (g) => set({ groups: g }),

  // Add messages to a conversation
  addMessages: (key, messages, prepend = false) => set((s) => ({
    messages: {
      ...s.messages,
      [key]: prepend
        ? [...messages, ...(s.messages[key] || [])]
        : [...(s.messages[key] || []), ...messages],
    },
  })),

  // Push single new message
  pushMessage: (key, message) => set((s) => ({
    messages: {
      ...s.messages,
      [key]: [...(s.messages[key] || []), message],
    },
  })),

  // Edit a message in place
  editMessage: (key, messageId, body) => set((s) => ({
    messages: {
      ...s.messages,
      [key]: (s.messages[key] || []).map((m) =>
        m.id === messageId ? { ...m, body, is_edited: true } : m
      ),
    },
  })),

  // Delete a message
  deleteMessage: (key, messageId) => set((s) => ({
    messages: {
      ...s.messages,
      [key]: (s.messages[key] || []).map((m) =>
        m.id === messageId ? { ...m, is_deleted: true, body: 'Message deleted' } : m
      ),
    },
  })),

  // Reactions
  updateReaction: (key, messageId, emoji, userId) => set((s) => ({
    messages: {
      ...s.messages,
      [key]: (s.messages[key] || []).map((m) => {
        if (m.id !== messageId) return m;
        const reactions = { ...(m.reactions || {}) };
        if (!reactions[emoji]) reactions[emoji] = [];
        if (reactions[emoji].includes(userId)) {
          reactions[emoji] = reactions[emoji].filter((id) => id !== userId);
        } else {
          reactions[emoji] = [...reactions[emoji], userId];
        }
        return { ...m, reactions };
      }),
    },
  })),

  setTyping: (key, userName, isTyping) => set((s) => {
    const current = s.typingUsers[key] || [];
    const updated = isTyping
      ? current.includes(userName) ? current : [...current, userName]
      : current.filter((n) => n !== userName);
    return { typingUsers: { ...s.typingUsers, [key]: updated } };
  }),

  setOnline:  (userId) => set((s) => { const o = new Set(s.onlineUsers); o.add(userId);    return { onlineUsers: o }; }),
  setOffline: (userId) => set((s) => { const o = new Set(s.onlineUsers); o.delete(userId); return { onlineUsers: o }; }),

  incrementUnread: (key) => set((s) => ({
    unreadCounts: { ...s.unreadCounts, [key]: (s.unreadCounts[key] || 0) + 1 },
  })),
  clearUnread: (key) => set((s) => ({ unreadCounts: { ...s.unreadCounts, [key]: 0 } })),
}));

// ─────────────────────────────────────────────────────────────
// NOTIFICATION STORE
// ─────────────────────────────────────────────────────────────
export const useNotificationStore = create((set) => ({
  notifications: [],
  unreadCount:   0,

  setNotifications: (n) => set({ notifications: n, unreadCount: n.filter((x) => !x.is_read).length }),

  pushNotification: (n) => set((s) => ({
    notifications: [n, ...s.notifications],
    unreadCount:   s.unreadCount + 1,
  })),

  markRead: (id) => set((s) => ({
    notifications: s.notifications.map((n) => n.id === id ? { ...n, is_read: true } : n),
    unreadCount:   Math.max(0, s.unreadCount - 1),
  })),

  markAllRead: () => set((s) => ({
    notifications: s.notifications.map((n) => ({ ...n, is_read: true })),
    unreadCount:   0,
  })),
}));

// ─────────────────────────────────────────────────────────────
// UI STORE
// ─────────────────────────────────────────────────────────────
export const useUIStore = create((set) => ({
  sidebarOpen:       true,
  mobileSidebarOpen: false,
  activeModal:       null,
  modalData:         null,

  toggleSidebar:       () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),
  toggleMobileSidebar: () => set((s) => ({ mobileSidebarOpen: !s.mobileSidebarOpen })),
  closeMobileSidebar:  () => set({ mobileSidebarOpen: false }),

  openModal:  (name, data = null) => set({ activeModal: name, modalData: data }),
  closeModal: ()                  => set({ activeModal: null, modalData: null }),
}));
