-- =============================================================================
-- ec_lifeinvader — ESX Test-Daten (manuell importieren)
-- Datenbank: ESXLegacy_F9E16F (oder deine ESX-DB)
--
-- Import:
--   Laragon (HeidiSQL oder CLI):
--     C:\laragon\bin\mysql\mysql-8.4.7-winx64\bin\mysql.exe -u root ESXLegacy_F9E16F < seed_test_esx.sql
--   Oder aus dev/:  npm run seed:esx
--        sql\import_seed_test_esx.bat
--
-- Enthält:
--   · 5 ESX-Testcharaktere in `users` (char1:litest001 … litest005)
--   · LifeInvader-Guthaben
--   · 5 aktive Anzeigen (davon 1 anonym)
--   · 3 Chats + 11 Nachrichten
--
-- Hinweis: Spalte `phone_number` in `users` muss existieren (NPWD / manuell).
--   ALTER TABLE `users` ADD COLUMN `phone_number` VARCHAR(20) NULL DEFAULT NULL;
--
-- Bestehende Test-IDs werden vor dem Einfügen entfernt (nur char1:litest*).
-- =============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------------
-- Aufräumen (nur unsere Test-Identifiers)
-- ---------------------------------------------------------------------------
DELETE m FROM `lifeinvader_messages` m
INNER JOIN `lifeinvader_conversations` c ON c.id = m.conversation_id
WHERE c.ad_owner_identifier LIKE 'char1:litest%'
   OR c.guest_identifier LIKE 'char1:litest%';

DELETE FROM `lifeinvader_conversations`
WHERE ad_owner_identifier LIKE 'char1:litest%'
   OR guest_identifier LIKE 'char1:litest%';

DELETE FROM `lifeinvader_feeds`
WHERE identifier LIKE 'char1:litest%';

DELETE FROM `lifeinvader`
WHERE identifier LIKE 'char1:litest%';

DELETE FROM `users`
WHERE identifier LIKE 'char1:litest%';

-- ---------------------------------------------------------------------------
-- ESX Spieler (users)
-- Minimal ESX Legacy + Identity (+ phone_number)
-- ---------------------------------------------------------------------------
INSERT INTO `users` (
    `identifier`, `ssn`, `accounts`, `group`, `job`, `job_grade`,
    `firstname`, `lastname`, `dateofbirth`, `sex`, `height`, `disabled`, `phone_number`
) VALUES
(
    'char1:litest001',
    '900-01-0001',
    '{"bank":42500,"money":2500,"black_money":0}',
    'user', 'unemployed', 0,
    'Max', 'Mustermann', '1990-05-15', 'm', 182, 0,
    '557-3441'
),
(
    'char1:litest002',
    '900-01-0002',
    '{"bank":88000,"money":1200,"black_money":0}',
    'user', 'unemployed', 0,
    'Ken', 'Rosenberg', '1975-11-03', 'm', 175, 0,
    '555-8831'
),
(
    'char1:litest003',
    '900-01-0003',
    '{"bank":120000,"money":8000,"black_money":0}',
    'user', 'unemployed', 0,
    'Franklin', 'Clinton', '1988-04-02', 'm', 183, 0,
    '555-0147'
),
(
    'char1:litest004',
    '900-01-0004',
    '{"bank":35000,"money":900,"black_money":0}',
    'user', 'unemployed', 0,
    'Benny', 'Motorworks', '1982-08-20', 'm', 178, 0,
    '555-4089'
),
(
    'char1:litest005',
    '900-01-0005',
    '{"bank":15000,"money":600,"black_money":0}',
    'user', 'unemployed', 0,
    'Lena', 'Incognito', '1995-01-28', 'f', 168, 0,
    '555-7281'
);

-- ---------------------------------------------------------------------------
-- LifeInvader Konten
-- ---------------------------------------------------------------------------
INSERT INTO `lifeinvader` (`identifier`, `balance`, `ad_slot_bonus`, `ad_duration_bonus_days`) VALUES
('char1:litest001', 10600, 0, 0),
('char1:litest002', 8500, 0, 0),
('char1:litest003', 5200, 0, 0),
('char1:litest004', 3100, 0, 0),
('char1:litest005', 1800, 0, 0);

