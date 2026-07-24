import axios from 'axios';
import toast from 'react-hot-toast';

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'https://edulink-backend-jxd2.onrender.com/api',
  timeout: 120000,
  headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
});

// ─── Request: attach token ─────────────────────────────────────
api.interceptors.request.use((config) => {
  const stored = localStorage.getItem('edulink-auth');
  if (stored) {
    try {
      const { state } = JSON.parse(stored);
      if (state?.token) config.headers.Authorization = `Bearer ${state.token}`;
    } catch {}
  }
  return config;
});

// ─── Response: handle errors globally ─────────────────────────
api.interceptors.response.use(
  (res) => res,
  (err) => {
    const status  = err.response?.status;
    const message = err.response?.data?.message || 'Something went wrong';

    if (status === 401) {
      localStorage.removeItem('edulink-auth');
      window.location.href = '/login';
      return Promise.reject(err);
    }

    if (status === 403) toast.error('You do not have permission to do that.');
    else if (status === 422) { /* Handled by forms */ }
    else if (status >= 500) toast.error('Server error. Please try again.');
    else if (!err.response)  toast.error('Network error. Check your connection.');

    return Promise.reject(err);
  }
);

// ─── Auth API ──────────────────────────────────────────────────
export const authAPI = {
  // ── Password Login ──
  login:          (d) => api.post('/auth/login', d),

  // ── OTP Login (2-step) ──
  sendLoginOtp:   (d) => api.post('/auth/send-login-otp', d),
  verifyLoginOtp: (d) => api.post('/auth/verify-login-otp', d),

  // ── Registration + email verification ──
  register:       (d) => api.post('/auth/register', d, { headers: { 'Content-Type': 'multipart/form-data' } }),
  verifyEmailOtp: (d) => api.post('/auth/verify-email', d),
  resendEmailOtp: (d) => api.post('/auth/resend-email-otp', d),

  // ── Password reset (existing OTP flow) ──
  forgotPassword: (d) => api.post('/auth/forgot-password', d),
  verifyOtp:      (d) => api.post('/auth/verify-otp', d),
  resetPassword:  (d) => api.post('/auth/reset-password', d),

  // ── Session ──
  logout:         ()  => api.post('/auth/logout'),
  me:             ()  => api.get('/auth/me'),
  updateProfile:  (d) => api.post('/auth/profile', d, { headers: { 'Content-Type': 'multipart/form-data' } }),
  changePassword: (d) => api.post('/auth/change-password', d),
  updateSettings: (d) => api.put('/settings', d),

  // ── Google OAuth ──
  googleLogin: (role) =>
    (window.location.href = `${import.meta.env.VITE_API_URL || 'https://edulink-backend-jxd2.onrender.com/api'}/auth/google?role=${role}`),
};

// ─── Class API ────────────────────────────────────────────────
export const classAPI = {
  list:           ()        => api.get('/classes'),
  create:         (d)       => api.post('/classes', d, { headers: { 'Content-Type': 'multipart/form-data' } }),
  get:            (id)      => api.get(`/classes/${id}`),
  update:         (id, d)   => api.put(`/classes/${id}`, d),
  join:           (code)    => api.post('/classes/join', { join_code: code }),
  leave:          (id)      => api.delete(`/classes/${id}/leave`),
  students:       (id)      => api.get(`/classes/${id}/students`),
  removeStudent:  (cid,sid) => api.delete(`/classes/${cid}/students/${sid}`),
  promoteLeader:  (cid,sid) => api.post(`/classes/${cid}/students/${sid}/promote`),
  regenerateCode: (id)      => api.post(`/classes/${id}/regenerate-code`),
  // Admin: assign teacher to class
  assignTeacher:  (id, tid) => api.post(`/classes/${id}/assign-teacher`, { teacher_id: tid }),
};

