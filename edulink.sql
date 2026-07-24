-- MariaDB dump 10.19  Distrib 10.4.32-MariaDB, for Win64 (AMD64)
--
-- Host: localhost    Database: edulink
-- ------------------------------------------------------
-- Server version	10.4.32-MariaDB

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Current Database: `edulink`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `edulink` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci */;

USE `edulink`;

--
-- Table structure for table `activity_log`
--

DROP TABLE IF EXISTS `activity_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `activity_log` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned DEFAULT NULL,
  `action` varchar(100) NOT NULL,
  `subject_type` varchar(50) DEFAULT NULL,
  `subject_id` bigint(20) unsigned DEFAULT NULL,
  `description` text DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` varchar(300) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_user` (`user_id`),
  KEY `idx_action` (`action`,`created_at`),
  KEY `idx_subject` (`subject_type`,`subject_id`),
  CONSTRAINT `fk_actlog_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `activity_log`
--

LOCK TABLES `activity_log` WRITE;
/*!40000 ALTER TABLE `activity_log` DISABLE KEYS */;
/*!40000 ALTER TABLE `activity_log` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ai_providers`
--

DROP TABLE IF EXISTS `ai_providers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ai_providers` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `display_name` varchar(100) DEFAULT NULL,
  `api_endpoint` varchar(300) DEFAULT NULL,
  `model_name` varchar(100) DEFAULT NULL,
  `daily_limit` int(11) DEFAULT 1000,
  `is_active` tinyint(1) DEFAULT 1,
  `priority` tinyint(4) DEFAULT 1,
  `reset_hour_utc` tinyint(4) DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ai_providers`
--

LOCK TABLES `ai_providers` WRITE;
/*!40000 ALTER TABLE `ai_providers` DISABLE KEYS */;
INSERT INTO `ai_providers` VALUES (1,'gemini','Google Gemini',NULL,'gemini-1.5-flash',1500,1,1,0),(2,'groq','Groq (Llama 3)',NULL,'llama3-8b-8192',14400,1,2,0),(3,'cohere','Cohere Command',NULL,'command-r',1000,1,3,0),(4,'mistral','Mistral AI',NULL,'mistral-7b-instruct',1000,1,4,0),(5,'together','Together AI',NULL,'mistral-7b-instruct',1000,1,5,0),(6,'huggingface','HuggingFace',NULL,'mistralai/Mistral-7B-Instruct-v0.2',99999,1,6,0);
/*!40000 ALTER TABLE `ai_providers` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ai_usage`
--

DROP TABLE IF EXISTS `ai_usage`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ai_usage` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `provider` varchar(50) NOT NULL,
  `user_id` bigint(20) unsigned DEFAULT NULL,
  `tokens_used` int(10) unsigned DEFAULT 0,
  `request_count` int(10) unsigned DEFAULT 0,
  `date` date NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_provider_user_date` (`provider`,`user_id`,`date`),
  KEY `idx_user` (`user_id`),
  CONSTRAINT `fk_ai_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ai_usage`
--

LOCK TABLES `ai_usage` WRITE;
/*!40000 ALTER TABLE `ai_usage` DISABLE KEYS */;
/*!40000 ALTER TABLE `ai_usage` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `announcements`
--

DROP TABLE IF EXISTS `announcements`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `announcements` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `class_id` bigint(20) unsigned NOT NULL,
  `author_id` bigint(20) unsigned NOT NULL,
  `title` varchar(300) NOT NULL,
  `body` text NOT NULL,
  `is_pinned` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_class` (`class_id`),
  KEY `idx_author` (`author_id`),
  FULLTEXT KEY `ft_search` (`title`,`body`),
  CONSTRAINT `fk_ann_author` FOREIGN KEY (`author_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_ann_class` FOREIGN KEY (`class_id`) REFERENCES `classes` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `announcements`
--

LOCK TABLES `announcements` WRITE;
/*!40000 ALTER TABLE `announcements` DISABLE KEYS */;
INSERT INTO `announcements` VALUES (1,1,2,'exam','we have exam yesterday',0,'2026-07-01 01:52:04','2026-07-01 01:52:04'),(2,1,2,'exam','Failed to post next week have exam',0,'2026-07-15 23:32:53','2026-07-15 23:32:53');
/*!40000 ALTER TABLE `announcements` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `assignment_attachments`
--

DROP TABLE IF EXISTS `assignment_attachments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `assignment_attachments` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `assignment_id` bigint(20) unsigned DEFAULT NULL,
  `submission_id` bigint(20) unsigned DEFAULT NULL,
  `uploader_id` bigint(20) unsigned NOT NULL,
  `original_name` varchar(300) NOT NULL,
  `stored_name` varchar(300) NOT NULL,
  `file_path` varchar(500) NOT NULL,
  `file_type` varchar(100) DEFAULT NULL,
  `file_size` bigint(20) unsigned DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_assign` (`assignment_id`),
  KEY `idx_sub` (`submission_id`),
  KEY `idx_uploader` (`uploader_id`),
  CONSTRAINT `fk_aa_assign` FOREIGN KEY (`assignment_id`) REFERENCES `assignments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_aa_sub` FOREIGN KEY (`submission_id`) REFERENCES `assignment_submissions` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_aa_uploader` FOREIGN KEY (`uploader_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `assignment_attachments`
--

LOCK TABLES `assignment_attachments` WRITE;
/*!40000 ALTER TABLE `assignment_attachments` DISABLE KEYS */;
INSERT INTO `assignment_attachments` VALUES (1,3,NULL,2,'7ßè¢ ßè¡ßììßêì ßê╡ßê¥ ßêÿßîÑßê¬ßï½ 2018 ßïô.ßê¥.pdf','KtTE0tgGcmpyf0emBcIYyVDijTEK4JUjwESfpVb7.pdf','http://localhost:8000/storage/assignments/1/KtTE0tgGcmpyf0emBcIYyVDijTEK4JUjwESfpVb7.pdf','application/pdf',807977,'2026-07-15 23:01:19'),(2,2,2,1,'8ßè¢ ßè¡ßììßêì ßê╡ßê¥ ßêÿßîÑßê¬ßï½ 2018 ßïô.ßê¥ (1).docx','d7GvkzkQR4Kv2vj7UZ2PdJrw6Grt29k4ARCJtwEw.docx','http://localhost:8000/storage/submissions/2/1/d7GvkzkQR4Kv2vj7UZ2PdJrw6Grt29k4ARCJtwEw.docx','application/vnd.openxmlformats-officedocument.wordprocessingml.document',49451,'2026-07-15 23:21:36');
/*!40000 ALTER TABLE `assignment_attachments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `assignment_submissions`
--

DROP TABLE IF EXISTS `assignment_submissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `assignment_submissions` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `assignment_id` bigint(20) unsigned NOT NULL,
  `student_id` bigint(20) unsigned NOT NULL,
  `text_answer` longtext DEFAULT NULL,
  `score` decimal(6,2) DEFAULT NULL,
  `feedback` text DEFAULT NULL,
  `status` enum('submitted','graded','returned','late') DEFAULT 'submitted',
  `submitted_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `graded_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_submission` (`assignment_id`,`student_id`),
  KEY `idx_student` (`student_id`),
  CONSTRAINT `fk_sub_assign` FOREIGN KEY (`assignment_id`) REFERENCES `assignments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_sub_student` FOREIGN KEY (`student_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `assignment_submissions`
--

LOCK TABLES `assignment_submissions` WRITE;
/*!40000 ALTER TABLE `assignment_submissions` DISABLE KEYS */;
INSERT INTO `assignment_submissions` VALUES (1,3,1,'this is mine answer and',30.00,NULL,'graded','2026-07-15 23:17:40','2026-07-15 23:22:55'),(2,2,1,'again test attached file',25.00,NULL,'graded','2026-07-15 23:21:36','2026-07-15 23:22:09');
/*!40000 ALTER TABLE `assignment_submissions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `assignments`
--

DROP TABLE IF EXISTS `assignments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `assignments` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `class_id` bigint(20) unsigned NOT NULL,
  `teacher_id` bigint(20) unsigned NOT NULL,
  `title` varchar(300) NOT NULL,
  `description` text NOT NULL,
  `max_score` decimal(6,2) DEFAULT 100.00,
  `due_date` timestamp NULL DEFAULT NULL,
  `allow_late` tinyint(1) DEFAULT 0,
  `is_pinned` tinyint(1) NOT NULL DEFAULT 0,
  `pinned_at` datetime DEFAULT NULL,
  `pinned_by` bigint(20) unsigned DEFAULT NULL,
  `is_published` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_class` (`class_id`),
  KEY `idx_teacher` (`teacher_id`),
  KEY `assignments_pinned_by_foreign` (`pinned_by`),
  FULLTEXT KEY `ft_search` (`title`,`description`),
  CONSTRAINT `assignments_pinned_by_foreign` FOREIGN KEY (`pinned_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_assign_class` FOREIGN KEY (`class_id`) REFERENCES `classes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_assign_teacher` FOREIGN KEY (`teacher_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `assignments`
--

LOCK TABLES `assignments` WRITE;
/*!40000 ALTER TABLE `assignments` DISABLE KEYS */;
INSERT INTO `assignments` VALUES (1,1,2,'chapter 5 homework fully','you must read all about assignmetn and i expect full answer',30.00,'2026-07-17 11:57:00',1,0,NULL,NULL,1,'2026-07-15 23:00:26','2026-07-15 23:00:26'),(2,1,2,'chapter 5 homework fully','you must read all about assignmetn and i expect full answer',30.00,'2026-07-17 11:57:00',1,0,NULL,NULL,1,'2026-07-15 23:00:35','2026-07-15 23:00:35'),(3,1,2,'chapter 5 homework fully','you must read all about assignmetn and i expect full answer',30.00,'2026-07-17 11:57:00',1,0,NULL,NULL,1,'2026-07-15 23:01:19','2026-07-15 23:01:19');
/*!40000 ALTER TABLE `assignments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `class_resources`
--

DROP TABLE IF EXISTS `class_resources`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `class_resources` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `class_id` bigint(20) unsigned NOT NULL,
  `uploader_id` bigint(20) unsigned NOT NULL,
  `title` varchar(300) NOT NULL,
  `description` text DEFAULT NULL,
  `type` enum('file','link','video') DEFAULT 'file',
  `file_path` varchar(500) DEFAULT NULL,
  `url` varchar(500) DEFAULT NULL,
  `file_size` bigint(20) unsigned DEFAULT NULL,
  `file_type` varchar(100) DEFAULT NULL,
  `download_count` int(10) unsigned DEFAULT 0,
  `is_published` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_class` (`class_id`),
  KEY `idx_uploader` (`uploader_id`),
  FULLTEXT KEY `ft_search` (`title`,`description`),
  CONSTRAINT `fk_cr_class` FOREIGN KEY (`class_id`) REFERENCES `classes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_cr_uploader` FOREIGN KEY (`uploader_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `class_resources`
--

LOCK TABLES `class_resources` WRITE;
/*!40000 ALTER TABLE `class_resources` DISABLE KEYS */;
/*!40000 ALTER TABLE `class_resources` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `classes`
--

DROP TABLE IF EXISTS `classes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `classes` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `school_id` bigint(20) unsigned DEFAULT NULL,
  `grade_id` bigint(20) unsigned DEFAULT NULL,
  `teacher_id` bigint(20) unsigned NOT NULL,
  `name` varchar(200) NOT NULL,
  `subject` varchar(100) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `cover_photo` varchar(500) DEFAULT NULL,
  `color` varchar(20) DEFAULT '#7C3AED',
  `join_code` varchar(12) NOT NULL,
  `invite_link` varchar(100) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `max_students` int(11) DEFAULT 200,
  `allow_student_chat` tinyint(1) DEFAULT 1,
  `archived_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_join_code` (`join_code`),
  UNIQUE KEY `uk_invite_link` (`invite_link`),
  KEY `idx_grade` (`grade_id`),
  KEY `idx_teacher` (`teacher_id`),
  KEY `idx_school_grade` (`school_id`,`grade_id`),
  KEY `idx_archived` (`archived_at`),
  FULLTEXT KEY `ft_name` (`name`),
  FULLTEXT KEY `ft_search` (`name`,`subject`,`description`),
  CONSTRAINT `fk_cls_grade` FOREIGN KEY (`grade_id`) REFERENCES `grades` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_cls_school` FOREIGN KEY (`school_id`) REFERENCES `schools` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_cls_teacher` FOREIGN KEY (`teacher_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `classes`
--

LOCK TABLES `classes` WRITE;
/*!40000 ALTER TABLE `classes` DISABLE KEYS */;
INSERT INTO `classes` VALUES (1,NULL,NULL,2,'my class',NULL,NULL,NULL,'#7C3AED','EH5BNE5B','t0IkTGe0klOzmLnQBHXK0PRnKpijIbWk',1,200,1,NULL,'2026-07-01 01:49:11','2026-07-01 01:49:11');
/*!40000 ALTER TABLE `classes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `email_logs`
--

DROP TABLE IF EXISTS `email_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `email_logs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned DEFAULT NULL,
  `to_email` varchar(180) NOT NULL,
  `type` varchar(60) NOT NULL COMMENT 'e.g. password_reset, login_otp, welcome, email_verify',
  `subject` varchar(300) NOT NULL,
  `status` enum('pending','sent','failed','bounced') DEFAULT 'pending',
  `provider` varchar(50) DEFAULT NULL COMMENT 'smtp driver used: smtp, mailgun, ses, etc.',
  `message_id` varchar(200) DEFAULT NULL COMMENT 'Provider tracking ID',
  `error` text DEFAULT NULL COMMENT 'SMTP/API error message when status=failed',
  `attempts` tinyint(3) unsigned DEFAULT 0,
  `sent_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_user` (`user_id`),
  KEY `idx_type_status` (`type`,`status`),
  KEY `idx_email_date` (`to_email`,`created_at`),
  CONSTRAINT `fk_elog_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `email_logs`
--

LOCK TABLES `email_logs` WRITE;
/*!40000 ALTER TABLE `email_logs` DISABLE KEYS */;
/*!40000 ALTER TABLE `email_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `email_queue`
--

DROP TABLE IF EXISTS `email_queue`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `email_queue` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned DEFAULT NULL,
  `to_email` varchar(180) NOT NULL,
  `type` varchar(60) NOT NULL,
  `subject` varchar(300) NOT NULL,
  `body_html` longtext DEFAULT NULL,
  `body_text` text DEFAULT NULL,
  `metadata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`metadata`)),
  `status` enum('queued','processing','sent','failed') DEFAULT 'queued',
  `attempts` tinyint(3) unsigned DEFAULT 0,
  `max_attempts` tinyint(3) unsigned DEFAULT 3,
  `next_retry_at` timestamp NULL DEFAULT NULL,
  `error` text DEFAULT NULL,
  `scheduled_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `sent_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_user` (`user_id`),
  KEY `idx_status_retry` (`status`,`next_retry_at`),
  CONSTRAINT `fk_eq_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `email_queue`
--

LOCK TABLES `email_queue` WRITE;
/*!40000 ALTER TABLE `email_queue` DISABLE KEYS */;
/*!40000 ALTER TABLE `email_queue` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `enrollments`
--

DROP TABLE IF EXISTS `enrollments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `enrollments` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `class_id` bigint(20) unsigned NOT NULL,
  `student_id` bigint(20) unsigned NOT NULL,
  `joined_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `is_class_leader` tinyint(1) DEFAULT 0,
  `is_banned` tinyint(1) DEFAULT 0,
  `progress_percent` tinyint(3) unsigned DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_enrollment` (`class_id`,`student_id`),
  KEY `idx_student` (`student_id`),
  KEY `idx_class` (`class_id`),
  CONSTRAINT `fk_enr_class` FOREIGN KEY (`class_id`) REFERENCES `classes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_enr_student` FOREIGN KEY (`student_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `enrollments`
--

LOCK TABLES `enrollments` WRITE;
/*!40000 ALTER TABLE `enrollments` DISABLE KEYS */;
INSERT INTO `enrollments` VALUES (1,1,1,'2026-07-01 01:53:11',0,0,0);
/*!40000 ALTER TABLE `enrollments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `files`
--

DROP TABLE IF EXISTS `files`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `files` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `uploader_id` bigint(20) unsigned NOT NULL,
  `related_type` varchar(50) DEFAULT NULL,
  `related_id` bigint(20) unsigned DEFAULT NULL,
  `original_name` varchar(300) NOT NULL,
  `stored_name` varchar(300) NOT NULL,
  `file_path` varchar(500) NOT NULL,
  `file_type` varchar(100) DEFAULT NULL,
  `file_size` bigint(20) unsigned DEFAULT NULL,
  `is_public` tinyint(1) DEFAULT 0,
  `download_count` int(10) unsigned DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_uploader` (`uploader_id`),
  KEY `idx_related` (`related_type`,`related_id`),
  CONSTRAINT `fk_file_uploader` FOREIGN KEY (`uploader_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `files`
--

LOCK TABLES `files` WRITE;
/*!40000 ALTER TABLE `files` DISABLE KEYS */;
INSERT INTO `files` VALUES (1,2,'lesson',1,'pexels-andrew-2248523.jpg','1782870585_pexels-andrew-2248523.jpg','lessons/1/1782870585_pexels-andrew-2248523.jpg','image/jpeg',2997287,0,0,'2026-07-01 01:49:45'),(2,2,'lesson',2,'HumanBodyExplorer-Rebuilt.docx','1784157820_HumanBodyExplorer-Rebuilt.docx','lessons/2/1784157820_HumanBodyExplorer-Rebuilt.docx','application/octet-stream',43562,0,0,'2026-07-15 23:23:40');
/*!40000 ALTER TABLE `files` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `grades`
--

DROP TABLE IF EXISTS `grades`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `grades` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `school_id` bigint(20) unsigned NOT NULL,
  `name` varchar(100) NOT NULL,
  `order_index` int(11) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_school` (`school_id`),
  CONSTRAINT `fk_grade_school` FOREIGN KEY (`school_id`) REFERENCES `schools` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `grades`
--

LOCK TABLES `grades` WRITE;
/*!40000 ALTER TABLE `grades` DISABLE KEYS */;
/*!40000 ALTER TABLE `grades` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `group_chat_members`
--

DROP TABLE IF EXISTS `group_chat_members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `group_chat_members` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `group_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `role` enum('member','admin','owner') DEFAULT 'member',
  `joined_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `last_read_at` timestamp NULL DEFAULT NULL,
  `is_muted` tinyint(1) DEFAULT 0,
  `is_banned` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_member` (`group_id`,`user_id`),
  KEY `idx_user` (`user_id`),
  KEY `idx_banned` (`group_id`,`is_banned`),
  CONSTRAINT `fk_gcm_group` FOREIGN KEY (`group_id`) REFERENCES `group_chats` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_gcm_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `group_chat_members`
--

LOCK TABLES `group_chat_members` WRITE;
/*!40000 ALTER TABLE `group_chat_members` DISABLE KEYS */;
INSERT INTO `group_chat_members` VALUES (1,1,2,'admin','2026-07-01 01:49:12','2026-07-17 01:44:43',0,0),(2,1,1,'member','2026-07-01 01:53:11','2026-07-17 01:46:09',0,0);
/*!40000 ALTER TABLE `group_chat_members` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `group_chats`
--

DROP TABLE IF EXISTS `group_chats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `group_chats` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(200) NOT NULL,
  `description` text DEFAULT NULL,
  `avatar` varchar(500) DEFAULT NULL,
  `type` enum('class','custom','private') DEFAULT 'custom',
  `class_id` bigint(20) unsigned DEFAULT NULL,
  `created_by` bigint(20) unsigned NOT NULL,
  `invite_link` varchar(100) DEFAULT NULL,
  `join_code` varchar(12) DEFAULT NULL,
  `is_public` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_gc_invite` (`invite_link`),
  UNIQUE KEY `uk_gc_code` (`join_code`),
  KEY `idx_class` (`class_id`),
  KEY `idx_created_by` (`created_by`),
  CONSTRAINT `fk_gc_class` FOREIGN KEY (`class_id`) REFERENCES `classes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_gc_creator` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `group_chats`
--

LOCK TABLES `group_chats` WRITE;
/*!40000 ALTER TABLE `group_chats` DISABLE KEYS */;
INSERT INTO `group_chats` VALUES (1,'my class',NULL,NULL,'class',1,2,NULL,'EH5BNE5B',0,'2026-07-01 01:49:12','2026-07-01 01:49:12');
/*!40000 ALTER TABLE `group_chats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lesson_bookmarks`
--

DROP TABLE IF EXISTS `lesson_bookmarks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lesson_bookmarks` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `lesson_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_bookmark` (`lesson_id`,`user_id`),
  KEY `idx_user` (`user_id`),
  CONSTRAINT `fk_lb_lesson` FOREIGN KEY (`lesson_id`) REFERENCES `lessons` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_lb_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lesson_bookmarks`
--

LOCK TABLES `lesson_bookmarks` WRITE;
/*!40000 ALTER TABLE `lesson_bookmarks` DISABLE KEYS */;
INSERT INTO `lesson_bookmarks` VALUES (1,1,1,'2026-07-15 22:55:50');
/*!40000 ALTER TABLE `lesson_bookmarks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lesson_comments`
--

DROP TABLE IF EXISTS `lesson_comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lesson_comments` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `lesson_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `parent_id` bigint(20) unsigned DEFAULT NULL,
  `body` text NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_lesson` (`lesson_id`),
  KEY `idx_user` (`user_id`),
  KEY `idx_parent` (`parent_id`),
  CONSTRAINT `fk_lc_lesson` FOREIGN KEY (`lesson_id`) REFERENCES `lessons` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_lc_parent` FOREIGN KEY (`parent_id`) REFERENCES `lesson_comments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_lc_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lesson_comments`
--

LOCK TABLES `lesson_comments` WRITE;
/*!40000 ALTER TABLE `lesson_comments` DISABLE KEYS */;
INSERT INTO `lesson_comments` VALUES (1,1,1,NULL,'its good teacher','2026-07-01 01:53:35','2026-07-01 01:53:35'),(2,1,2,NULL,'ok','2026-07-01 01:53:57','2026-07-01 01:53:57'),(3,2,1,NULL,'good lesson','2026-07-15 23:24:18','2026-07-15 23:24:18'),(4,2,2,NULL,'yes i','2026-07-15 23:24:42','2026-07-15 23:24:42');
/*!40000 ALTER TABLE `lesson_comments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lesson_reactions`
--

DROP TABLE IF EXISTS `lesson_reactions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lesson_reactions` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `lesson_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `type` enum('like','love','wow','helpful') DEFAULT 'like',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_reaction` (`lesson_id`,`user_id`),
  KEY `idx_user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lesson_reactions`
--

LOCK TABLES `lesson_reactions` WRITE;
/*!40000 ALTER TABLE `lesson_reactions` DISABLE KEYS */;
/*!40000 ALTER TABLE `lesson_reactions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lessons`
--

DROP TABLE IF EXISTS `lessons`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lessons` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `class_id` bigint(20) unsigned NOT NULL,
  `teacher_id` bigint(20) unsigned NOT NULL,
  `title` varchar(300) NOT NULL,
  `description` text DEFAULT NULL,
  `content` longtext DEFAULT NULL,
  `order_index` int(11) DEFAULT 0,
  `is_published` tinyint(1) DEFAULT 1,
  `allow_comments` tinyint(1) DEFAULT 1,
  `allow_downloads` tinyint(1) DEFAULT 1,
  `views` int(10) unsigned DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_class` (`class_id`),
  KEY `idx_teacher` (`teacher_id`),
  FULLTEXT KEY `ft_title` (`title`),
  FULLTEXT KEY `ft_search` (`title`,`description`),
  CONSTRAINT `fk_les_class` FOREIGN KEY (`class_id`) REFERENCES `classes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_les_teacher` FOREIGN KEY (`teacher_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lessons`
--

LOCK TABLES `lessons` WRITE;
/*!40000 ALTER TABLE `lessons` DISABLE KEYS */;
INSERT INTO `lessons` VALUES (1,1,2,'wallpaper','it work',NULL,0,1,1,1,14,'2026-07-01 01:49:45','2026-07-16 01:44:15'),(2,1,2,'ict 2','this is our next course',NULL,0,1,1,1,8,'2026-07-15 23:23:40','2026-07-17 01:45:48');
/*!40000 ALTER TABLE `lessons` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `meeting_participants`
--

DROP TABLE IF EXISTS `meeting_participants`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `meeting_participants` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `meeting_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `joined_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `left_at` timestamp NULL DEFAULT NULL,
  `duration_seconds` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_participant` (`meeting_id`,`user_id`),
  KEY `idx_user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `meeting_participants`
--

LOCK TABLES `meeting_participants` WRITE;
/*!40000 ALTER TABLE `meeting_participants` DISABLE KEYS */;
/*!40000 ALTER TABLE `meeting_participants` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `message_attachments`
--

DROP TABLE IF EXISTS `message_attachments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `message_attachments` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `message_id` bigint(20) unsigned NOT NULL,
  `uploader_id` bigint(20) unsigned NOT NULL,
  `original_name` varchar(300) NOT NULL,
  `stored_name` varchar(300) NOT NULL,
  `file_path` varchar(500) NOT NULL,
  `file_type` varchar(100) DEFAULT NULL,
  `file_size` bigint(20) unsigned DEFAULT NULL,
  `thumbnail` varchar(500) DEFAULT NULL,
  `duration` int(11) DEFAULT NULL COMMENT 'Duration in seconds for audio/video',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_message` (`message_id`),
  KEY `idx_uploader` (`uploader_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `message_attachments`
--

LOCK TABLES `message_attachments` WRITE;
/*!40000 ALTER TABLE `message_attachments` DISABLE KEYS */;
/*!40000 ALTER TABLE `message_attachments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `message_reads`
--

DROP TABLE IF EXISTS `message_reads`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `message_reads` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `message_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `read_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_read` (`message_id`,`user_id`),
  KEY `idx_user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `message_reads`
--

LOCK TABLES `message_reads` WRITE;
/*!40000 ALTER TABLE `message_reads` DISABLE KEYS */;
/*!40000 ALTER TABLE `message_reads` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `messages`
--

DROP TABLE IF EXISTS `messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `messages` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `sender_id` bigint(20) unsigned NOT NULL,
  `receiver_id` bigint(20) unsigned DEFAULT NULL,
  `group_id` bigint(20) unsigned DEFAULT NULL,
  `reply_to_id` bigint(20) unsigned DEFAULT NULL,
  `forwarded_from_id` bigint(20) unsigned DEFAULT NULL,
  `message_type` enum('text','image','video','audio','file','voice','system') DEFAULT 'text',
  `body` text DEFAULT NULL,
  `is_edited` tinyint(1) DEFAULT 0,
  `is_deleted` tinyint(1) DEFAULT 0,
  `deleted_for` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'JSON array of user_ids who deleted for themselves only' CHECK (`deleted_for` is null or json_valid(`deleted_for`)),
  `is_pinned` tinyint(1) DEFAULT 0,
  `reactions` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`reactions`)),
  `metadata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`metadata`)),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_sender` (`sender_id`),
  KEY `idx_receiver` (`receiver_id`),
  KEY `idx_reply` (`reply_to_id`),
  KEY `idx_forward` (`forwarded_from_id`),
  KEY `idx_private` (`sender_id`,`receiver_id`),
  KEY `idx_group` (`group_id`,`created_at`),
  KEY `idx_created` (`created_at`),
  KEY `idx_conversation` (`sender_id`,`receiver_id`,`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `messages`
--

LOCK TABLES `messages` WRITE;
/*!40000 ALTER TABLE `messages` DISABLE KEYS */;
INSERT INTO `messages` VALUES (1,2,1,NULL,NULL,NULL,'text','hi',0,0,NULL,0,NULL,NULL,'2026-06-26 13:21:48','2026-06-26 13:21:48'),(2,1,2,NULL,NULL,NULL,'text','hi',0,0,NULL,0,NULL,NULL,'2026-06-26 13:32:56','2026-06-26 13:32:56'),(3,1,2,NULL,NULL,NULL,'text','hi tesfa',0,0,NULL,0,NULL,NULL,'2026-06-26 13:33:16','2026-06-26 13:33:16'),(4,2,1,NULL,NULL,NULL,'text','hi',0,0,NULL,0,NULL,NULL,'2026-06-26 14:43:40','2026-06-26 14:43:40'),(5,2,1,NULL,NULL,NULL,'text','HI BEZA',0,0,NULL,0,NULL,NULL,'2026-06-26 14:54:04','2026-06-26 14:54:04'),(6,1,2,NULL,NULL,NULL,'text','HI',0,0,NULL,0,NULL,NULL,'2026-06-26 14:54:54','2026-06-26 14:54:54'),(7,1,2,NULL,NULL,NULL,'text','hi',0,0,NULL,0,NULL,NULL,'2026-06-26 15:02:09','2026-06-26 15:02:09'),(8,1,2,NULL,NULL,NULL,'text','by',0,0,NULL,0,NULL,NULL,'2026-06-26 15:02:58','2026-06-26 15:02:58'),(9,2,1,NULL,NULL,NULL,'text','hi tesfa',0,0,NULL,0,NULL,NULL,'2026-06-26 15:03:25','2026-06-26 15:03:25'),(10,1,2,NULL,NULL,NULL,'text','hi',0,0,NULL,0,NULL,NULL,'2026-06-26 15:09:24','2026-06-26 15:09:24'),(11,2,1,NULL,10,NULL,'text','hi bro',0,0,NULL,0,NULL,NULL,'2026-06-26 15:09:54','2026-06-26 15:09:54'),(12,2,1,NULL,NULL,NULL,'text','hi',0,0,NULL,0,NULL,NULL,'2026-06-26 19:07:42','2026-06-26 19:07:42'),(13,2,1,NULL,NULL,NULL,'text','hi',0,0,NULL,0,NULL,NULL,'2026-06-26 20:00:07','2026-06-26 20:00:07'),(14,1,2,NULL,NULL,NULL,'text','hi',0,0,NULL,0,NULL,NULL,'2026-06-26 20:01:37','2026-06-26 20:01:37'),(15,2,1,NULL,NULL,NULL,'text','hi agiain',0,0,NULL,0,NULL,NULL,'2026-06-26 20:04:35','2026-06-26 20:04:35'),(16,1,2,NULL,NULL,NULL,'text','ok',0,0,NULL,0,NULL,NULL,'2026-06-26 20:06:16','2026-06-26 20:06:16'),(17,2,1,NULL,16,NULL,'text','hi',0,0,NULL,0,NULL,NULL,'2026-06-26 20:07:52','2026-06-26 20:07:52'),(18,1,2,NULL,NULL,NULL,'text','ok hi again',0,0,NULL,0,NULL,NULL,'2026-06-26 20:08:51','2026-06-26 20:08:51'),(19,2,1,NULL,NULL,NULL,'text','what',0,0,NULL,0,NULL,NULL,'2026-06-26 20:09:10','2026-06-26 20:09:10'),(20,2,1,NULL,NULL,NULL,'text','is it work',0,0,NULL,0,NULL,NULL,'2026-06-26 20:11:21','2026-06-26 20:11:21'),(21,1,2,NULL,NULL,NULL,'text','ok',0,0,NULL,0,NULL,NULL,'2026-06-26 20:11:30','2026-06-26 20:11:30'),(22,1,NULL,1,NULL,NULL,'text','hi teacher',0,0,NULL,0,NULL,NULL,'2026-07-01 01:57:35','2026-07-01 01:57:35'),(23,2,1,NULL,NULL,NULL,'text','hi',0,0,NULL,0,NULL,NULL,'2026-07-15 22:06:14','2026-07-15 22:06:14'),(24,2,1,NULL,NULL,NULL,'text','hi',0,0,NULL,0,NULL,NULL,'2026-07-16 23:49:20','2026-07-16 23:49:20');
/*!40000 ALTER TABLE `messages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `migrations`
--

DROP TABLE IF EXISTS `migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `migrations` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `migration` varchar(255) NOT NULL,
  `batch` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `migrations`
--

LOCK TABLES `migrations` WRITE;
/*!40000 ALTER TABLE `migrations` DISABLE KEYS */;
INSERT INTO `migrations` VALUES (1,'2026_06_23_232041_create_personal_access_tokens_table',1),(2,'2026_06_23_000000_create_edulink_schema',2);
/*!40000 ALTER TABLE `migrations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `notifications` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `type` varchar(60) NOT NULL,
  `title` varchar(300) NOT NULL,
  `body` text DEFAULT NULL,
  `icon` varchar(50) DEFAULT 'bell',
  `related_type` varchar(50) DEFAULT NULL,
  `related_id` bigint(20) unsigned DEFAULT NULL,
  `action_url` varchar(500) DEFAULT NULL,
  `is_read` tinyint(1) DEFAULT 0,
  `pushed_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_user_read` (`user_id`,`is_read`),
  KEY `idx_created` (`created_at`),
  KEY `idx_unread` (`user_id`,`is_read`,`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notifications`
--

LOCK TABLES `notifications` WRITE;
/*!40000 ALTER TABLE `notifications` DISABLE KEYS */;
INSERT INTO `notifications` VALUES (1,2,'student_joined','Atsede Teguhan joined your class','Atsede joined my class','bell','class',1,'/classes/1/students',1,NULL,'2026-07-01 01:53:12'),(2,1,'new_lesson','≡ƒôÜ New lesson: ict 2','in my class','bell','lesson',2,'/classes/1/lessons/2',1,NULL,'2026-07-15 23:23:40'),(3,1,'new_announcement','≡ƒôó exam','my class','bell','class',1,'/classes/1',1,NULL,'2026-07-15 23:32:53');
/*!40000 ALTER TABLE `notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `otp_codes`
--

DROP TABLE IF EXISTS `otp_codes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `otp_codes` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `type` enum('login_otp','email_verify','password_reset') NOT NULL,
  `code` varchar(10) NOT NULL,
  `token` varchar(100) DEFAULT NULL COMMENT 'Long token for link-based reset (e.g. in email link)',
  `expires_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `is_used` tinyint(1) DEFAULT 0,
  `attempts` tinyint(3) unsigned DEFAULT 0,
  `max_attempts` tinyint(3) unsigned DEFAULT 5,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` varchar(300) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_user` (`user_id`),
  KEY `idx_lookup` (`user_id`,`type`,`is_used`,`expires_at`),
  KEY `idx_token` (`token`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `otp_codes`
--

LOCK TABLES `otp_codes` WRITE;
/*!40000 ALTER TABLE `otp_codes` DISABLE KEYS */;
INSERT INTO `otp_codes` VALUES (1,2,'password_reset','067460',NULL,'2026-07-16 21:52:59',0,0,5,'127.0.0.1',NULL,'2026-07-16 21:42:59'),(2,2,'password_reset','534375',NULL,'2026-07-16 21:54:17',0,0,5,'127.0.0.1',NULL,'2026-07-16 21:44:17'),(3,2,'password_reset','533651',NULL,'2026-07-16 22:02:57',0,0,5,'127.0.0.1',NULL,'2026-07-16 21:52:57'),(4,1,'login_otp','422342',NULL,'2026-07-16 22:53:16',0,0,5,'127.0.0.1',NULL,'2026-07-16 22:43:16'),(5,2,'login_otp','329731',NULL,'2026-07-17 01:15:25',0,0,5,'127.0.0.1',NULL,'2026-07-17 01:05:25'),(6,1,'password_reset','614984',NULL,'2026-07-17 01:16:44',0,0,5,'127.0.0.1',NULL,'2026-07-17 01:06:44'),(7,6,'email_verify','146970',NULL,'2026-07-17 01:18:55',0,0,5,'127.0.0.1',NULL,'2026-07-17 01:08:55');
/*!40000 ALTER TABLE `otp_codes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `personal_access_tokens`
--

DROP TABLE IF EXISTS `personal_access_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `personal_access_tokens` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `tokenable_type` varchar(255) NOT NULL,
  `tokenable_id` bigint(20) unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  `token` varchar(64) NOT NULL,
  `abilities` text DEFAULT NULL,
  `last_used_at` timestamp NULL DEFAULT NULL,
  `expires_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_token` (`token`),
  KEY `idx_tokenable` (`tokenable_type`,`tokenable_id`),
  KEY `idx_expires` (`expires_at`)
) ENGINE=InnoDB AUTO_INCREMENT=35 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `personal_access_tokens`
--

LOCK TABLES `personal_access_tokens` WRITE;
/*!40000 ALTER TABLE `personal_access_tokens` DISABLE KEYS */;
INSERT INTO `personal_access_tokens` VALUES (3,'App\\Models\\User',3,'auth_token','82c5180bca4186213efa3e2897ff7851a27c028338772013d035c8d319ee98bd','[\"*\"]','2026-06-23 23:11:19',NULL,'2026-06-23 20:49:46','2026-06-23 23:11:19'),(5,'App\\Models\\User',4,'auth_token','9c477faf113856a2c15145ba1605cc79eea9a8c025deb75f935a3ca3d25136b7','[\"*\"]','2026-06-26 14:34:52',NULL,'2026-06-26 13:24:20','2026-06-26 14:34:52'),(26,'App\\Models\\User',5,'auth_token','e9aedd9b3d0de3a04fc6e6951c3e0122178e78b4c3b0e0c480ee40ab829c2efb','[\"*\"]','2026-07-17 00:57:58','2026-08-16 00:57:45','2026-07-17 00:57:45','2026-07-17 00:57:58'),(34,'App\\Models\\User',2,'auth_token','f5dae7619cb931e4fd5807744e6bebec942309cb0425541275c0d0e4312b1de3','[\"*\"]','2026-07-18 00:08:55','2026-08-17 00:08:40','2026-07-18 00:08:40','2026-07-18 00:08:55');
/*!40000 ALTER TABLE `personal_access_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `quiz_attempts`
--

DROP TABLE IF EXISTS `quiz_attempts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `quiz_attempts` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `quiz_id` bigint(20) unsigned NOT NULL,
  `student_id` bigint(20) unsigned NOT NULL,
  `answers` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (`answers` is null or json_valid(`answers`)),
  `score` decimal(6,2) DEFAULT NULL,
  `max_score` decimal(6,2) DEFAULT NULL,
  `percentage` decimal(5,2) DEFAULT NULL,
  `passed` tinyint(1) DEFAULT NULL,
  `time_taken_seconds` int(11) DEFAULT NULL,
  `started_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `submitted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_student` (`student_id`),
  KEY `idx_quiz_student` (`quiz_id`,`student_id`),
  KEY `idx_score` (`quiz_id`,`percentage`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `quiz_attempts`
--

LOCK TABLES `quiz_attempts` WRITE;
/*!40000 ALTER TABLE `quiz_attempts` DISABLE KEYS */;
INSERT INTO `quiz_attempts` VALUES (1,4,1,'[{\"question_id\":4,\"selected_answer\":\"False\",\"is_correct\":false,\"points_earned\":0},{\"question_id\":5,\"selected_answer\":\"hkhl;kl;j;;jlk;\",\"is_correct\":false,\"points_earned\":0},{\"question_id\":6,\"selected_answer\":\"fghk\",\"is_correct\":false,\"points_earned\":0},{\"question_id\":7,\"selected_answer\":\"True\",\"is_correct\":false,\"points_earned\":0}]',0.00,100.00,0.00,0,40,'2026-07-15 22:47:35','2026-07-15 22:47:35'),(2,4,1,'[{\"question_id\":4,\"selected_answer\":\"True\",\"is_correct\":true,\"points_earned\":\"25.00\"},{\"question_id\":5,\"selected_answer\":\"hkhl;kl;j;;jlk;\",\"is_correct\":false,\"points_earned\":0},{\"question_id\":6,\"selected_answer\":\"fghk\",\"is_correct\":false,\"points_earned\":0},{\"question_id\":7,\"selected_answer\":\"True\",\"is_correct\":false,\"points_earned\":0}]',25.00,100.00,25.00,0,300,'2026-07-15 22:51:21','2026-07-15 22:51:21');
/*!40000 ALTER TABLE `quiz_attempts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `quiz_questions`
--

DROP TABLE IF EXISTS `quiz_questions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `quiz_questions` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `quiz_id` bigint(20) unsigned NOT NULL,
  `question_type` enum('multiple_choice','true_false','fill_blank','essay') NOT NULL,
  `question_text` text NOT NULL,
  `options` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`options`)),
  `correct_answer` text DEFAULT NULL,
  `points` decimal(5,2) DEFAULT 1.00,
  `order_index` int(11) DEFAULT 0,
  `explanation` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_quiz` (`quiz_id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `quiz_questions`
--

LOCK TABLES `quiz_questions` WRITE;
/*!40000 ALTER TABLE `quiz_questions` DISABLE KEYS */;
INSERT INTO `quiz_questions` VALUES (4,4,'true_false','djdghjghj',NULL,'True',25.00,0,'the answer is this!','2026-07-15 22:39:21'),(5,4,'essay','sggjfdgjf',NULL,'dgdjjgjfghjfghjghjjhghjfghjjhgfgj',25.00,1,'is question is hard or not?','2026-07-15 22:39:21'),(6,4,'multiple_choice','fgkk','[\"fhgfk\",\"fk\",\"fghk\",\"fhk\"]','fk',25.00,2,NULL,'2026-07-15 22:39:21'),(7,4,'true_false','djhhjh',NULL,'False',25.00,3,'its already false you must know this≡ƒÿè','2026-07-15 22:39:21');
/*!40000 ALTER TABLE `quiz_questions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `quizzes`
--

DROP TABLE IF EXISTS `quizzes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `quizzes` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `class_id` bigint(20) unsigned NOT NULL,
  `teacher_id` bigint(20) unsigned NOT NULL,
  `title` varchar(300) NOT NULL,
  `description` text DEFAULT NULL,
  `time_limit_minutes` int(11) DEFAULT NULL,
  `max_attempts` tinyint(4) DEFAULT 1,
  `shuffle_questions` tinyint(1) DEFAULT 0,
  `show_answers_after` tinyint(1) DEFAULT 1,
  `pass_score` decimal(5,2) DEFAULT 50.00,
  `is_published` tinyint(1) DEFAULT 0,
  `opens_at` timestamp NULL DEFAULT NULL,
  `closes_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `is_pinned` tinyint(1) NOT NULL DEFAULT 0,
  `pinned_at` datetime DEFAULT NULL,
  `pinned_by` bigint(20) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_class` (`class_id`),
  KEY `idx_teacher` (`teacher_id`),
  KEY `quizzes_pinned_by_foreign` (`pinned_by`),
  CONSTRAINT `quizzes_pinned_by_foreign` FOREIGN KEY (`pinned_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `quizzes`
--

LOCK TABLES `quizzes` WRITE;
/*!40000 ALTER TABLE `quizzes` DISABLE KEYS */;
INSERT INTO `quizzes` VALUES (4,1,2,'ict exam','you must examine your self by this exam',3,1,1,1,60.00,1,NULL,NULL,'2026-07-15 22:39:21','2026-07-15 22:39:21',0,NULL,NULL);
/*!40000 ALTER TABLE `quizzes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `roles`
--

DROP TABLE IF EXISTS `roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `roles` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(30) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_role_name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `roles`
--

LOCK TABLES `roles` WRITE;
/*!40000 ALTER TABLE `roles` DISABLE KEYS */;
INSERT INTO `roles` VALUES (1,'guest','2026-06-23 15:44:54'),(2,'student','2026-06-23 15:44:54'),(3,'teacher','2026-06-23 15:44:54'),(4,'school_admin','2026-06-23 15:44:54'),(5,'super_admin','2026-06-23 15:44:54');
/*!40000 ALTER TABLE `roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `schools`
--

DROP TABLE IF EXISTS `schools`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `schools` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(200) NOT NULL,
  `slug` varchar(200) NOT NULL,
  `description` text DEFAULT NULL,
  `logo` varchar(500) DEFAULT NULL,
  `cover_photo` varchar(500) DEFAULT NULL,
  `address` text DEFAULT NULL,
  `city` varchar(100) DEFAULT NULL,
  `country` varchar(100) DEFAULT 'Ethiopia',
  `phone` varchar(30) DEFAULT NULL,
  `email` varchar(150) DEFAULT NULL,
  `website` varchar(300) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `max_students` int(11) DEFAULT 1000,
  `plan` varchar(30) DEFAULT 'free',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_slug` (`slug`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `schools`
--

LOCK TABLES `schools` WRITE;
/*!40000 ALTER TABLE `schools` DISABLE KEYS */;
INSERT INTO `schools` VALUES (1,'miraf school','miraf-school-Tz9htI',NULL,NULL,NULL,NULL,NULL,'Ethiopia',NULL,NULL,NULL,1,1000,'free','2026-06-23 20:49:46','2026-06-23 20:49:46');
/*!40000 ALTER TABLE `schools` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `student_progress`
--

DROP TABLE IF EXISTS `student_progress`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `student_progress` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `student_id` bigint(20) unsigned NOT NULL,
  `class_id` bigint(20) unsigned NOT NULL,
  `lessons_viewed` int(10) unsigned DEFAULT 0,
  `lessons_total` int(10) unsigned DEFAULT 0,
  `assignments_submitted` int(10) unsigned DEFAULT 0,
  `assignments_total` int(10) unsigned DEFAULT 0,
  `avg_quiz_score` decimal(5,2) DEFAULT 0.00,
  `quizzes_taken` int(10) unsigned DEFAULT 0,
  `last_activity` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_progress` (`student_id`,`class_id`),
  KEY `idx_class` (`class_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `student_progress`
--

LOCK TABLES `student_progress` WRITE;
/*!40000 ALTER TABLE `student_progress` DISABLE KEYS */;
INSERT INTO `student_progress` VALUES (1,1,1,5,2,0,0,0.00,0,'2026-07-17 01:45:48','2026-07-17 01:45:48');
/*!40000 ALTER TABLE `student_progress` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_blocks`
--

DROP TABLE IF EXISTS `user_blocks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_blocks` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `blocker_id` bigint(20) unsigned NOT NULL,
  `blocked_id` bigint(20) unsigned NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_block` (`blocker_id`,`blocked_id`),
  KEY `idx_blocked` (`blocked_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_blocks`
--

LOCK TABLES `user_blocks` WRITE;
/*!40000 ALTER TABLE `user_blocks` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_blocks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_settings`
--

DROP TABLE IF EXISTS `user_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_settings` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `dark_mode` tinyint(1) DEFAULT 0,
  `language` varchar(10) DEFAULT 'en',
  `notifications_enabled` tinyint(1) DEFAULT 1,
  `email_notifications` tinyint(1) DEFAULT 1,
  `push_notifications` tinyint(1) DEFAULT 1,
  `sound_enabled` tinyint(1) DEFAULT 1,
  `show_online_status` tinyint(1) DEFAULT 1,
  `allow_messages_from` enum('everyone','classmates','nobody') DEFAULT 'everyone',
  `theme` varchar(20) DEFAULT 'purple',
  `font_size` enum('small','medium','large') DEFAULT 'medium',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_settings` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_settings`
--

LOCK TABLES `user_settings` WRITE;
/*!40000 ALTER TABLE `user_settings` DISABLE KEYS */;
INSERT INTO `user_settings` VALUES (1,1,1,'en',1,1,1,1,1,'everyone','green','medium','2026-06-23 20:18:31','2026-07-17 01:46:07'),(2,2,1,'en',1,1,1,1,1,'everyone','purple','medium','2026-06-23 20:26:36','2026-07-17 01:44:45'),(3,3,0,'en',1,1,1,1,1,'everyone','purple','medium','2026-06-23 20:49:46','2026-06-23 20:49:46'),(4,4,0,'en',1,1,1,1,1,'everyone','purple','medium','2026-06-26 13:24:20','2026-06-26 13:24:20'),(5,5,0,'en',1,1,1,1,1,'everyone','purple','medium','2026-07-17 00:57:44','2026-07-17 00:57:44'),(6,6,0,'en',1,1,1,1,1,'everyone','purple','medium','2026-07-17 01:08:55','2026-07-17 01:08:55');
/*!40000 ALTER TABLE `user_settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `users` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `school_id` bigint(20) unsigned DEFAULT NULL,
  `role_id` tinyint(3) unsigned NOT NULL DEFAULT 2,
  `first_name` varchar(80) NOT NULL,
  `last_name` varchar(80) NOT NULL,
  `username` varchar(60) DEFAULT NULL,
  `email` varchar(180) NOT NULL,
  `email_verified` tinyint(1) NOT NULL DEFAULT 0,
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `auth_provider` enum('email','google','both') NOT NULL DEFAULT 'email',
  `google_id` varchar(100) DEFAULT NULL,
  `profile_photo` text DEFAULT NULL,
  `cover_photo` varchar(500) DEFAULT NULL,
  `bio` text DEFAULT NULL,
  `grade` varchar(30) DEFAULT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `date_of_birth` date DEFAULT NULL,
  `gender` enum('male','female','other') DEFAULT NULL,
  `otp_login_enabled` tinyint(1) DEFAULT 0,
  `two_factor_enabled` tinyint(1) DEFAULT 0,
  `login_attempts` tinyint(3) unsigned DEFAULT 0,
  `locked_until` timestamp NULL DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `is_online` tinyint(1) DEFAULT 0,
  `last_seen` timestamp NULL DEFAULT NULL,
  `remember_token` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_email` (`email`),
  UNIQUE KEY `uk_username` (`username`),
  UNIQUE KEY `uk_google_id` (`google_id`),
  UNIQUE KEY `uq_google_id` (`google_id`),
  KEY `idx_email` (`email`),
  KEY `idx_school` (`school_id`),
  KEY `idx_role` (`role_id`),
  KEY `idx_provider` (`auth_provider`),
  KEY `idx_locked` (`locked_until`),
  FULLTEXT KEY `ft_name` (`first_name`,`last_name`),
  FULLTEXT KEY `ft_search` (`first_name`,`last_name`,`username`,`email`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,NULL,2,'Atsede','Teguhan','atsedeteguhan','atsedeteguhan2@gmail.com',0,'2026-06-23 20:18:30','$2y$12$veUctcXcDRCEc9kN5/SRlOHV9ocXpxkMwXw4ltefSOtJ453//0wli','google','100561821881745676411','https://lh3.googleusercontent.com/a/ACg8ocL-z1llwtyhUVOLdUiY1ihct3Xo5plE8FMO_5QcznmKe6NV9o0=s96-c',NULL,NULL,NULL,NULL,NULL,NULL,0,0,0,NULL,1,0,'2026-07-17 01:48:56',NULL,'2026-06-23 20:18:30','2026-07-17 01:48:56'),(2,NULL,3,'Tesfahun','Bayih','tesfahunbayih','tesfahunbaye6@gmail.com',0,'2026-06-23 20:26:36','$2y$12$zdhEGkvzrswqNL1P35LEMuQDrx8l6Hx6qxSUrTK3yBNjhYn4HWiK2','google','112083021837221096174','https://lh3.googleusercontent.com/a/ACg8ocJH21RM4lYPki7Wwp64QKUU-eHFcAMSPYZreDaM48eWK2L2lQOm=s96-c','covers/2/1TaHfdpwa0yn1b3KGCiDZJB3tsxEQlGDsonB4GcJ.jpg',NULL,NULL,NULL,NULL,NULL,0,0,0,NULL,1,1,'2026-07-18 00:08:40',NULL,'2026-06-23 20:26:36','2026-07-18 00:08:40'),(3,1,4,'tesfa','baye','tesfabaye','tesfa@gmail.com',0,NULL,'$2y$12$O8dUAGLbJrYt0mCstSzK8eLboRVEURHyAGhF/BAin6oyC4YZvj40y','email',NULL,'avatars/3/XaaLink0QR5xTAHdqBulcpY36etWWN0sNC9X3vEL.jpg',NULL,NULL,NULL,NULL,NULL,NULL,0,0,0,NULL,1,0,NULL,NULL,'2026-06-23 20:49:46','2026-06-23 22:54:45'),(4,NULL,4,'samuel','bayih','samuelbayih','shetesfa3@gmail.co',0,NULL,'$2y$12$RfPiypy2LjnNHdaWGR0Ex.6Vts5LvHtV8TvlYuGZq9/XUAh4pUwYC','email',NULL,NULL,NULL,NULL,'Grade 7',NULL,NULL,NULL,0,0,0,NULL,1,0,NULL,NULL,'2026-06-26 13:24:20','2026-06-26 13:24:20'),(5,NULL,2,'Anti','Gravity','anti.gravity','antig4124@gmail.com',0,NULL,'$2y$12$38FmGVgaKgeBO3odudYp0.YCIOk5Ym9.vtk/ZFqpnW7OOjT37aIci','email','104066067333144836727','https://lh3.googleusercontent.com/a/ACg8ocJpOcQ2pMIPnRY0G-71g5dTGJB35GcHoN3SCQgnC1jq3L5ucg=s96-c',NULL,NULL,NULL,NULL,NULL,NULL,0,0,0,NULL,1,1,'2026-07-17 00:57:45',NULL,'2026-07-17 00:57:44','2026-07-17 00:57:45'),(6,NULL,2,'shime','kebede','shime.kebede','codex3667@gmail.com',0,NULL,'$2y$12$TkR1XQ6uurnRm1FGs23wzO7xx9hY40hpOEquFhRlTNW1Pfj0sNvV2','email',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,0,0,NULL,1,0,'2026-07-17 01:09:34',NULL,'2026-07-17 01:08:53','2026-07-17 01:09:34');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `video_meetings`
--

DROP TABLE IF EXISTS `video_meetings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `video_meetings` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `class_id` bigint(20) unsigned DEFAULT NULL,
  `host_id` bigint(20) unsigned NOT NULL,
  `title` varchar(300) NOT NULL,
  `room_id` varchar(100) NOT NULL,
  `scheduled_at` timestamp NULL DEFAULT NULL,
  `started_at` timestamp NULL DEFAULT NULL,
  `ended_at` timestamp NULL DEFAULT NULL,
  `status` enum('scheduled','live','ended') DEFAULT 'scheduled',
  `is_recorded` tinyint(1) DEFAULT 0,
  `recording_url` varchar(500) DEFAULT NULL,
  `participant_count` int(11) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_room` (`room_id`),
  KEY `idx_class` (`class_id`),
  KEY `idx_host` (`host_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `video_meetings`
--

LOCK TABLES `video_meetings` WRITE;
/*!40000 ALTER TABLE `video_meetings` DISABLE KEYS */;
INSERT INTO `video_meetings` VALUES (1,NULL,2,'tesfa','edulink-EWTjZP2Z4fk0-1782487110',NULL,NULL,NULL,'scheduled',0,NULL,0,'2026-06-26 15:18:30','2026-06-26 15:18:30'),(2,NULL,2,'tesfa','edulink-IHe6UYUaackD-1784158541',NULL,NULL,NULL,'scheduled',0,NULL,0,'2026-07-15 23:35:41','2026-07-15 23:35:41');
/*!40000 ALTER TABLE `video_meetings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping routines for database 'edulink'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-07-25  2:06:31
