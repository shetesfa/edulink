/**
 * EduLink Real-Time Server
 * Node.js + Socket.io
 * Handles: live chat, typing indicators, online presence,
 *          notifications push, video meeting signals
 */

const express   = require('express');
const http      = require('http');
const { Server }= require('socket.io');
const jwt       = require('jsonwebtoken');
const axios     = require('axios');
const Redis     = require('ioredis');

const app    = express();
const server = http.createServer(app);

// ─── Redis client wrapper (fallback to In-Memory if connection fails or not installed) ────────
class MemoryRedis {
    constructor() {
        this.store = new Map();
        console.log("ℹ️ In-Memory Redis Mock active.");
    }
    async hset(key, field, value) {
        if (!this.store.has(key)) {
            this.store.set(key, new Map());
        }
        this.store.get(key).set(String(field), String(value));
        return 1;
    }
    async hdel(key, field) {
        if (this.store.has(key)) {
            this.store.get(key).delete(String(field));
        }
        return 1;
    }
    async hgetall(key) {
        if (!this.store.has(key)) return {};
        const obj = {};
        for (const [k, v] of this.store.get(key).entries()) {
            obj[k] = v;
        }
        return obj;
    }
    on(event, handler) {}
}

class RedisWrapper {
    constructor() {
        this.fallback = new MemoryRedis();
        this.useFallback = false;
        this.client = null;
        
        try {
            const client = new Redis({
                host: process.env.REDIS_HOST || '127.0.0.1',
                port: process.env.REDIS_PORT || 6379,
                connectTimeout: 2000,
                lazyConnect: true,
                retryStrategy(times) {
                    return null; // Don't retry, trigger connection failure immediately
                }
            });
            
            client.on('error', (err) => {
                if (!this.useFallback) {
                    console.warn('⚠️ Redis connection failed. Falling back to in-memory store.');
                    this.useFallback = true;
                }
            });

            this.client = client;
            client.connect().catch(() => {
                this.useFallback = true;
            });
        } catch (e) {
            console.warn('⚠️ Failed to initialize Redis. Falling back to in-memory store.');
            this.useFallback = true;
        }
    }

    async hset(key, field, value) {
        if (this.useFallback || !this.client) {
            return this.fallback.hset(key, field, value);
        }
        try {
            return await this.client.hset(key, field, value);
        } catch (e) {
            this.useFallback = true;
            return this.fallback.hset(key, field, value);
        }
    }

    async hdel(key, field) {
        if (this.useFallback || !this.client) {
            return this.fallback.hdel(key, field);
        }
        try {
            return await this.client.hdel(key, field);
        } catch (e) {
            this.useFallback = true;
            return this.fallback.hdel(key, field);
        }
    }

    async hgetall(key) {
        if (this.useFallback || !this.client) {
            return this.fallback.hgetall(key);
        }
        try {
            return await this.client.hgetall(key);
        } catch (e) {
            this.useFallback = true;
            return this.fallback.hgetall(key);
        }
    }
}

const redis = new RedisWrapper();

// ─── Socket.io server ─────────────────────────────────────────
const io = new Server(server, {
    cors: {
        origin: [
            process.env.APP_URL || 'https://edulink.com',
            'http://localhost:3000',
            'http://localhost:5173',
        ],
        methods: ['GET', 'POST'],
        credentials: true,
    },
    pingTimeout:  60000,
    pingInterval: 25000,
});

// ─── Auth middleware ───────────────────────────────────────────
io.use(async (socket, next) => {
    try {
        const token = socket.handshake.auth.token
            || socket.handshake.headers.authorization?.replace('Bearer ', '');

        if (!token) return next(new Error('No token provided'));

        // Verify with Laravel backend
        const response = await axios.get(
            `${process.env.LARAVEL_API}/api/auth/me`,
            { headers: { Authorization: `Bearer ${token}` }, timeout: 5000 }
        );

        socket.user = response.data.user;
        socket.token = token;
        next();
    } catch (err) {
        next(new Error('Authentication failed'));
    }
});

