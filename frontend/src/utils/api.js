import axios from 'axios';
import toast from 'react-hot-toast';

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '/api',
  timeout: 30000,
  headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
});

// ─── Request: attach token ─────────────────────────────────────
api.interceptors.request.use((config) => {
  const stored = localStorage.getItem('edulink-auth');
  if (stored) {
    const { state } = JSON.parse(stored);
    if (state?.token) config.headers.Authorization = `Bearer ${state.token}`;
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

// ─── API methods ───────────────────────────────────────────────
export const authAPI = {
  register:       (d) => api.post('/auth/register', d, { headers: { 'Content-Type': 'multipart/form-data' } }),
  login:          (d) => api.post('/auth/login', d),
  logout:         ()  => api.post('/auth/logout'),
  me:             ()  => api.get('/auth/me'),
  updateProfile:  (d) => api.post('/auth/profile', d, { headers: { 'Content-Type': 'multipart/form-data' } }),
  changePassword: (d) => api.post('/auth/change-password', d),
  forgotPassword: (d) => api.post('/auth/forgot-password', d),
  resetPassword:  (d) => api.post('/auth/reset-password', d),
  verifyOtp:      (d) => api.post('/auth/verify-otp', d),
  updateSettings: (d) => api.put('/settings', d),
  googleLogin:    ()  => window.location.href = (import.meta.env.VITE_API_URL || 'http://localhost:8000/api') + '/auth/google',
};

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
};

export const lessonAPI = {
  list:           (cid)     => api.get(`/classes/${cid}/lessons`),
  create:         (cid,d)   => api.post(`/classes/${cid}/lessons`, d, { headers: { 'Content-Type': 'multipart/form-data' } }),
  get:            (cid,id)  => api.get(`/classes/${cid}/lessons/${id}`),
  update:         (cid,id,d)=> api.put(`/classes/${cid}/lessons/${id}`, d),
  delete:         (cid,id)  => api.delete(`/classes/${cid}/lessons/${id}`),
  bookmark:       (cid,id)  => api.post(`/classes/${cid}/lessons/${id}/bookmark`),
  addComment:     (cid,id,d)=> api.post(`/classes/${cid}/lessons/${id}/comments`, d),
  getComments:    (cid,id)  => api.get(`/classes/${cid}/lessons/${id}/comments`),
};

export const assignmentAPI = {
  list:           (cid)           => api.get(`/classes/${cid}/assignments`),
  create:         (cid,d)         => api.post(`/classes/${cid}/assignments`, d, { headers: { 'Content-Type': 'multipart/form-data' } }),
  get:            (cid,id)        => api.get(`/classes/${cid}/assignments/${id}`),
  submit:         (cid,id,d)      => api.post(`/classes/${cid}/assignments/${id}/submit`, d, { headers: { 'Content-Type': 'multipart/form-data' } }),
  submissions:    (cid,id)        => api.get(`/classes/${cid}/assignments/${id}/submissions`),
  grade:          (cid,id,sid,d)  => api.post(`/classes/${cid}/assignments/${id}/grade/${sid}`, d),
};

export const quizAPI = {
  list:           (cid)     => api.get(`/classes/${cid}/quizzes`),
  create:         (cid,d)   => api.post(`/classes/${cid}/quizzes`, d),
  take:           (cid,qid) => api.get(`/classes/${cid}/quizzes/${qid}/take`),
  submit:         (cid,qid,d)=> api.post(`/classes/${cid}/quizzes/${qid}/submit`, d),
  analytics:      (cid,qid) => api.get(`/classes/${cid}/quizzes/${qid}/analytics`),
  delete:         (cid,qid) => api.delete(`/classes/${cid}/quizzes/${qid}`),
};

export const chatAPI = {
  conversations:  ()        => api.get('/chat/conversations'),
  privateMessages:(uid,p)   => api.get(`/chat/private/${uid}`, { params: { page: p } }),
  groups:         ()        => api.get('/chat/groups'),
  groupMessages:  (gid,p)   => api.get(`/chat/groups/${gid}`, { params: { page: p } }),
  createGroup:    (d)       => api.post('/chat/groups', d, { headers: { 'Content-Type': 'multipart/form-data' } }),
  joinGroup:      (code)    => api.post('/chat/groups/join', { join_code: code }),
  updateGroup:    (gid,d)   => api.put(`/chat/groups/${gid}`, d),
  leaveGroup:     (gid)     => api.delete(`/chat/groups/${gid}/leave`),
  addMember:      (gid,uid) => api.post(`/chat/groups/${gid}/members`, { user_id: uid }),
  removeMember:   (gid,uid) => api.delete(`/chat/groups/${gid}/members/${uid}`),
  searchMessages: (q)       => api.get('/chat/search', { params: { q } }),
  pinMessage:     (id)      => api.post(`/chat/messages/${id}/pin`),
  forwardMessage: (id,d)    => api.post(`/chat/messages/${id}/forward`, d),
};

export const meetingAPI = {
  list:   ()    => api.get('/meetings'),
  create: (d)   => api.post('/meetings', d),
  get:    (id)  => api.get(`/meetings/${id}`),
  start:  (id)  => api.post(`/meetings/${id}/start`),
  end:    (id)  => api.post(`/meetings/${id}/end`),
  token:  (id)  => api.get(`/meetings/${id}/token`),
};

export const aiAPI = {
  ask:                (d) => api.post('/ai/ask', d),
  generateQuiz:       (d) => api.post('/ai/quiz', d),
  summarize:          (d) => api.post('/ai/summarize', d),
  translate:          (d) => api.post('/ai/translate', d),
  generateAssignment: (d) => api.post('/ai/assignment', d),
  explain:            (d) => api.post('/ai/explain', d),
  providerStatus:     ()  => api.get('/ai/providers'),
};

export const notificationAPI = {
  list:       ()    => api.get('/notifications'),
  unreadCount:()    => api.get('/notifications/unread-count'),
  markRead:   (id)  => api.post(`/notifications/${id}/read`),
  markAllRead:()    => api.post('/notifications/read-all'),
  delete:     (id)  => api.delete(`/notifications/${id}`),
};

export const searchAPI = {
  search: (q, type) => api.get('/search', { params: { q, type } }),
};

export const progressAPI = {
  dashboard:       ()       => api.get('/dashboard'),
  myProgress:      ()       => api.get('/progress/my'),
  classProgress:   (cid)    => api.get(`/classes/${cid}/progress`),
  studentProgress: (cid,sid)=> api.get(`/classes/${cid}/progress/${sid}`),
};

export const adminAPI = {
  stats:      ()    => api.get('/admin/stats'),
  users:      (p)   => api.get('/admin/users', { params: p }),
  toggleUser: (id)  => api.post(`/admin/users/${id}/toggle`),
  deleteUser: (id)  => api.delete(`/admin/users/${id}`),
  classes:    ()    => api.get('/admin/classes'),
  reports:    ()    => api.get('/admin/reports'),
  aiUsage:    ()    => api.get('/admin/ai-usage'),
};

export const fileAPI = {
  upload:   (d, onProgress) => api.post('/files/upload', d, {
    headers: { 'Content-Type': 'multipart/form-data' },
    onUploadProgress: (e) => onProgress?.(Math.round((e.loaded * 100) / e.total)),
  }),
  download: (id)  => api.get(`/files/${id}/download`, { responseType: 'blob' }),
  delete:   (id)  => api.delete(`/files/${id}`),
};

export default api;
