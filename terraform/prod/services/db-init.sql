-- ============================================================
-- db-init.sql — JOA 오픈뱅킹 DB 스키마 초기화
-- ============================================================
-- RDS(MySQL 8.0)에 접속하여 실행.
-- DB Name: joa
-- 테이블: account, admin, api, bank, dummy, member, product, transaction
--
-- 실행 방법:
--   mysql -h <RDS_ENDPOINT> -u admin -p joa < db-init.sql

CREATE DATABASE IF NOT EXISTS joa DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE joa;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;


-- ────────────────────────────────────────
-- Source: joa_member.sql
-- ────────────────────────────────────────
DROP TABLE IF EXISTS `member`;
CREATE TABLE `member` (
  `id` binary(16) NOT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `is_deleted` bit(1) DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `phone` varchar(255) DEFAULT NULL,
  `bank_id` binary(16) DEFAULT NULL,
  `dummy_id` binary(16) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FKd2xb9a1gvm10rr2y2ks6l8yig` (`bank_id`),
  KEY `FKoobt4mqgrkdwpqg6scrgkr2fk` (`dummy_id`),
  CONSTRAINT `FKd2xb9a1gvm10rr2y2ks6l8yig` FOREIGN KEY (`bank_id`) REFERENCES `bank` (`id`),
  CONSTRAINT `FKoobt4mqgrkdwpqg6scrgkr2fk` FOREIGN KEY (`dummy_id`) REFERENCES `dummy` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- ────────────────────────────────────────
-- Source: joa_dummy.sql
-- ────────────────────────────────────────
DROP TABLE IF EXISTS `dummy`;
CREATE TABLE `dummy` (
  `id` binary(16) NOT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `is_deleted` bit(1) DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `account_count` int DEFAULT NULL,
  `admin_id` binary(16) DEFAULT NULL,
  `member_count` int DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `transaction_count` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- ────────────────────────────────────────
-- Source: joa_product.sql
-- ────────────────────────────────────────
DROP TABLE IF EXISTS `product`;
CREATE TABLE `product` (
  `id` binary(16) NOT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `is_deleted` bit(1) DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `is_done` bit(1) DEFAULT NULL,
  `max_amount` bigint DEFAULT NULL,
  `min_amount` bigint DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `payment_type` tinyint DEFAULT NULL,
  `product_type` tinyint DEFAULT NULL,
  `rate` double DEFAULT NULL,
  `bank_id` binary(16) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FKpp8e5de1f71s8b3ens91et0t0` (`bank_id`),
  CONSTRAINT `FKpp8e5de1f71s8b3ens91et0t0` FOREIGN KEY (`bank_id`) REFERENCES `bank` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- ────────────────────────────────────────
-- Source: joa_bank.sql
-- ────────────────────────────────────────
DROP TABLE IF EXISTS `bank`;
CREATE TABLE `bank` (
  `id` binary(16) NOT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `is_deleted` bit(1) DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `admin_id` binary(16) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `uri` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- ────────────────────────────────────────
-- Source: joa_account.sql
-- ────────────────────────────────────────
DROP TABLE IF EXISTS `account`;
CREATE TABLE `account` (
  `id` varchar(255) NOT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `is_deleted` bit(1) DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `amount` bigint DEFAULT NULL,
  `balance` bigint DEFAULT NULL,
  `bank_id` binary(16) DEFAULT NULL,
  `deposit_account` varchar(255) DEFAULT NULL,
  `end_date` varchar(255) DEFAULT NULL,
  `is_dormant` bit(1) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `non_payment_num` int DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `payment_num` int DEFAULT NULL,
  `start_date` varchar(255) DEFAULT NULL,
  `term` int DEFAULT NULL,
  `transfer_limit` bigint DEFAULT NULL,
  `withdraw_account` varchar(255) DEFAULT NULL,
  `dummy_id` binary(16) DEFAULT NULL,
  `member_id` binary(16) DEFAULT NULL,
  `product_id` binary(16) DEFAULT NULL,
  `tax_type` tinyint DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FKk51nb78lueejxotwsba29p1lt` (`dummy_id`),
  KEY `FKr5j0huynd7nsv1s7e9vb8qvwo` (`member_id`),
  KEY `FKdjgw9kqy673mleqcnn6wfw5lr` (`product_id`),
  CONSTRAINT `FKdjgw9kqy673mleqcnn6wfw5lr` FOREIGN KEY (`product_id`) REFERENCES `product` (`id`),
  CONSTRAINT `FKk51nb78lueejxotwsba29p1lt` FOREIGN KEY (`dummy_id`) REFERENCES `dummy` (`id`),
  CONSTRAINT `FKr5j0huynd7nsv1s7e9vb8qvwo` FOREIGN KEY (`member_id`) REFERENCES `member` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- ────────────────────────────────────────
-- Source: joa_transaction.sql
-- ────────────────────────────────────────
DROP TABLE IF EXISTS `transaction`;
CREATE TABLE `transaction` (
  `id` binary(16) NOT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `is_deleted` bit(1) DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `amount` bigint DEFAULT NULL,
  `depositor_name` varchar(255) DEFAULT NULL,
  `from_account` varchar(255) DEFAULT NULL,
  `to_account` varchar(255) DEFAULT NULL,
  `dummy_id` binary(16) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK2y6q5tnhjqiksi2wd9k808hxn` (`dummy_id`),
  CONSTRAINT `FK2y6q5tnhjqiksi2wd9k808hxn` FOREIGN KEY (`dummy_id`) REFERENCES `dummy` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- ────────────────────────────────────────
-- Source: joa_admin.sql
-- ────────────────────────────────────────
DROP TABLE IF EXISTS `admin`;
CREATE TABLE `admin` (
  `admin_id` binary(16) NOT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `is_deleted` bit(1) DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `phone` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`admin_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- ────────────────────────────────────────
-- Source: joa_api.sql
-- ────────────────────────────────────────
DROP TABLE IF EXISTS `api`;
CREATE TABLE `api` (
  `api_key` binary(16) NOT NULL,
  `created_at` datetime(6) DEFAULT NULL,
  `is_deleted` bit(1) DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `admin_id` binary(16) DEFAULT NULL,
  PRIMARY KEY (`api_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


SET FOREIGN_KEY_CHECKS = 1;