// ─── Connection handler ────────────────────────────────────────
io.on('connection', async (socket) => {
    const user = socket.user;
    console.log(`✅ Connected: ${user.full_name} (${user.id})`);

    // Mark user online in Redis
    await redis.hset('online_users', String(user.id), JSON.stringify({
        userId:   user.id,
        name:     user.full_name,
        avatar:   user.profile_photo,
        socketId: socket.id,
        since:    Date.now(),
    }));

    // Join personal room (for direct notifications)
    socket.join(`user:${user.id}`);

    // Notify contacts that user is online
    io.emit('user:online', { userId: user.id, name: user.full_name });

    // ── JOIN CLASS ROOMS ────────────────────────────────────────
    socket.on('join:class', (classId) => {
        socket.join(`class:${classId}`);
        console.log(`${user.full_name} joined class room ${classId}`);
    });

    socket.on('leave:class', (classId) => {
        socket.leave(`class:${classId}`);
    });

    // ── JOIN GROUP CHAT ROOM ────────────────────────────────────
    socket.on('join:group', (groupId) => {
        socket.join(`group:${groupId}`);
    });

    socket.on('leave:group', (groupId) => {
        socket.leave(`group:${groupId}`);
    });

    // ─────────────────────────────────────────────────────────────
    // PRIVATE MESSAGING
    // ─────────────────────────────────────────────────────────────
    socket.on('message:private', async (data) => {
        /* data = { receiverId, body, type, replyToId, fileId } */
        try {
            // Save via Laravel API
            const res = await axios.post(
                `${process.env.LARAVEL_API}/api/chat/private/${data.receiverId}`,
                data,
                { headers: { Authorization: `Bearer ${socket.token}` } }
            );

            const message = res.data.message;

            // Emit to sender (confirmation)
            socket.emit('message:sent', message);

            // Emit to receiver
            io.to(`user:${data.receiverId}`).emit('message:private', {
                ...message,
                sender: {
                    id:     user.id,
                    name:   user.full_name,
                    avatar: user.profile_photo,
                },
            });
        } catch (err) {
            socket.emit('message:error', { error: 'Failed to send message' });
        }
    });

    // ─────────────────────────────────────────────────────────────
    // GROUP MESSAGING
    // ─────────────────────────────────────────────────────────────
    socket.on('message:group', async (data) => {
        /* data = { groupId, body, type, replyToId, fileId } */
        try {
            const res = await axios.post(
                `${process.env.LARAVEL_API}/api/chat/groups/${data.groupId}`,
                data,
                { headers: { Authorization: `Bearer ${socket.token}` } }
            );

            const message = res.data.message;

            // Broadcast to all group members
            io.to(`group:${data.groupId}`).emit('message:group', {
                ...message,
                sender: {
                    id:     user.id,
                    name:   user.full_name,
                    avatar: user.profile_photo,
                },
            });
        } catch (err) {
            socket.emit('message:error', { error: 'Failed to send message' });
        }
    });

    // ─────────────────────────────────────────────────────────────
    // MESSAGE ACTIONS
    // ─────────────────────────────────────────────────────────────
    socket.on('message:edit', async ({ messageId, body, groupId, receiverId }) => {
        try {
            await axios.put(
                `${process.env.LARAVEL_API}/api/chat/messages/${messageId}`,
                { body },
                { headers: { Authorization: `Bearer ${socket.token}` } }
            );

            const target = groupId ? `group:${groupId}` : `user:${receiverId}`;
            io.to(target).emit('message:edited', { messageId, body, editedAt: new Date() });
            socket.emit('message:edited', { messageId, body });
        } catch {}
    });

    socket.on('message:delete', async ({ messageId, groupId, receiverId }) => {
        try {
            await axios.delete(
                `${process.env.LARAVEL_API}/api/chat/messages/${messageId}`,
                { headers: { Authorization: `Bearer ${socket.token}` } }
            );

            const target = groupId ? `group:${groupId}` : `user:${receiverId}`;
            io.to(target).emit('message:deleted', { messageId });
            socket.emit('message:deleted', { messageId });
        } catch {}
    });

    socket.on('message:react', async ({ messageId, emoji, groupId, receiverId }) => {
        try {
            await axios.post(
                `${process.env.LARAVEL_API}/api/chat/messages/${messageId}/react`,
                { emoji },
                { headers: { Authorization: `Bearer ${socket.token}` } }
            );

            const target = groupId ? `group:${groupId}` : `user:${receiverId}`;
            io.to(target).emit('message:reacted', { messageId, emoji, userId: user.id });
        } catch {}
    });

    socket.on('message:read', async ({ messageId }) => {
        try {
            await axios.post(
                `${process.env.LARAVEL_API}/api/chat/messages/${messageId}/read`,
                {},
                { headers: { Authorization: `Bearer ${socket.token}` } }
            );
        } catch {}
    });

    // ─────────────────────────────────────────────────────────────
    // TYPING INDICATORS
    // ─────────────────────────────────────────────────────────────
    socket.on('typing:start', ({ targetId, isGroup }) => {
        const room = isGroup ? `group:${targetId}` : `user:${targetId}`;
        socket.to(room).emit('typing:start', {
            userId: user.id,
            name:   user.first_name,
        });
    });

    socket.on('typing:stop', ({ targetId, isGroup }) => {
        const room = isGroup ? `group:${targetId}` : `user:${targetId}`;
        socket.to(room).emit('typing:stop', { userId: user.id });
    });

    // ─────────────────────────────────────────────────────────────
    // VIDEO MEETING SIGNALS (WebRTC)
    // ─────────────────────────────────────────────────────────────
    socket.on('meeting:join', ({ meetingId }) => {
        socket.join(`meeting:${meetingId}`);
        socket.to(`meeting:${meetingId}`).emit('meeting:user-joined', {
            userId: user.id,
            name:   user.full_name,
            avatar: user.profile_photo,
        });
    });

    socket.on('meeting:leave', ({ meetingId }) => {
        socket.leave(`meeting:${meetingId}`);
        socket.to(`meeting:${meetingId}`).emit('meeting:user-left', { userId: user.id });
    });

    socket.on('meeting:signal', ({ meetingId, to, signal }) => {
        io.to(`user:${to}`).emit('meeting:signal', {
            from:   user.id,
            signal: signal,
        });
    });

    socket.on('meeting:raise-hand', ({ meetingId }) => {
        io.to(`meeting:${meetingId}`).emit('meeting:hand-raised', { userId: user.id, name: user.first_name });
    });

    socket.on('meeting:lower-hand', ({ meetingId }) => {
        io.to(`meeting:${meetingId}`).emit('meeting:hand-lowered', { userId: user.id });
    });

    socket.on('meeting:mute-user', ({ meetingId, targetUserId }) => {
        io.to(`user:${targetUserId}`).emit('meeting:muted', { by: user.id });
    });

    // ─────────────────────────────────────────────────────────────
    // NOTIFICATIONS (push from server → client)
    // ─────────────────────────────────────────────────────────────
    // Laravel publishes notification events here via HTTP
    socket.on('notification:ack', ({ notificationId }) => {
        // Client acknowledged receiving notification
    });

    // ─────────────────────────────────────────────────────────────
    // DISCONNECT
    // ─────────────────────────────────────────────────────────────
    socket.on('disconnect', async () => {
        console.log(`❌ Disconnected: ${user.full_name}`);
        await redis.hdel('online_users', String(user.id));

        io.emit('user:offline', {
            userId:   user.id,
            lastSeen: new Date().toISOString(),
        });

        // Update last_seen in Laravel (fire-and-forget)
        axios.post(
            `${process.env.LARAVEL_API}/api/auth/offline`,
            {},
            { headers: { Authorization: `Bearer ${socket.token}` } }
        ).catch(() => {});
    });
});

