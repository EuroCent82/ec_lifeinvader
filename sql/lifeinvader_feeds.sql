-- Geschaltete Anzeigen (Feed)
CREATE TABLE IF NOT EXISTS `lifeinvader_feeds` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(64) NOT NULL,
    `author_name` VARCHAR(128) NOT NULL,
    `title` VARCHAR(64) NOT NULL,
    `content` VARCHAR(500) NOT NULL,
    `category` VARCHAR(32) NOT NULL,
    `phone` VARCHAR(32) NOT NULL,
    `anonymous` TINYINT(1) NOT NULL DEFAULT 0,
    `premium` JSON NULL,
    `duration_days` INT UNSIGNED NOT NULL,
    `price_paid` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at` TIMESTAMP NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_lifeinvader_feeds_identifier` (`identifier`),
    KEY `idx_lifeinvader_feeds_expires` (`expires_at`),
    KEY `idx_lifeinvader_feeds_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
