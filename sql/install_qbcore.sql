-- =============================================================================
-- ec_lifeinvader — QBCore · Datenbank-Schema (6 Tabellen)
-- Resource: ec_lifeinvader
-- Framework: QBCore (qb-core) · Config.Adapters.framework = 'qbcore'
-- Import:   mysql -u user -p datenbank < install_qbcore.sql
--
-- Spalte `identifier` = PlayerData.citizenid (z.B. ABC12345)
-- Bridge: LiBridge.Server.GetIdentifier(source) → citizenid
-- Config: Config.Adapters.framework = 'qbcore'
-- =============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE IF NOT EXISTS `lifeinvader` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(128) NOT NULL COMMENT 'QBCore PlayerData.citizenid',
    `balance` INT NOT NULL DEFAULT 0,
    `ad_slot_bonus` INT NOT NULL DEFAULT 0 COMMENT 'Zusätzliche aktive Anzeigen-Slots (Team)',
    `ad_duration_bonus_days` INT NOT NULL DEFAULT 0 COMMENT 'Zusätzliche max. Anzeigen-Laufzeit in Tagen (Team)',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_lifeinvader_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `lifeinvader_feeds` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(128) NOT NULL COMMENT 'QBCore citizenid (Besitzer)',
    `author_name` VARCHAR(128) NOT NULL,
    `title` VARCHAR(64) NOT NULL,
    `content` VARCHAR(500) NOT NULL,
    `category` VARCHAR(32) NOT NULL,
    `phone` VARCHAR(32) NOT NULL COMMENT 'PlayerData.charinfo.phone',
    `anonymous` TINYINT(1) NOT NULL DEFAULT 0,
    `premium` JSON NULL,
    `duration_hours` INT UNSIGNED NOT NULL,
    `price_paid` INT NOT NULL DEFAULT 0,
    `status` ENUM('active', 'blocked', 'deleted') NOT NULL DEFAULT 'active',
    `spotlight_until` TIMESTAMP NULL DEFAULT NULL,
    `anonym_until` TIMESTAMP NULL DEFAULT NULL,
    `ticker_until` TIMESTAMP NULL DEFAULT NULL,
    `ticker_enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `ticker_sort_order` INT NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at` TIMESTAMP NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_lifeinvader_feeds_identifier` (`identifier`),
    KEY `idx_lifeinvader_feeds_expires` (`expires_at`),
    KEY `idx_lifeinvader_feeds_category` (`category`),
    KEY `idx_lifeinvader_feeds_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `lifeinvader_categories` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `slug` VARCHAR(32) NOT NULL,
    `label` VARCHAR(64) NOT NULL,
    `icon` VARCHAR(32) NOT NULL DEFAULT 'ellipsis',
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `sort_order` INT NOT NULL DEFAULT 0,
    `created_by` VARCHAR(128) NULL COMMENT 'QBCore citizenid (Team)',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_lifeinvader_categories_slug` (`slug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `lifeinvader_ticker` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `message` VARCHAR(255) NOT NULL,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `sort_order` INT NOT NULL DEFAULT 0,
    `created_by` VARCHAR(128) NULL COMMENT 'QBCore citizenid (Team)',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_lifeinvader_ticker_sort` (`sort_order`, `enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `lifeinvader_vouchers` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `code` VARCHAR(32) NOT NULL COMMENT 'LIV-1234-5678',
    `value` INT NOT NULL,
    `expires_at` TIMESTAMP NULL DEFAULT NULL,
    `max_uses` INT UNSIGNED NULL DEFAULT NULL,
    `uses_count` INT UNSIGNED NOT NULL DEFAULT 0,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `per_player_once` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = jeder Spieler max. einmal',
    `internal_note` VARCHAR(512) NULL DEFAULT NULL COMMENT 'Interner Team-Hinweis',
    `created_by` VARCHAR(128) NOT NULL COMMENT 'QBCore citizenid (Team)',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_lifeinvader_vouchers_code` (`code`),
    KEY `idx_lifeinvader_vouchers_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `lifeinvader_voucher_redemptions` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `voucher_id` INT UNSIGNED NOT NULL,
    `identifier` VARCHAR(128) NOT NULL COMMENT 'QBCore citizenid',
    `redeemed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_lifeinvader_voucher_player` (`voucher_id`, `identifier`),
    KEY `idx_lifeinvader_voucher_redemptions_identifier` (`identifier`),
    CONSTRAINT `fk_lifeinvader_voucher_redemptions_voucher`
        FOREIGN KEY (`voucher_id`) REFERENCES `lifeinvader_vouchers` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `lifeinvader_refunds` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `feed_id` INT UNSIGNED NULL,
    `identifier` VARCHAR(128) NOT NULL COMMENT 'QBCore citizenid (Empfänger)',
    `amount` INT NOT NULL,
    `reason` VARCHAR(255) NULL,
    `issued_by` VARCHAR(128) NOT NULL COMMENT 'QBCore citizenid (Team)',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_lifeinvader_refunds_feed` (`feed_id`),
    KEY `idx_lifeinvader_refunds_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `lifeinvader_blacklist` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(128) NOT NULL COMMENT 'QBCore citizenid',
    `reason` VARCHAR(255) NULL,
    `banned_by` VARCHAR(128) NOT NULL COMMENT 'Team-Identifier',
    `expires_at` TIMESTAMP NULL DEFAULT NULL COMMENT 'NULL = dauerhaft',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_lifeinvader_blacklist_identifier` (`identifier`),
    KEY `idx_lifeinvader_blacklist_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `lifeinvader_conversations` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `feed_id` INT UNSIGNED NOT NULL,
    `ad_owner_identifier` VARCHAR(128) NOT NULL,
    `guest_identifier` VARCHAR(128) NOT NULL COMMENT 'Interessent (nicht Inserent)',
    `guest_name` VARCHAR(128) NOT NULL DEFAULT 'Unbekannt',
    `ad_owner_last_read_at` TIMESTAMP NULL DEFAULT NULL,
    `guest_last_read_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_lifeinvader_conv_feed_guest` (`feed_id`, `guest_identifier`),
    KEY `idx_lifeinvader_conv_feed` (`feed_id`),
    KEY `idx_lifeinvader_conv_owner` (`ad_owner_identifier`),
    KEY `idx_lifeinvader_conv_guest` (`guest_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `lifeinvader_messages` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `conversation_id` INT UNSIGNED NOT NULL,
    `sender_identifier` VARCHAR(128) NOT NULL,
    `body` VARCHAR(500) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_lifeinvader_msg_conv_created` (`conversation_id`, `created_at`),
    CONSTRAINT `fk_lifeinvader_messages_conversation`
        FOREIGN KEY (`conversation_id`) REFERENCES `lifeinvader_conversations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;
