/**
 * EduLink – Real-time Server (Socket.IO + Node.js)
 * ─────────────────────────────────────────────────────────────
 * Handles:
 *  • Private 1-on-1 messaging (real-time, with delivery receipts)
 *  • Group chat  (class groups and custom groups)
 *  • Message typing indicators
 *  • Seen / delivered receipts
 *  • Online presence (is_online, last_seen)
 *  • Push notifications via HTTP to Laravel
 *  • WebRTC signaling for voice + video calls
 *  • Group voice/video (room-based)
 *  • File + media messages
 *  • Message edit / delete broadcasting
 */

const { createServer } = require('http');
const { Server }       = require('socket.io');
const axios            = require('axios');
const jwt              = require('jsonwebtoken');
require('dotenv').config();

// ─── Config ───────────────────────────────────────────────────
const PORT        = process.env.SOCKET_PORT   || 3001;
const BACKEND_URL = process.env.BACKEND_URL   || 'http://localhost:8000';
const API_SECRET  = process.env.INTERNAL_SECRET || 'edulink_internal';
const ALLOWED     = (process.env.CORS_ORIGINS || 'http://localhost:5173').split(',');

console.log(`[EduLink RT] Starting on port ${PORT}`);

// ─── Server setup ─────────────────────────────────────────────
const httpServer = createServer();

const io = new Server(httpServer, {
  cors: {
    origin:      ALLOWED,
    credentials: true,
    methods:     ['GET', 'POST'],
  },
  pingTimeout:  30000,
  pingInterval: 15000,
  maxHttpBufferSize: 10e6, // 10 MB (for file meta)
});

// ─── In-memory state ──────────────────────────────────────────
const connectedUsers = new Map(); // userId → Set<socketId>
const userMeta       = new Map(); // userId → { name, role, schoolId }

function getUserSockets(userId) {
  return [...(connectedUsers.get(userId) || new Set())];
}

function isOnline(userId) {
  const sockets = connectedUsers.get(userId);
  return sockets && sockets.size > 0;
}

function emitToUser(userId, event, data) {
  getUserSockets(userId).forEach((sid) => io.to(sid).emit(event, data));
}

// ─── Auth middleware ──────────────────────────────────────────
io.use(async (socket, next) => {
  const token = socket.handshake.auth?.token || socket.handshake.headers?.authorization?.replace('Bearer ', '');
  if (!token) return next(new Error('auth_required'));

  try {
    // Validate token against Laravel
    const { data } = await axios.get(`${BACKEND_URL}/api/auth/me`, {
      headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' },
      timeout: 5000,
    });

    if (!data?.user) return next(new Error('invalid_token'));

    socket.user  = data.user;
    socket.token = token;
    next();
  } catch (err) {
    console.error('[Auth]', err.message);
    next(new Error('invalid_token'));
  }
});