-- ---------------------------------------------------------------------------
-- Anzeigen (5 Stück)
-- ---------------------------------------------------------------------------
INSERT INTO `lifeinvader_feeds` (
    `identifier`, `author_name`, `title`, `content`, `category`, `phone`,
    `anonymous`, `premium`, `duration_hours`, `price_paid`, `status`,
    `spotlight_until`, `anonym_until`, `ticker_until`, `created_at`, `expires_at`
) VALUES
(
    'char1:litest002',
    'Rosenberg & Partner',
    'Biete Anwaltshilfe in allen Lebenslagen',
    'Vertretung vor Gericht, Beratung zu Zivil- und Strafsachen. Diskret und erfahren.',
    'dienstleistungen', '555-8831',
    0, NULL, 168, 450, 'active',
    NULL, NULL, NULL,
    DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_ADD(NOW(), INTERVAL 166 HOUR)
),
(
    'char1:litest003',
    'Franklin Clinton',
    'Verkauf: Sultan RS Vollgetunt',
    'Sultan RS mit Turbo, Bremsen und Karosserie max. Zustand sehr gut — VHB 120.000$.',
    'verkauf', '555-0147',
    0, '{"spotlight":{"days":1}}', 48, 520, 'active',
    DATE_ADD(NOW(), INTERVAL 20 HOUR), NULL, NULL,
    DATE_SUB(NOW(), INTERVAL 6 HOUR), DATE_ADD(NOW(), INTERVAL 42 HOUR)
),
(
    'char1:litest004',
    'Benny''s Motorworks',
    'Suche Mechaniker für Tuning-Werkstatt',
    'Vollzeit oder Teilzeit. Erfahrung mit Imports und Lowridern von Vorteil.',
    'jobs', '555-4089',
    0, NULL, 72, 380, 'active',
    NULL, NULL, NULL,
    DATE_SUB(NOW(), INTERVAL 12 HOUR), DATE_ADD(NOW(), INTERVAL 60 HOUR)
),
(
    'char1:litest005',
    'Lena Incognito',
    'Test Feed',
    'Ein einfacher Test Feed — anonym geschaltet. Nachrichten bitte über LifeInvader.',
    'sonstiges', '0815',
    1, '{"anonym":{"days":3}}', 168, 620, 'active',
    NULL, DATE_ADD(NOW(), INTERVAL 3 DAY), NULL,
    DATE_SUB(NOW(), INTERVAL 3 HOUR), DATE_ADD(NOW(), INTERVAL 165 HOUR)
),
(
    'char1:litest001',
    'Max Mustermann',
    'Suche Mitfahrgelegenheit nach Paleto',
    'Heute Abend Richtung Norden, zahle Sprit und Snacks. Bitte melden!',
    'sonstiges', '557-3441',
    0, NULL, 24, 240, 'active',
    NULL, NULL, NULL,
    DATE_SUB(NOW(), INTERVAL 1 HOUR), DATE_ADD(NOW(), INTERVAL 23 HOUR)
);

SET @feed_lawyer := (SELECT id FROM lifeinvader_feeds WHERE identifier = 'char1:litest002' AND title LIKE 'Biete Anwaltshilfe%' ORDER BY id DESC LIMIT 1);
SET @feed_car := (SELECT id FROM lifeinvader_feeds WHERE identifier = 'char1:litest003' AND title LIKE 'Verkauf: Sultan%' ORDER BY id DESC LIMIT 1);
SET @feed_anon := (SELECT id FROM lifeinvader_feeds WHERE identifier = 'char1:litest005' AND title = 'Test Feed' ORDER BY id DESC LIMIT 1);