// ─────────────────────────────────────────────────────────────
// HTTP ENDPOINTS (called by Laravel to push events)
// ─────────────────────────────────────────────────────────────
app.use(express.json());

// Secret middleware for internal calls only
app.use('/internal', (req, res, next) => {
    if (req.headers['x-socket-secret'] !== process.env.SOCKET_SECRET) {
        return res.status(401).json({ error: 'Unauthorized' });
    }
    next();
});

// Push notification to a user
app.post('/internal/notify', (req, res) => {
    const { userId, notification } = req.body;
    io.to(`user:${userId}`).emit('notification', notification);
    res.json({ sent: true });
});

// Push notification to a class room
app.post('/internal/notify-class', (req, res) => {
    const { classId, event, data } = req.body;
    io.to(`class:${classId}`).emit(event, data);
    res.json({ sent: true });
});

// Push notification to a group
app.post('/internal/notify-group', (req, res) => {
    const { groupId, event, data } = req.body;
    io.to(`group:${groupId}`).emit(event, data);
    res.json({ sent: true });
});

// Get online users list
app.get('/internal/online-users', async (req, res) => {
    const users = await redis.hgetall('online_users');
    const parsed = Object.values(users || {}).map(u => JSON.parse(u));
    res.json({ online: parsed, count: parsed.length });
});

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', connections: io.engine.clientsCount });
});

// ─────────────────────────────────────────────────────────────
// START SERVER
// ─────────────────────────────────────────────────────────────
const PORT = process.env.SOCKET_PORT || 3001;
server.listen(PORT, () => {
    console.log(`🚀 EduLink Socket.io server running on port ${PORT}`);
});

module.exports = { io, redis };