// ═══════════════════════════════════════════════════════════════
// CONNECTION
// ═══════════════════════════════════════════════════════════════
io.on('connection', (socket) => {
  const user = socket.user;
  const uid  = String(user.id);

  // ── Track connection ──────────────────────────────────────
  if (!connectedUsers.has(uid)) connectedUsers.set(uid, new Set());
  connectedUsers.get(uid).add(socket.id);
  userMeta.set(uid, { name: user.full_name, role: user.role, schoolId: user.school_id });

  socket.join(`user:${uid}`);

  console.log(`[+] ${user.full_name} (${uid}) connected [${socket.id}] — total tabs: ${connectedUsers.get(uid).size}`);

  // Notify contacts this user is now online
  broadcastPresence(uid, true);
  notifyBackend('user.online', { user_id: uid });

  // ─────────────────────────────────────────────────────────────
  // JOIN ROOMS
  // ─────────────────────────────────────────────────────────────

  socket.on('join:groups', (groupIds = []) => {
    groupIds.forEach((gid) => socket.join(`group:${gid}`));
  });

  socket.on('join:class', (classId) => {
    socket.join(`class:${classId}`);
  });

  // ─────────────────────────────────────────────────────────────
  // PRIVATE MESSAGING
  // ─────────────────────────────────────────────────────────────

  socket.on('message:private:send', async (payload, ack) => {
    /*
     * payload: { to_user_id, content, type, temp_id, file_meta? }
     * type: 'text' | 'image' | 'video' | 'audio' | 'file' | 'voice_note'
     */
    const { to_user_id, content, type = 'text', temp_id, file_meta } = payload;
    if (!to_user_id || !content) return;

    try {
      // Persist via Laravel
      const { data } = await axios.post(
        `${BACKEND_URL}/api/chat/private/${to_user_id}`,
        { content, type, file_meta },
        { headers: { Authorization: `Bearer ${socket.token}`, Accept: 'application/json' } }
      );

      const msg = data.message || {};

      // Send to recipient
      emitToUser(String(to_user_id), 'message:private:receive', {
        ...msg,
        sender: { id: user.id, name: user.full_name, avatar: user.profile_photo },
      });

      // Echo back to sender with real message data
      socket.emit('message:private:sent', { temp_id, message: msg });

      // Delivery receipt to sender when recipient is online
      if (isOnline(String(to_user_id))) {
        socket.emit('message:delivered', { message_id: msg.id, to_user_id });
        // Mark delivered in backend
        notifyBackend('message.delivered', { message_id: msg.id });
      }

      ack?.({ success: true, message: msg });
    } catch (err) {
      console.error('[msg:private]', err.message);
      ack?.({ success: false, error: err.message });
    }
  });

  // ─────────────────────────────────────────────────────────────
  // GROUP / CLASS MESSAGING
  // ─────────────────────────────────────────────────────────────

  socket.on('message:group:send', async (payload, ack) => {
    const { group_id, content, type = 'text', temp_id, file_meta } = payload;
    if (!group_id || !content) return;

    try {
      const { data } = await axios.post(
        `${BACKEND_URL}/api/chat/groups/${group_id}`,
        { content, type, file_meta },
        { headers: { Authorization: `Bearer ${socket.token}`, Accept: 'application/json' } }
      );

      const msg = {
        ...(data.message || {}),
        sender: { id: user.id, name: user.full_name, avatar: user.profile_photo },
      };

      // Broadcast to ALL group members (including sender for consistency)
      io.to(`group:${group_id}`).emit('message:group:receive', { group_id, message: msg });

      // Echo real message back to sender
      socket.emit('message:group:sent', { temp_id, group_id, message: msg });

      ack?.({ success: true, message: msg });
    } catch (err) {
      console.error('[msg:group]', err.message);
      ack?.({ success: false, error: err.message });
    }
  });

  // ─────────────────────────────────────────────────────────────
  // TYPING INDICATORS
  // ─────────────────────────────────────────────────────────────

  socket.on('typing:start', ({ to_user_id, group_id }) => {
    if (to_user_id) {
      emitToUser(String(to_user_id), 'typing:start', { from_user_id: uid, name: user.full_name });
    } else if (group_id) {
      socket.to(`group:${group_id}`).emit('typing:start', { group_id, from_user_id: uid, name: user.full_name });
    }
  });

  socket.on('typing:stop', ({ to_user_id, group_id }) => {
    if (to_user_id) {
      emitToUser(String(to_user_id), 'typing:stop', { from_user_id: uid });
    } else if (group_id) {
      socket.to(`group:${group_id}`).emit('typing:stop', { group_id, from_user_id: uid });
    }
  });

  // ─────────────────────────────────────────────────────────────
  // READ RECEIPTS
  // ─────────────────────────────────────────────────────────────

  socket.on('message:seen', async ({ message_id, from_user_id }) => {
    emitToUser(String(from_user_id), 'message:seen', { message_id, seen_by: uid });
    notifyBackend('message.seen', { message_id, user_id: uid });
  });

  socket.on('message:group:seen', async ({ message_id, group_id }) => {
    socket.to(`group:${group_id}`).emit('message:group:seen', {
      message_id, group_id, seen_by: uid, name: user.full_name,
    });
  });

  // ─────────────────────────────────────────────────────────────
  // EDIT / DELETE MESSAGES
  // ─────────────────────────────────────────────────────────────

  socket.on('message:edit', async ({ message_id, content, to_user_id, group_id }) => {
    try {
      await axios.put(
        `${BACKEND_URL}/api/chat/messages/${message_id}`,
        { content },
        { headers: { Authorization: `Bearer ${socket.token}` } }
      );

      const payload = { message_id, content, edited_by: uid, edited_at: new Date().toISOString() };

      if (to_user_id) emitToUser(String(to_user_id), 'message:edited', payload);
      if (group_id) io.to(`group:${group_id}`).emit('message:edited', { ...payload, group_id });
    } catch (err) {
      console.error('[msg:edit]', err.message);
    }
  });

  socket.on('message:delete', async ({ message_id, to_user_id, group_id }) => {
    try {
      await axios.delete(
        `${BACKEND_URL}/api/chat/messages/${message_id}`,
        { headers: { Authorization: `Bearer ${socket.token}` } }
      );

      const payload = { message_id, deleted_by: uid };

      if (to_user_id) emitToUser(String(to_user_id), 'message:deleted', payload);
      if (group_id) io.to(`group:${group_id}`).emit('message:deleted', { ...payload, group_id });
    } catch (err) {
      console.error('[msg:delete]', err.message);
    }
  });

  // ─────────────────────────────────────────────────────────────
  // REACTIONS
  // ─────────────────────────────────────────────────────────────

  socket.on('message:react', ({ message_id, emoji, to_user_id, group_id }) => {
    const payload = { message_id, emoji, by: { id: uid, name: user.full_name } };

    if (to_user_id) emitToUser(String(to_user_id), 'message:reaction', payload);
    if (group_id) io.to(`group:${group_id}`).emit('message:reaction', { ...payload, group_id });
  });

  // ─────────────────────────────────────────────────────────────
  // WEBRTC SIGNALING — 1-on-1 voice/video calls
  // ─────────────────────────────────────────────────────────────

  socket.on('call:initiate', ({ to_user_id, call_type, room_id, offer }) => {
    // call_type: 'audio' | 'video'
    emitToUser(String(to_user_id), 'call:incoming', {
      from_user_id:  uid,
      from_name:     user.full_name,
      from_avatar:   user.profile_photo,
      call_type,
      room_id,
      offer,
    });
  });

  socket.on('call:accept', ({ to_user_id, room_id, answer }) => {
    emitToUser(String(to_user_id), 'call:accepted', { from_user_id: uid, room_id, answer });
  });

  socket.on('call:reject', ({ to_user_id, room_id, reason }) => {
    emitToUser(String(to_user_id), 'call:rejected', { from_user_id: uid, room_id, reason });
  });

  socket.on('call:end', ({ to_user_id, group_id, room_id }) => {
    if (to_user_id) emitToUser(String(to_user_id), 'call:ended', { from_user_id: uid, room_id });
    if (group_id) io.to(`group:${group_id}`).emit('call:ended', { from_user_id: uid, room_id });
  });

  socket.on('call:ice-candidate', ({ to_user_id, room_id, candidate }) => {
    emitToUser(String(to_user_id), 'call:ice-candidate', { from_user_id: uid, room_id, candidate });
  });

  // ─────────────────────────────────────────────────────────────
  // WEBRTC — GROUP VOICE / VIDEO
  // ─────────────────────────────────────────────────────────────

  socket.on('group:call:join', ({ group_id, call_type }) => {
    const room = `call:group:${group_id}`;
    socket.join(room);
    socket.to(room).emit('group:call:peer-joined', {
      user_id: uid,
      name:    user.full_name,
      avatar:  user.profile_photo,
      call_type,
    });
  });

  socket.on('group:call:leave', ({ group_id }) => {
    const room = `call:group:${group_id}`;
    socket.leave(room);
    io.to(room).emit('group:call:peer-left', { user_id: uid });
  });

  socket.on('group:call:offer', ({ group_id, to_user_id, offer }) => {
    emitToUser(String(to_user_id), 'group:call:offer', { group_id, from_user_id: uid, offer });
  });

  socket.on('group:call:answer', ({ group_id, to_user_id, answer }) => {
    emitToUser(String(to_user_id), 'group:call:answer', { group_id, from_user_id: uid, answer });
  });

  socket.on('group:call:ice', ({ group_id, to_user_id, candidate }) => {
    emitToUser(String(to_user_id), 'group:call:ice', { group_id, from_user_id: uid, candidate });
  });

  // ─────────────────────────────────────────────────────────────
  // PRESENCE
  // ─────────────────────────────────────────────────────────────

  socket.on('presence:get', (userIds = [], cb) => {
    const result = {};
    userIds.forEach((id) => { result[id] = isOnline(String(id)); });
    cb?.(result);
  });

  // ─────────────────────────────────────────────────────────────
  // CLASS EVENTS (teacher broadcasts to all students)
  // ─────────────────────────────────────────────────────────────

  socket.on('class:announcement', ({ class_id, message }) => {
    socket.to(`class:${class_id}`).emit('class:announcement', {
      class_id,
      from:    { id: uid, name: user.full_name },
      message,
      at:      new Date().toISOString(),
    });
  });

  // Pin update → broadcast to all students in class
  socket.on('class:pin-update', ({ class_id, item }) => {
    socket.to(`class:${class_id}`).emit('class:pin-update', { class_id, item });
  });

  // New assignment / quiz created → notify class
  socket.on('class:new-content', ({ class_id, content_type, title }) => {
    io.to(`class:${class_id}`).emit('class:new-content', {
      class_id, content_type, title,
      from: { id: uid, name: user.full_name },
    });
  });

  // ─────────────────────────────────────────────────────────────
  // DISCONNECT
  // ─────────────────────────────────────────────────────────────

  socket.on('disconnect', (reason) => {
    const sockets = connectedUsers.get(uid);
    if (sockets) {
      sockets.delete(socket.id);
      if (sockets.size === 0) {
        connectedUsers.delete(uid);
        userMeta.delete(uid);
        broadcastPresence(uid, false);
        notifyBackend('user.offline', { user_id: uid });
        console.log(`[-] ${user.full_name} (${uid}) disconnected [${reason}]`);
      }
    }
  });
});

