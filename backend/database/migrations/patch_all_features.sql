-- ═══════════════════════════════════════════════════════════════
-- EduLink — PATCH MIGRATION
-- Run this against your existing database to add all missing
-- columns and tables for the fixed features.
-- ═══════════════════════════════════════════════════════════════

SET FOREIGN_KEY_CHECKS = 0;

-- ─────────────────────────────────────────────────────────────
-- 1. OTP CODES TABLE
--    Stores every OTP issued (login, email verify, password reset)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `otp_codes` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`     BIGINT UNSIGNED NOT NULL,
  `type`        ENUM('login_otp','email_verify','password_reset') NOT NULL,
  `code`        VARCHAR(255)    NOT NULL COMMENT 'bcrypt hash of the 6-digit code',
  `expires_at`  DATETIME        NOT NULL,
  `used_at`     DATETIME        NULL,
  `ip_address`  VARCHAR(45)     NULL,
  `created_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_type` (`user_id`, `type`),
  KEY `idx_expires`   (`expires_at`),
  CONSTRAINT `fk_otp_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ─────────────────────────────────────────────────────────────
-- 2. USERS — add missing columns
-- ─────────────────────────────────────────────────────────────
ALTER TABLE `users`
  ADD COLUMN IF NOT EXISTS `google_id`       VARCHAR(100)  NULL           AFTER `password`,
  ADD COLUMN IF NOT EXISTS `email_verified`  TINYINT(1)    NOT NULL DEFAULT 0   AFTER `email`,
  ADD COLUMN IF NOT EXISTS `is_active`       TINYINT(1)    NOT NULL DEFAULT 1   AFTER `email_verified`,
  ADD COLUMN IF NOT EXISTS `grade`           VARCHAR(30)   NULL           AFTER `is_active`,
  ADD COLUMN IF NOT EXISTS `bio`             TEXT          NULL           AFTER `grade`,
  ADD COLUMN IF NOT EXISTS `is_online`       TINYINT(1)    NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `last_seen`       DATETIME      NULL,
  ADD UNIQUE  INDEX IF NOT EXISTS `uq_google_id` (`google_id`);

-- ─────────────────────────────────────────────────────────────
-- 3. QUIZ ATTEMPTS — add submitted_at + time_taken_seconds
-- ─────────────────────────────────────────────────────────────
ALTER TABLE `quiz_attempts`
  ADD COLUMN IF NOT EXISTS `submitted_at`        DATETIME       NULL          AFTER `score`,
  ADD COLUMN IF NOT EXISTS `time_taken_seconds`  INT UNSIGNED   NULL DEFAULT 0 AFTER `submitted_at`,
  ADD COLUMN IF NOT EXISTS `passed`              TINYINT(1)     NOT NULL DEFAULT 0 AFTER `time_taken_seconds`,
  ADD COLUMN IF NOT EXISTS `percentage`          DECIMAL(5,2)   NOT NULL DEFAULT 0.00 AFTER `passed`,
  ADD COLUMN IF NOT EXISTS `max_score`           INT UNSIGNED   NOT NULL DEFAULT 0 AFTER `percentage`,
  ADD KEY IF NOT EXISTS `idx_quiz_student`       (`quiz_id`, `student_id`);

-- Backfill skipped

-- ─────────────────────────────────────────────────────────────
-- 4. ASSIGNMENT SUBMISSIONS — add submitted_at column (may be named differently)
-- ─────────────────────────────────────────────────────────────
ALTER TABLE `assignment_submissions`
  ADD COLUMN IF NOT EXISTS `submitted_at`  DATETIME     NULL AFTER `status`,
  ADD COLUMN IF NOT EXISTS `graded_at`     DATETIME     NULL AFTER `feedback`,
  ADD COLUMN IF NOT EXISTS `status`        ENUM('submitted','late','graded') NOT NULL DEFAULT 'submitted';

-- Backfill skipped

