-- ec_lifeinvader — ESX Demo-Daten (Config.fake = true)
-- Wird nur geladen wenn lifeinvader_categories leer ist.

INSERT INTO `lifeinvader_categories` (`slug`, `label`, `icon`, `sort_order`, `created_by`) VALUES
('verkauf', 'Verkauf', 'tags', 1, 'system'),
('dienstleistungen', 'Dienstleistungen', 'handshake', 2, 'system'),
('jobs', 'Jobs', 'briefcase', 3, 'system'),
('events', 'Events', 'calendar-days', 4, 'system'),
('sonstiges', 'Sonstiges', 'ellipsis', 5, 'system');

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
('char1:fake_demo5', 'Anonym', 'Verlorener Ehering gesucht',
 'Finderlohn $5.000! Bitte per SMS melden.',
 'sonstiges', '555-7281', 1, NULL, 24, 280, 'active',
 NULL, DATE_ADD(NOW(), INTERVAL 24 HOUR), NULL, DATE_ADD(NOW(), INTERVAL 24 HOUR));
