-- ============================================================
-- EDULINK DATABASE SCHEMA v1.0
-- All 22 tables for the complete school platform
-- Engine: MySQL 8.0+  Charset: utf8mb4
-- ============================================================

CREATE DATABASE IF NOT EXISTS edulink CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE edulink;

-- ============================================================
-- 1. ROLES
-- ============================================================
CREATE TABLE roles (
    id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(30) NOT NULL UNIQUE,  -- guest, student, teacher, school_admin, super_admin
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO roles (name) VALUES ('guest'),('student'),('teacher'),('school_admin'),('super_admin');

-- ============================================================
-- 2. SCHOOLS
-- ============================================================
CREATE TABLE schools (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(200) NOT NULL UNIQUE,
    description TEXT,
    logo VARCHAR(500),
    cover_photo VARCHAR(500),
    address TEXT,
    city VARCHAR(100),
    country VARCHAR(100) DEFAULT 'Ethiopia',
    phone VARCHAR(30),
    email VARCHAR(150),
    website VARCHAR(300),
    is_active TINYINT(1) DEFAULT 1,
    max_students INT DEFAULT 1000,
    plan VARCHAR(30) DEFAULT 'free',  -- free, school, enterprise
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ============================================================
-- 3. USERS
-- ============================================================
CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id BIGINT UNSIGNED NULL,
    role_id TINYINT UNSIGNED NOT NULL DEFAULT 2,
    first_name VARCHAR(80) NOT NULL,
    last_name VARCHAR(80) NOT NULL,
    username VARCHAR(60) UNIQUE,
    email VARCHAR(180) NOT NULL UNIQUE,
    email_verified_at TIMESTAMP NULL,
    password VARCHAR(255) NOT NULL,
    google_id VARCHAR(100) NULL,
    profile_photo VARCHAR(500),
    cover_photo VARCHAR(500),
    bio TEXT,
    grade VARCHAR(30),
    phone VARCHAR(30),
    date_of_birth DATE,
    gender ENUM('male','female','other') NULL,
    is_active TINYINT(1) DEFAULT 1,
    is_online TINYINT(1) DEFAULT 0,
    last_seen TIMESTAMP NULL,
    remember_token VARCHAR(100) NULL,
    password_reset_token VARCHAR(100) NULL,
    password_reset_expires TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE SET NULL,
    FOREIGN KEY (role_id) REFERENCES roles(id),
    INDEX idx_email (email),
    INDEX idx_school (school_id),
    INDEX idx_role (role_id)
);

-- ============================================================
-- 4. USER SETTINGS
-- ============================================================
CREATE TABLE user_settings (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL UNIQUE,
    dark_mode TINYINT(1) DEFAULT 0,
    language VARCHAR(10) DEFAULT 'en',  -- en, am (Amharic)
    notifications_enabled TINYINT(1) DEFAULT 1,
    email_notifications TINYINT(1) DEFAULT 1,
    sound_enabled TINYINT(1) DEFAULT 1,
    show_online_status TINYINT(1) DEFAULT 1,
    allow_messages_from ENUM('everyone','classmates','nobody') DEFAULT 'everyone',
    theme VARCHAR(20) DEFAULT 'purple',
    font_size ENUM('small','medium','large') DEFAULT 'medium',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ============================================================
-- 5. GRADES (Grade 9, Grade 10, etc.)
-- ============================================================
CREATE TABLE grades (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(100) NOT NULL,  -- Grade 9, Grade 10, Year 1
    order_index INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
);

-- ============================================================
-- 6. CLASSES (Subjects inside grades)
-- ============================================================
CREATE TABLE classes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    school_id BIGINT UNSIGNED NOT NULL,
    grade_id BIGINT UNSIGNED NULL,
    teacher_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(200) NOT NULL,       -- Biology, Chemistry, Mathematics
    subject VARCHAR(100),
    description TEXT,
    cover_photo VARCHAR(500),
    color VARCHAR(20) DEFAULT '#7C3AED',
    join_code VARCHAR(12) NOT NULL UNIQUE,
    invite_link VARCHAR(100) UNIQUE,
    is_active TINYINT(1) DEFAULT 1,
    max_students INT DEFAULT 200,
    allow_student_chat TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
    FOREIGN KEY (grade_id) REFERENCES grades(id) ON DELETE SET NULL,
    FOREIGN KEY (teacher_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_join_code (join_code),
    INDEX idx_school_grade (school_id, grade_id)
);

-- ============================================================
-- 7. ENROLLMENTS (students ↔ classes)
-- ============================================================
CREATE TABLE enrollments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    class_id BIGINT UNSIGNED NOT NULL,
    student_id BIGINT UNSIGNED NOT NULL,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_class_leader TINYINT(1) DEFAULT 0,
    is_banned TINYINT(1) DEFAULT 0,
    progress_percent TINYINT UNSIGNED DEFAULT 0,
    UNIQUE KEY unique_enrollment (class_id, student_id),
    FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE,
    FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_student (student_id),
    INDEX idx_class (class_id)
);

-- ============================================================
-- 8. ANNOUNCEMENTS
-- ============================================================
CREATE TABLE announcements (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    class_id BIGINT UNSIGNED NOT NULL,
    author_id BIGINT UNSIGNED NOT NULL,
    title VARCHAR(300) NOT NULL,
    body TEXT NOT NULL,
    is_pinned TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE,
    FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ============================================================
-- 9. LESSONS
-- ============================================================
CREATE TABLE lessons (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    class_id BIGINT UNSIGNED NOT NULL,
    teacher_id BIGINT UNSIGNED NOT NULL,
    title VARCHAR(300) NOT NULL,
    description TEXT,
    content LONGTEXT,               -- rich text content
    order_index INT DEFAULT 0,
    is_published TINYINT(1) DEFAULT 1,
    allow_comments TINYINT(1) DEFAULT 1,
    allow_downloads TINYINT(1) DEFAULT 1,
    views INT UNSIGNED DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE,
    FOREIGN KEY (teacher_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ============================================================
-- 10. FILES (attached to lessons, assignments, messages, etc.)
-- ============================================================
CREATE TABLE files (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    uploader_id BIGINT UNSIGNED NOT NULL,
    related_type VARCHAR(50),       -- lesson, assignment, message, submission
    related_id BIGINT UNSIGNED NULL,
    original_name VARCHAR(300) NOT NULL,
    stored_name VARCHAR(300) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_type VARCHAR(100),         -- application/pdf, video/mp4, etc.
    file_size BIGINT UNSIGNED,      -- bytes
    is_public TINYINT(1) DEFAULT 0,
    download_count INT UNSIGNED DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (uploader_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_related (related_type, related_id)
);

-- ============================================================
-- 11. LESSON BOOKMARKS
-- ============================================================
CREATE TABLE lesson_bookmarks (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    lesson_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_bookmark (lesson_id, user_id),
    FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ============================================================
-- 12. LESSON COMMENTS
-- ============================================================
CREATE TABLE lesson_comments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    lesson_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    parent_id BIGINT UNSIGNED NULL,
    body TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES lesson_comments(id) ON DELETE CASCADE
);

-- ============================================================
-- 13. ASSIGNMENTS
-- ============================================================
CREATE TABLE assignments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    class_id BIGINT UNSIGNED NOT NULL,
    teacher_id BIGINT UNSIGNED NOT NULL,
    title VARCHAR(300) NOT NULL,
    description TEXT NOT NULL,
    max_score DECIMAL(6,2) DEFAULT 100,
    due_date TIMESTAMP NULL,
    allow_late TINYINT(1) DEFAULT 0,
    is_published TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE,
    FOREIGN KEY (teacher_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ============================================================
-- 14. ASSIGNMENT SUBMISSIONS
-- ============================================================
CREATE TABLE assignment_submissions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    assignment_id BIGINT UNSIGNED NOT NULL,
    student_id BIGINT UNSIGNED NOT NULL,
    text_answer LONGTEXT NULL,
    score DECIMAL(6,2) NULL,
    feedback TEXT NULL,
    status ENUM('submitted','graded','returned','late') DEFAULT 'submitted',
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    graded_at TIMESTAMP NULL,
    UNIQUE KEY unique_submission (assignment_id, student_id),
    FOREIGN KEY (assignment_id) REFERENCES assignments(id) ON DELETE CASCADE,
    FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ============================================================
-- 15. QUIZZES
-- ============================================================
CREATE TABLE quizzes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    class_id BIGINT UNSIGNED NOT NULL,
    teacher_id BIGINT UNSIGNED NOT NULL,
    title VARCHAR(300) NOT NULL,
    description TEXT,
    time_limit_minutes INT NULL,    -- NULL = no limit
    max_attempts TINYINT DEFAULT 1,
    shuffle_questions TINYINT(1) DEFAULT 0,
    show_answers_after TINYINT(1) DEFAULT 1,
    pass_score DECIMAL(5,2) DEFAULT 50.00,  -- percentage
    is_published TINYINT(1) DEFAULT 0,
    opens_at TIMESTAMP NULL,
    closes_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE,
    FOREIGN KEY (teacher_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ============================================================
-- 16. QUIZ QUESTIONS
-- ============================================================
CREATE TABLE quiz_questions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    quiz_id BIGINT UNSIGNED NOT NULL,
    question_type ENUM('multiple_choice','true_false','fill_blank','essay') NOT NULL,
    question_text TEXT NOT NULL,
    options JSON NULL,              -- ["A","B","C","D"] for multiple choice
    correct_answer TEXT NULL,       -- "A" or "True" or the answer text
    points DECIMAL(5,2) DEFAULT 1,
    order_index INT DEFAULT 0,
    explanation TEXT NULL,          -- shown after quiz
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (quiz_id) REFERENCES quizzes(id) ON DELETE CASCADE
);

-- ============================================================
-- 17. QUIZ ATTEMPTS
-- ============================================================
CREATE TABLE quiz_attempts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    quiz_id BIGINT UNSIGNED NOT NULL,
    student_id BIGINT UNSIGNED NOT NULL,
    answers JSON NOT NULL,           -- {"question_id": "answer", ...}
    score DECIMAL(6,2) NULL,
    max_score DECIMAL(6,2) NULL,
    percentage DECIMAL(5,2) NULL,
    passed TINYINT(1) NULL,
    time_taken_seconds INT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    submitted_at TIMESTAMP NULL,
    FOREIGN KEY (quiz_id) REFERENCES quizzes(id) ON DELETE CASCADE,
    FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_quiz_student (quiz_id, student_id)
);

-- ============================================================
-- 18. GROUP CHATS
-- ============================================================
CREATE TABLE group_chats (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    avatar VARCHAR(500),
    type ENUM('class','custom','private') DEFAULT 'custom',
    class_id BIGINT UNSIGNED NULL,      -- linked to a class if type=class
    created_by BIGINT UNSIGNED NOT NULL,
    invite_link VARCHAR(100) UNIQUE,
    join_code VARCHAR(12) UNIQUE,
    is_public TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
);

-- ============================================================
-- 19. GROUP CHAT MEMBERS
-- ============================================================
CREATE TABLE group_chat_members (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    group_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    role ENUM('member','admin','owner') DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_read_at TIMESTAMP NULL,
    is_muted TINYINT(1) DEFAULT 0,
    UNIQUE KEY unique_member (group_id, user_id),
    FOREIGN KEY (group_id) REFERENCES group_chats(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ============================================================
-- 20. MESSAGES
-- ============================================================
CREATE TABLE messages (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sender_id BIGINT UNSIGNED NOT NULL,
    -- target: either private chat or group chat
    receiver_id BIGINT UNSIGNED NULL,       -- private message target
    group_id BIGINT UNSIGNED NULL,          -- group message target
    reply_to_id BIGINT UNSIGNED NULL,       -- for threaded replies
    forwarded_from_id BIGINT UNSIGNED NULL,
    message_type ENUM('text','image','video','audio','file','voice','system') DEFAULT 'text',
    body TEXT NULL,
    is_edited TINYINT(1) DEFAULT 0,
    is_deleted TINYINT(1) DEFAULT 0,
    is_pinned TINYINT(1) DEFAULT 0,
    reactions JSON NULL,                    -- {"❤️": [user_ids], "👍": [user_ids]}
    metadata JSON NULL,                     -- file info, link preview, etc.
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (group_id) REFERENCES group_chats(id) ON DELETE CASCADE,
    FOREIGN KEY (reply_to_id) REFERENCES messages(id) ON DELETE SET NULL,
    INDEX idx_private (sender_id, receiver_id),
    INDEX idx_group (group_id, created_at),
    INDEX idx_created (created_at)
);

-- ============================================================
-- 21. MESSAGE READ RECEIPTS
-- ============================================================
CREATE TABLE message_reads (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    message_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    read_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_read (message_id, user_id),
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ============================================================
-- 22. VIDEO MEETINGS
-- ============================================================
CREATE TABLE video_meetings (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    class_id BIGINT UNSIGNED NULL,
    host_id BIGINT UNSIGNED NOT NULL,
    title VARCHAR(300) NOT NULL,
    room_id VARCHAR(100) NOT NULL UNIQUE,   -- Jitsi room name
    scheduled_at TIMESTAMP NULL,
    started_at TIMESTAMP NULL,
    ended_at TIMESTAMP NULL,
    status ENUM('scheduled','live','ended') DEFAULT 'scheduled',
    is_recorded TINYINT(1) DEFAULT 0,
    recording_url VARCHAR(500) NULL,
    participant_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE SET NULL,
    FOREIGN KEY (host_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ============================================================
-- 23. NOTIFICATIONS
-- ============================================================
CREATE TABLE notifications (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    type VARCHAR(60) NOT NULL,      -- new_message, new_assignment, quiz_result, etc.
    title VARCHAR(300) NOT NULL,
    body TEXT,
    icon VARCHAR(50) DEFAULT 'bell',
    related_type VARCHAR(50) NULL,  -- class, assignment, quiz, message
    related_id BIGINT UNSIGNED NULL,
    action_url VARCHAR(500) NULL,
    is_read TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_read (user_id, is_read),
    INDEX idx_created (created_at)
);

-- ============================================================
-- 24. AI USAGE TRACKER (for failover logic)
-- ============================================================
CREATE TABLE ai_usage (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    provider VARCHAR(50) NOT NULL,   -- gemini, groq, cohere, huggingface, mistral
    user_id BIGINT UNSIGNED NULL,
    tokens_used INT UNSIGNED DEFAULT 0,
    request_count INT UNSIGNED DEFAULT 0,
    date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_provider_date (provider, date),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- ============================================================
-- 25. AI PROVIDER CONFIG (live limits stored in DB)
-- ============================================================
CREATE TABLE ai_providers (
    id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100),
    api_endpoint VARCHAR(300),
    model_name VARCHAR(100),
    daily_limit INT DEFAULT 1000,
    is_active TINYINT(1) DEFAULT 1,
    priority TINYINT DEFAULT 1,      -- 1=first tried, 6=last fallback
    reset_hour_utc TINYINT DEFAULT 0
);

INSERT INTO ai_providers (name, display_name, model_name, daily_limit, priority) VALUES
('gemini',      'Google Gemini',     'gemini-1.5-flash',    1500, 1),
('groq',        'Groq (Llama 3)',    'llama3-8b-8192',      14400, 2),
('cohere',      'Cohere Command',    'command-r',            1000, 3),
('mistral',     'Mistral AI',        'mistral-7b-instruct',  1000, 4),
('together',    'Together AI',       'mistral-7b-instruct',  1000, 5),
('huggingface', 'HuggingFace',       'mistralai/Mistral-7B-Instruct-v0.2', 99999, 6);

-- ============================================================
-- 26. PROGRESS TRACKING
-- ============================================================
CREATE TABLE student_progress (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id BIGINT UNSIGNED NOT NULL,
    class_id BIGINT UNSIGNED NOT NULL,
    lessons_viewed INT UNSIGNED DEFAULT 0,
    lessons_total INT UNSIGNED DEFAULT 0,
    assignments_submitted INT UNSIGNED DEFAULT 0,
    assignments_total INT UNSIGNED DEFAULT 0,
    avg_quiz_score DECIMAL(5,2) DEFAULT 0,
    quizzes_taken INT UNSIGNED DEFAULT 0,
    last_activity TIMESTAMP NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_progress (student_id, class_id),
    FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE
);

-- ============================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================
CREATE INDEX idx_messages_conversation ON messages(sender_id, receiver_id, created_at);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read, created_at);
CREATE INDEX idx_quiz_attempts_score ON quiz_attempts(quiz_id, percentage);