-- ─────────────────────────────────────────────────────────────
-- 5. PIN SYSTEM — add is_pinned to assignments and quizzes
-- ─────────────────────────────────────────────────────────────
ALTER TABLE `assignments`
  ADD COLUMN IF NOT EXISTS `is_pinned`  TINYINT(1)  NOT NULL DEFAULT 0 AFTER `allow_late`,
  ADD COLUMN IF NOT EXISTS `pinned_at`  DATETIME    NULL AFTER `is_pinned`,
  ADD COLUMN IF NOT EXISTS `pinned_by`  BIGINT UNSIGNED NULL AFTER `pinned_at`,
  ADD COLUMN IF NOT EXISTS `due_date`   DATETIME    NULL,
  ADD COLUMN IF NOT EXISTS `allow_late` TINYINT(1)  NOT NULL DEFAULT 0,
  ADD KEY IF NOT EXISTS `idx_pinned`    (`class_id`, `is_pinned`),
  ADD CONSTRAINT IF NOT EXISTS `fk_asgn_pinned_by` FOREIGN KEY (`pinned_by`) REFERENCES `users`(`id`) ON DELETE SET NULL;

ALTER TABLE `quizzes`
  ADD COLUMN IF NOT EXISTS `is_pinned`       TINYINT(1) NOT NULL DEFAULT 0 AFTER `is_active`,
  ADD COLUMN IF NOT EXISTS `pinned_at`       DATETIME   NULL AFTER `is_pinned`,
  ADD COLUMN IF NOT EXISTS `pinned_by`       BIGINT UNSIGNED NULL AFTER `pinned_at`,
  ADD COLUMN IF NOT EXISTS `questions_count` INT UNSIGNED NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `pass_percentage` INT UNSIGNED NOT NULL DEFAULT 60,
  ADD KEY IF NOT EXISTS `idx_quiz_pinned`    (`class_id`, `is_pinned`),
  ADD CONSTRAINT IF NOT EXISTS `fk_quiz_pinned_by` FOREIGN KEY (`pinned_by`) REFERENCES `users`(`id`) ON DELETE SET NULL;

-- ─────────────────────────────────────────────────────────────
-- 6. MESSAGES — ensure all columns exist
-- ─────────────────────────────────────────────────────────────
ALTER TABLE `messages`
  ADD COLUMN IF NOT EXISTS `type`         ENUM('text','image','video','audio','file','voice_note') NOT NULL DEFAULT 'text',
  ADD COLUMN IF NOT EXISTS `file_meta`    JSON         NULL COMMENT 'URL, name, size, mime for media messages',
  ADD COLUMN IF NOT EXISTS `is_edited`    TINYINT(1)   NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `is_deleted`   TINYINT(1)   NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `is_pinned`    TINYINT(1)   NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `reply_to_id`  BIGINT UNSIGNED NULL,
  ADD COLUMN IF NOT EXISTS `delivered_at` DATETIME     NULL,
  ADD COLUMN IF NOT EXISTS `seen_at`      DATETIME     NULL,
  ADD COLUMN IF NOT EXISTS `reactions`    JSON         NULL COMMENT '{"😂":["userId1"],"❤️":["userId2"]}',
  ADD KEY IF NOT EXISTS `idx_msg_sender`     (`sender_id`),
  ADD KEY IF NOT EXISTS `idx_msg_receiver`   (`receiver_id`),
  ADD KEY IF NOT EXISTS `idx_msg_group`      (`group_id`),
  ADD KEY IF NOT EXISTS `idx_msg_created`    (`created_at`);