// ─── Lesson API ───────────────────────────────────────────────
export const lessonAPI = {
  list:       (cid)          => api.get(`/classes/${cid}/lessons`),
  create:     (cid, d)       => api.post(`/classes/${cid}/lessons`, d, { headers: { 'Content-Type': 'multipart/form-data' } }),
  get:        (cid, id)      => api.get(`/classes/${cid}/lessons/${id}`),
  update:     (cid, id, d)   => api.put(`/classes/${cid}/lessons/${id}`, d),
  delete:     (cid, id)      => api.delete(`/classes/${cid}/lessons/${id}`),
  bookmark:   (cid, id)      => api.post(`/classes/${cid}/lessons/${id}/bookmark`),
  addComment: (cid, id, d)   => api.post(`/classes/${cid}/lessons/${id}/comments`, d),
  getComments:(cid, id)      => api.get(`/classes/${cid}/lessons/${id}/comments`),
};

// ─── Assignment API ───────────────────────────────────────────
export const assignmentAPI = {
  list:        (cid)              => api.get(`/classes/${cid}/assignments`),
  create:      (cid, d)           => api.post(`/classes/${cid}/assignments`, d, { headers: { 'Content-Type': 'multipart/form-data' } }),
  get:         (cid, id)          => api.get(`/classes/${cid}/assignments/${id}`),
  update:      (cid, id, d)       => api.put(`/classes/${cid}/assignments/${id}`, d),
  delete:      (cid, id)          => api.delete(`/classes/${cid}/assignments/${id}`),
  submit:      (cid, id, d)       => api.post(`/classes/${cid}/assignments/${id}/submit`, d, { headers: { 'Content-Type': 'multipart/form-data' } }),
  submissions: (cid, id)          => api.get(`/classes/${cid}/assignments/${id}/submissions`),
  grade:       (cid, id, sid, d)  => api.post(`/classes/${cid}/assignments/${id}/grade/${sid}`, d),
  // ── Pin/unpin (teacher only) ──
  pin:         (cid, id)          => api.post(`/classes/${cid}/assignments/${id}/pin`),
};

// ─── Quiz API ─────────────────────────────────────────────────
export const quizAPI = {
  list:      (cid)       => api.get(`/classes/${cid}/quizzes`),
  create:    (cid, d)    => api.post(`/classes/${cid}/quizzes`, d),
  update:    (cid, qid, d) => api.put(`/classes/${cid}/quizzes/${qid}`, d),
  take:      (cid, qid)  => api.get(`/classes/${cid}/quizzes/${qid}/take`),
  submit:    (cid, qid, d) => api.post(`/classes/${cid}/quizzes/${qid}/submit`, d),
  analytics: (cid, qid)  => api.get(`/classes/${cid}/quizzes/${qid}/analytics`),
  // Returns all attempts with submitted_at, score, percentage, time_taken
  attempts:  (cid, qid)  => api.get(`/classes/${cid}/quizzes/${qid}/attempts`),
  delete:    (cid, qid)  => api.delete(`/classes/${cid}/quizzes/${qid}`),
  // ── Pin/unpin (teacher only) ──
  pin:       (cid, qid)  => api.post(`/classes/${cid}/quizzes/${qid}/pin`),
};

// ─── Chat API ─────────────────────────────────────────────────
export const chatAPI = {
  conversations:   ()         => api.get('/chat/conversations'),
  privateMessages: (uid, p)   => api.get(`/chat/private/${uid}`, { params: { page: p } }),
  sendPrivate:     (uid, d)   => api.post(`/chat/private/${uid}`, d),
  groups:          ()         => api.get('/chat/groups'),
  groupMessages:   (gid, p)   => api.get(`/chat/groups/${gid}`, { params: { page: p } }),
  sendGroup:       (gid, d)   => api.post(`/chat/group/${gid}`, d),
  createGroup:     (d)        => api.post('/chat/groups', d, { headers: { 'Content-Type': 'multipart/form-data' } }),
  joinGroup:       (code)     => api.post('/chat/groups/join', { join_code: code }),
  updateGroup:     (gid, d)   => api.put(`/chat/groups/${gid}`, d),
  leaveGroup:      (gid)      => api.delete(`/chat/groups/${gid}/leave`),
  addMember:       (gid, uid) => api.post(`/chat/groups/${gid}/members`, { user_id: uid }),
  removeMember:    (gid, uid) => api.delete(`/chat/groups/${gid}/members/${uid}`),
  searchMessages:  (q)        => api.get('/chat/search', { params: { q } }),
  pinMessage:      (id)       => api.post(`/chat/messages/${id}/pin`),
  forwardMessage:  (id, d)    => api.post(`/chat/messages/${id}/forward`, d),
  deleteMessage:   (id)       => api.delete(`/chat/messages/${id}`),
  editMessage:     (id, d)    => api.put(`/chat/messages/${id}`, d),
};