// ─── Presence broadcast ────────────────────────────────────────
function broadcastPresence(userId, online) {
  io.emit('presence:update', {
    user_id:  userId,
    online,
    last_seen: online ? null : new Date().toISOString(),
  });
}

// ─── Notify Laravel backend ────────────────────────────────────
async function notifyBackend(event, payload) {
  try {
    await axios.post(
      `${BACKEND_URL}/api/internal/socket-event`,
      { event, payload },
      {
        headers: { 'X-Internal-Secret': API_SECRET, 'Content-Type': 'application/json' },
        timeout: 3000,
      }
    );
  } catch {
    // Non-critical — backend may handle these asynchronously
  }
}

// ─── Internal HTTP: broadcast from Laravel to Socket ──────────
// Laravel can POST to /broadcast to emit events to specific rooms
const internalApp = require('express')();
internalApp.use(require('express').json());

internalApp.post('/broadcast', (req, res) => {
  const secret = req.headers['x-internal-secret'];
  if (secret !== API_SECRET) return res.status(403).json({ error: 'Forbidden' });

  const { room, event, data } = req.body;
  if (!room || !event) return res.status(400).json({ error: 'Missing room or event' });

  if (room.startsWith('user:')) {
    emitToUser(room.replace('user:', ''), event, data);
  } else {
    io.to(room).emit(event, data);
  }

  res.json({ success: true, room, event });
});

// Start internal HTTP server on separate port
const INTERNAL_PORT = process.env.INTERNAL_PORT || 3002;
internalApp.listen(INTERNAL_PORT, () =>
  console.log(`[EduLink RT] Internal broadcast HTTP on port ${INTERNAL_PORT}`)
);

// ─── Start ────────────────────────────────────────────────────
httpServer.listen(PORT, () => {
  console.log(`[EduLink RT] Socket.IO listening on port ${PORT}`);
  console.log(`[EduLink RT] Allowed origins: ${ALLOWED.join(', ')}`);
});

process.on('uncaughtException',  (err) => console.error('[Uncaught]', err));
process.on('unhandledRejection', (err) => console.error('[Rejection]', err));