-- ─────────────────────────────────────────────────────────────
-- 7. GROUPS (chat) — ensure all columns exist
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `chat_groups` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`        VARCHAR(200)    NOT NULL,
  `description` TEXT            NULL,
  `avatar`      VARCHAR(500)    NULL,
  `type`        ENUM('group','class_group') NOT NULL DEFAULT 'group',
  `class_id`    BIGINT UNSIGNED NULL,
  `join_code`   VARCHAR(20)     NULL UNIQUE,
  `created_by`  BIGINT UNSIGNED NOT NULL,
  `school_id`   BIGINT UNSIGNED NULL,
  `is_active`   TINYINT(1)      NOT NULL DEFAULT 1,
  `created_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_class`    (`class_id`),
  KEY `idx_school`   (`school_id`),
  KEY `idx_join_code`(`join_code`),
  CONSTRAINT `fk_group_creator` FOREIGN KEY (`created_by`) REFERENCES `users`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `chat_group_members` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `group_id`   BIGINT UNSIGNED NOT NULL,
  `user_id`    BIGINT UNSIGNED NOT NULL,
  `role`       ENUM('member','admin') NOT NULL DEFAULT 'member',
  `joined_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_group_member` (`group_id`, `user_id`),
  CONSTRAINT `fk_gm_group` FOREIGN KEY (`group_id`) REFERENCES `chat_groups`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_gm_user`  FOREIGN KEY (`user_id`)  REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ─────────────────────────────────────────────────────────────
-- 8. QUIZ ANSWERS (per question tracking)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `quiz_attempt_answers` (
  `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `attempt_id`     BIGINT UNSIGNED NOT NULL,
  `question_id`    BIGINT UNSIGNED NOT NULL,
  `selected_answer` VARCHAR(500)   NULL,
  `is_correct`     TINYINT(1)      NOT NULL DEFAULT 0,
  `points_earned`  DECIMAL(5,2)    NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_attempt` (`attempt_id`),
  CONSTRAINT `fk_qaa_attempt` FOREIGN KEY (`attempt_id`) REFERENCES `quiz_attempts`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ─────────────────────────────────────────────────────────────
-- 9. SCHOOLS — ensure table exists
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `schools` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`       VARCHAR(200)    NOT NULL,
  `slug`       VARCHAR(220)    NOT NULL UNIQUE,
  `country`    VARCHAR(100)    NULL DEFAULT 'Ethiopia',
  `logo`       VARCHAR(500)    NULL,
  `is_active`  TINYINT(1)      NOT NULL DEFAULT 1,
  `created_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ─────────────────────────────────────────────────────────────
-- 10. NOTIFICATIONS — ensure table exists
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `notifications` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`    BIGINT UNSIGNED NOT NULL,
  `type`       VARCHAR(80)     NOT NULL,
  `title`      VARCHAR(255)    NOT NULL,
  `body`       TEXT            NULL,
  `data`       JSON            NULL,
  `is_read`    TINYINT(1)      NOT NULL DEFAULT 0,
  `read_at`    DATETIME        NULL,
  `created_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_notif_user` (`user_id`, `is_read`),
  KEY `idx_notif_type` (`type`),
  CONSTRAINT `fk_notif_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ─────────────────────────────────────────────────────────────
-- 11. USER SETTINGS — ensure table exists
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `user_settings` (
  `id`        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`   BIGINT UNSIGNED NOT NULL UNIQUE,
  `dark_mode` TINYINT(1)      NOT NULL DEFAULT 0,
  `language`  VARCHAR(10)     NOT NULL DEFAULT 'en',
  `notifications_enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `email_notifications`   TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_us_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ─────────────────────────────────────────────────────────────
-- 12. QUIZ QUESTIONS — ensure columns for correct_answer & explanation
-- ─────────────────────────────────────────────────────────────
ALTER TABLE `questions`
  ADD COLUMN IF NOT EXISTS `explanation`    TEXT    NULL  AFTER `correct_answer`,
  ADD COLUMN IF NOT EXISTS `order_index`    INT     NOT NULL DEFAULT 0 AFTER `explanation`,
  ADD KEY    IF NOT EXISTS `idx_q_quiz`     (`quiz_id`);

SET FOREIGN_KEY_CHECKS = 1;

-- ─────────────────────────────────────────────────────────────
-- Done — all patch columns and tables created.
-- ─────────────────────────────────────────────────────────────
SELECT 'EduLink patch migration completed successfully.' AS message;