-- ---------------------------------------------------------------------------
-- Unterhaltungen
-- ---------------------------------------------------------------------------
INSERT INTO `lifeinvader_conversations` (
    `feed_id`, `ad_owner_identifier`, `guest_identifier`, `guest_name`, `created_at`, `updated_at`
) VALUES
(@feed_lawyer, 'char1:litest002', 'char1:litest001', 'Max Mustermann', DATE_SUB(NOW(), INTERVAL 90 MINUTE), DATE_SUB(NOW(), INTERVAL 8 MINUTE)),
(@feed_car, 'char1:litest003', 'char1:litest001', 'Max Mustermann', DATE_SUB(NOW(), INTERVAL 45 MINUTE), DATE_SUB(NOW(), INTERVAL 20 MINUTE)),
(@feed_anon, 'char1:litest005', 'char1:litest001', 'Max Mustermann', DATE_SUB(NOW(), INTERVAL 30 MINUTE), DATE_SUB(NOW(), INTERVAL 2 MINUTE));

SET @conv_lawyer := (SELECT id FROM lifeinvader_conversations WHERE feed_id = @feed_lawyer AND guest_identifier = 'char1:litest001' LIMIT 1);
SET @conv_car := (SELECT id FROM lifeinvader_conversations WHERE feed_id = @feed_car AND guest_identifier = 'char1:litest001' LIMIT 1);
SET @conv_anon := (SELECT id FROM lifeinvader_conversations WHERE feed_id = @feed_anon AND guest_identifier = 'char1:litest001' LIMIT 1);

-- ---------------------------------------------------------------------------
-- Nachrichten
-- ---------------------------------------------------------------------------
INSERT INTO `lifeinvader_messages` (`conversation_id`, `sender_identifier`, `body`, `created_at`) VALUES
(@conv_lawyer, 'char1:litest001', 'Hallo, ich brauche Hilfe bei einer Verkehrsordnungswidrigkeit.', DATE_SUB(NOW(), INTERVAL 88 MINUTE)),
(@conv_lawyer, 'char1:litest002', 'Guten Tag — schildern Sie kurz den Fall, dann melde ich mich.', DATE_SUB(NOW(), INTERVAL 82 MINUTE)),
(@conv_lawyer, 'char1:litest001', 'Habe an einer roten Ampel zu spät gebremst…', DATE_SUB(NOW(), INTERVAL 75 MINUTE)),
(@conv_lawyer, 'char1:litest002', 'Kein Problem, das kriegen wir hin. Rufen Sie mich an oder schreiben weiter.', DATE_SUB(NOW(), INTERVAL 8 MINUTE)),

(@conv_car, 'char1:litest001', 'Ist der Sultan noch verfügbar?', DATE_SUB(NOW(), INTERVAL 44 MINUTE)),
(@conv_car, 'char1:litest003', 'Ja — Probefahrt nach Absprache möglich.', DATE_SUB(NOW(), INTERVAL 38 MINUTE)),
(@conv_car, 'char1:litest001', 'Preis verhandelbar?', DATE_SUB(NOW(), INTERVAL 20 MINUTE)),

(@conv_anon, 'char1:litest001', 'Hallo, ist das Angebot noch aktuell?', DATE_SUB(NOW(), INTERVAL 28 MINUTE)),
(@conv_anon, 'char1:litest005', 'Ja, bitte kurz per Nachricht — bleibe anonym.', DATE_SUB(NOW(), INTERVAL 22 MINUTE)),
(@conv_anon, 'char1:litest001', 'Alles klar, danke!', DATE_SUB(NOW(), INTERVAL 2 MINUTE));

SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------------
-- Kurz-Check (optional auskommentieren)
-- ---------------------------------------------------------------------------
-- SELECT identifier, firstname, lastname, phone_number FROM users WHERE identifier LIKE 'char1:litest%';
-- SELECT id, identifier, author_name, title, anonymous FROM lifeinvader_feeds WHERE identifier LIKE 'char1:litest%';
-- SELECT c.id, c.feed_id, c.guest_name, COUNT(m.id) AS msgs
-- FROM lifeinvader_conversations c
-- LEFT JOIN lifeinvader_messages m ON m.conversation_id = c.id
-- WHERE c.ad_owner_identifier LIKE 'char1:litest%'
-- GROUP BY c.id;