// ─── Meeting API ──────────────────────────────────────────────
export const meetingAPI = {
  list:   ()    => api.get('/meetings'),
  create: (d)   => api.post('/meetings', d),
  get:    (id)  => api.get(`/meetings/${id}`),
  start:  (id)  => api.post(`/meetings/${id}/start`),
  end:    (id)  => api.post(`/meetings/${id}/end`),
  token:  (id)  => api.get(`/meetings/${id}/token`),
};

// ─── AI API ───────────────────────────────────────────────────
export const aiAPI = {
  ask:                (d) => api.post('/ai/ask', d),
  generateQuiz:       (d) => api.post('/ai/quiz', d),
  summarize:          (d) => api.post('/ai/summarize', d),
  translate:          (d) => api.post('/ai/translate', d),
  generateAssignment: (d) => api.post('/ai/assignment', d),
  explain:            (d) => api.post('/ai/explain', d),
  providerStatus:     ()  => api.get('/ai/providers'),
};

// ─── Notification API ─────────────────────────────────────────
export const notificationAPI = {
  list:        ()    => api.get('/notifications'),
  unreadCount: ()    => api.get('/notifications/unread-count'),
  markRead:    (id)  => api.post(`/notifications/${id}/read`),
  markAllRead: ()    => api.post('/notifications/read-all'),
  delete:      (id)  => api.delete(`/notifications/${id}`),
};

// ─── Search API ───────────────────────────────────────────────
export const searchAPI = {
  search: (q, type) => api.get('/search', { params: { q, type } }),
};

// ─── Progress / Dashboard API ─────────────────────────────────
export const progressAPI = {
  dashboard:       ()        => api.get('/dashboard'),
  myProgress:      ()        => api.get('/progress/my'),
  classProgress:   (cid)     => api.get(`/classes/${cid}/progress`),
  studentProgress: (cid,sid) => api.get(`/classes/${cid}/progress/${sid}`),
};

// ─── Admin API ────────────────────────────────────────────────
export const adminAPI = {
  stats:          ()       => api.get('/admin/stats'),
  users:          (p)      => api.get('/admin/users', { params: p }),
  toggleUser:     (id)     => api.post(`/admin/users/${id}/toggle`),
  deleteUser:     (id)     => api.delete(`/admin/users/${id}`),
  classes:        ()       => api.get('/admin/classes'),
  reports:        ()       => api.get('/admin/reports'),
  aiUsage:        ()       => api.get('/admin/ai-usage'),
  assignTeacher:  (cid,tid)=> api.post(`/admin/classes/${cid}/assign-teacher`, { teacher_id: tid }),
  createClass:    (d)      => api.post('/admin/classes', d, { headers: { 'Content-Type': 'multipart/form-data' } }),
  teachers:       ()       => api.get('/admin/teachers'),
};

// ─── File API ─────────────────────────────────────────────────
export const fileAPI = {
  upload: (d, onProgress) => api.post('/files/upload', d, {
    headers: { 'Content-Type': 'multipart/form-data' },
    onUploadProgress: (e) => onProgress?.(Math.round((e.loaded * 100) / e.total)),
  }),
  download: (id) => api.get(`/files/${id}/download`, { responseType: 'blob' }),
  delete:   (id) => api.delete(`/files/${id}`),
};

export default api;
