-- ec_lifeinvader — ESX Demo-Daten (Config.fake = true)
-- Wird nur geladen wenn lifeinvader_categories leer ist.
-- Für manuelles Test-Setup siehe: sql/seed_test_esx.sql

INSERT INTO `lifeinvader_categories` (`slug`, `label`, `icon`, `sort_order`, `created_by`) VALUES
('verkauf', 'Verkauf', 'tags', 1, 'system'),
('dienstleistungen', 'Dienstleistungen', 'handshake', 2, 'system'),
('jobs', 'Jobs', 'briefcase', 3, 'system'),
('events', 'Events', 'calendar-days', 4, 'system'),
('sonstiges', 'Sonstiges', 'ellipsis', 5, 'system');

INSERT INTO `lifeinvader` (`identifier`, `balance`) VALUES
('char1:fake_demo', 5000),
('char1:fake_demo2', 4200),
('char1:fake_demo3', 3800),
('char1:fake_demo4', 6100),
('char1:fake_demo5', 2900);

INSERT INTO `lifeinvader_feeds` (
    `identifier`, `author_name`, `title`, `content`, `category`, `phone`,
    `anonymous`, `premium`, `duration_hours`, `price_paid`, `status`,
    `spotlight_until`, `anonym_until`, `ticker_until`, `expires_at`
) VALUES
('char1:fake_demo', 'Bennys Motorworks', 'Suche Mechaniker für Tuning-Werkstatt!',
 "Benny's Original Motorworks sucht erfahrene Mechaniker. Gute Bezahlung und flexibles Team.",
 'jobs', '555-4089', 0, '{"spotlight":{"days":2}}', 48, 550, 'active',
 DATE_ADD(NOW(), INTERVAL 2 DAY), NULL, NULL, DATE_ADD(NOW(), INTERVAL 48 HOUR)),
('char1:fake_demo2', 'Franklin Clinton', 'Verkauf: Sultan RS Vollgetunt!',
 'Verkaufe meinen Sultan RS. Volles Tuning, Turbo verbaut. VHB $120.000.',
 'verkauf', '555-0147', 0, NULL, 24, 320, 'active',
 NULL, NULL, NULL, DATE_ADD(NOW(), INTERVAL 24 HOUR)),
('char1:fake_demo3', 'Vanilla Unicorn', 'LifeInvader Party im Vanilla Unicorn!',
 'Heute Abend ab 22:00 Uhr große Party! Freier Eintritt für Frauen, Drinks halber Preis.',
 'events', '555-9082', 0, '{"spotlight":{"days":1},"liveticker":{"days":1}}', 72, 980, 'active',
 DATE_ADD(NOW(), INTERVAL 1 DAY), NULL, DATE_ADD(NOW(), INTERVAL 1 DAY), DATE_ADD(NOW(), INTERVAL 72 HOUR)),
('char1:fake_demo4', 'Rosenberg & Partner', 'Biete Anwaltshilfe in allen Lebenslagen',
 'Vertretung vor Gericht. Melde dich bei Ken Rosenberg!',
 'dienstleistungen', '555-8831', 0, NULL, 168, 450, 'active',
 NULL, NULL, NULL, DATE_ADD(NOW(), INTERVAL 168 HOUR)),
('char1:fake_demo5', 'Lena Incognito', 'Test Feed',
 'Ein einfacher Test Feed — anonym. Nachrichten über LifeInvader möglich.',
 'sonstiges', '0815', 1, '{"anonym":{"days":1}}', 24, 280, 'active',
 NULL, DATE_ADD(NOW(), INTERVAL 24 HOUR), NULL, DATE_ADD(NOW(), INTERVAL 24 HOUR));

SET @fake_feed_lawyer := (SELECT id FROM lifeinvader_feeds WHERE identifier = 'char1:fake_demo4' ORDER BY id DESC LIMIT 1);
SET @fake_feed_anon := (SELECT id FROM lifeinvader_feeds WHERE identifier = 'char1:fake_demo5' ORDER BY id DESC LIMIT 1);

INSERT INTO `lifeinvader_conversations` (
    `feed_id`, `ad_owner_identifier`, `guest_identifier`, `guest_name`, `updated_at`
) VALUES
(@fake_feed_lawyer, 'char1:fake_demo4', 'char1:fake_demo2', 'Franklin Clinton', DATE_SUB(NOW(), INTERVAL 15 MINUTE)),
(@fake_feed_anon, 'char1:fake_demo5', 'char1:fake_demo', 'Bennys Motorworks', DATE_SUB(NOW(), INTERVAL 5 MINUTE));

SET @fake_conv_lawyer := (SELECT id FROM lifeinvader_conversations WHERE feed_id = @fake_feed_lawyer AND guest_identifier = 'char1:fake_demo2' LIMIT 1);
SET @fake_conv_anon := (SELECT id FROM lifeinvader_conversations WHERE feed_id = @fake_feed_anon AND guest_identifier = 'char1:fake_demo' LIMIT 1);

INSERT INTO `lifeinvader_messages` (`conversation_id`, `sender_identifier`, `body`, `created_at`) VALUES
(@fake_conv_lawyer, 'char1:fake_demo2', 'Hallo, ich brauche Beratung wegen eines Vertrags.', DATE_SUB(NOW(), INTERVAL 20 MINUTE)),
(@fake_conv_lawyer, 'char1:fake_demo4', 'Gerne — schildern Sie den Fall kurz.', DATE_SUB(NOW(), INTERVAL 18 MINUTE)),
(@fake_conv_lawyer, 'char1:fake_demo2', 'Es geht um einen Kaufvertrag für ein Fahrzeug.', DATE_SUB(NOW(), INTERVAL 15 MINUTE)),
(@fake_conv_anon, 'char1:fake_demo', 'Hallo, ist das Angebot noch aktiv?', DATE_SUB(NOW(), INTERVAL 8 MINUTE)),
(@fake_conv_anon, 'char1:fake_demo5', 'Ja — bitte hier weiter schreiben.', DATE_SUB(NOW(), INTERVAL 5 MINUTE));
