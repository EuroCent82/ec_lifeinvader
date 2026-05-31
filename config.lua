--[[
  ec_lifeinvader — Hauptkonfiguration

  Alle Erklärungen und Beispiele stehen direkt hier in dieser Datei.
]]

Config = {}
Config.Lang = 'de'

--------------------------------------------------------------------------------
-- 1) Adapter / Bridge
--    Zentraler Schalter: Framework, Target, Inventar, MySQL, Library.
--    Code: shared/bridge.lua · framework/
--
--    Beispiel ESX + ox_stack:
--      framework = 'esx', target = 'ox_target', inventory = 'ox_inventory'
--
--    Beispiel QBCore:
--      framework = 'qbcore', target = 'qb-target', inventory = 'qb-inventory'
--
--    Beispiel QBox:
--      framework = 'qbox', target = 'ox_target', inventory = 'ox_inventory'
--
--    Bei mysql-async zusätzlich in fxmanifest.lua VOR server_scripts:
--      '@mysql-async/lib/MySQL.lua'
--------------------------------------------------------------------------------

Config.Adapters = {
    --- esx | qbcore | qbox | standalone
    framework = 'esx',

    --- ox_target | qb-target | qtarget | native | custom
    target = 'ox_target',

    --- ox_inventory | esx | qb-inventory | qs-inventory
    inventory = 'ox_inventory',

    --- oxmysql | mysql-async
    mysql = 'oxmysql',

    --- ox_lib (Callbacks/Notify/TextUI) — Fallback ESX-Notify
    library = 'ox_lib',

    --- Eigene Hooks — siehe Block am Ende dieser Datei
    customBridge = nil,
}

--[[  Adapter-Beispiele (einen Block auskommentieren und Werte übernehmen):

-- QBCore + qb-target
Config.Adapters = {
    framework = 'qbcore',
    target = 'qb-target',
    inventory = 'qb-inventory',
    mysql = 'oxmysql',
    library = 'ox_lib',
    customBridge = nil,
}

-- QBox + ox_target
Config.Adapters = {
    framework = 'qbox',
    target = 'ox_target',
    inventory = 'ox_inventory',
    mysql = 'oxmysql',
    library = 'ox_lib',
    customBridge = nil,
}

-- Native (E-Taste) ohne Target-Script
Config.Adapters = {
    framework = 'esx',
    target = 'native',
    inventory = 'ox_inventory',
    mysql = 'oxmysql',
    library = 'ox_lib',
    customBridge = nil,
}
]]

--------------------------------------------------------------------------------
-- 2) Interaktion — wie Spieler LifeInvader öffnen
--
--    mode = 'target'  → ox_target / qb-target (je nach Config.Adapters.target)
--    mode = 'native'  → [E] in Nähe (nativePrompt: 3d oder help)
--    mode = 'item'    → nur über Config.Item (Inventar)
--
--    nativePrompt = '3d'   → Text schwebt über NPC/Objekt
--    nativePrompt = 'help' → klassische GTA-Hilfe oben links (grünes [E])
--
--    Pro Standort optional: Config.Locations[i].nativePrompt = 'help'
--
--    WICHTIG: Bei mode = 'native' gilt native für alle Standorte (außer type/item).
--    Sonst überschreibt Config.Locations[i].interaction den globalen mode.
--------------------------------------------------------------------------------

Config.Interaction = {
    mode = 'target',
    nativeKey = 38,           --- Control-ID (38 = E)
    nativeKeyLabel = 'E',     --- Anzeige in der Hilfe
    nativeDistance = 2.5,     --- Meter
    nativePrompt = '3d',      --- 3d | help
    nativeTextOffset = 0.35,  --- nur bei nativePrompt = '3d' (Meter über Kopf)
    nativeWakeDistance = 20.0, --- ab dieser Entfernung kein Wait(0) mehr (~0.00 resmon)
    nativeIdleWait = 500,     --- ms Schlaf wenn weit weg (Performance)
}

--------------------------------------------------------------------------------
-- 3) Item — LifeInvader ohne NPC/Objekt in der Welt
--
--    enabled = true  → Item registrieren (name muss im Inventar existieren)
--------------------------------------------------------------------------------

Config.Item = {
    enabled = false,
    name = 'lifeinvader_tablet',
}

--------------------------------------------------------------------------------
-- 4) Telefon — Nummer für Anzeigen (aus Inventar / Charinfo)
--
--    requirePhoneItem = true  → Spieler braucht eines der items
--    ox_inventory: Metadaten phone / number / phoneNumber
--    QBCore/QBox: Fallback PlayerData.charinfo.phone
--------------------------------------------------------------------------------

Config.Phone = {
    requirePhoneItem = true,
    items = { 'phone', 'black_phone', 'yellow_phone', 'white_phone' },
}

--------------------------------------------------------------------------------
-- 4b) Nachrichten — Ingame-Chat zu Anzeigen (kein externes Phone-System)
--------------------------------------------------------------------------------

Config.Messages = {
    enabled = true,
    maxLength = 500,
    --- Chat als gelesen markieren, nachdem der Spieler X ms in der Unterhaltung war
    markReadDelayMs = 12000,
    --- GTA-Feed-Benachrichtigung bei neuen Chat-Nachrichten (CHAR_LIFEINVADER)
    ---
    --- Rollen:
    ---   owner     = Inserent (hat die Anzeige geschaltet)
    ---   inquirer  = Interessent (hat wegen einer Anzeige geschrieben)
    ---
    --- /linotify [type] [count|titel|text]
    ---   owner_single | owner_multi | inquirer_reply | inquirer_multi | custom
    ---   (guest_* = Alias für inquirer_*)
    notifications = {
        enabled = true,
        queueIntervalMs = 3200,
        sender = 'LifeInvader',
        subject = 'Neue Nachricht',
        textureDict = 'CHAR_LIFEINVADER',
        iconType = 1,
        flash = false,
        saveToBrief = true,
        testCommand = 'linotify',
        templates = {
            --- Inserent: Interessent schreibt wegen deiner Anzeige
            owner_single = 'Neuer Interessent zu „%s“. Jemand will reden — check den Chat, bevor es wieder jemand anders tut.',
            owner_multi = '%d ungelesene Nachrichten zu deinen Anzeigen. Beliebt oder Spam? LifeInvader verrät es nicht.',
            --- Interessent: Inserent antwortet auf deine Anfrage
            inquirer_reply = 'Antwort auf „%s“. Der Inserent meldet sich — ob seriös, prüfst du selbst. Wir kennen die Leute auch nicht.',
            inquirer_multi = '%d Antworten auf deine Anfragen. Mindestens eine ist hoffentlich kein „Preis ist Preis“.',
        },
        --- Weitere Ideen zum Durchprobieren (/linotify custom … oder templates ersetzen):
        --- owner_single  = 'Ping! Interesse an „%s“. Where your personal info is public info.'
        --- owner_single  = 'Jemand will „%s“. Deine Nummer steht eh schon in der Anzeige — jetzt auch im Chat.'
        --- owner_multi   = 'Dein Postfach brodelt: %d Nachrichten von Interessenten. Sei nett. Oder nicht.'
        --- inquirer_reply = 'Gute Nachrichten: Antwort zu „%s“. Schlechte: LifeInvader haftet nicht.'
        --- inquirer_reply = 'Der Verkäufer von „%s“ hat geantwortet. Vielleicht. Schau ins Tablet.'
        --- inquirer_multi = '%d Inserenten haben reagiert. Einer davon ist vielleicht echt.'
    },
}

--------------------------------------------------------------------------------
-- 5) Berechtigungen
--
--    nil     = jeder darf
--    false   = niemand
--    Tabelle = groups, jobs, ace (mindestens eine Regel muss passen)
--
--    default = false  → verweigern wenn keine Regel greift
--    default = true   → erlauben wenn keine Regel greift
--------------------------------------------------------------------------------

Config.Permissions = {
    open = nil,
    post = nil,
    admin = {
        groups = { 'admin', 'superadmin' },
        --- jobs = { 'lifeinvader' },
        ace = 'ec_lifeinvader.admin',
        default = false,
    },
    --- Team-Panel im Tablet (Gutscheine, Kategorien, Anzeigen, Rückerstattung)
    team = {
        groups = { 'admin', 'superadmin', 'lifeinvader' },
        ace = 'ec_lifeinvader.team',
        default = false,
    },
    --- livdb check / livdb fix (Schema-Status, Reparatur)
    dbCheck = {
        groups = { 'admin', 'superadmin' },
        ace = 'ec_lifeinvader.dbcheck',
        default = false,
    },
    --- Tablet von überall öffnen (/lifeinvader) — alternativ reicht team
    teamOpen = {
        groups = { 'admin', 'superadmin', 'lifeinvader' },
        ace = 'ec_lifeinvader.teamOpen',
        default = false,
    },

    --- Team-Bereiche einzeln (nil = gleiche Regel wie team)
    --- false = für niemanden · Tabelle = wie open/post/admin (groups, jobs, ace, default)
    teamCategories = nil,
    teamVouchers = nil,
    teamTicker = nil,
    teamAds = nil,
    teamMessages = nil,   --- nil = wie teamAds
    teamRefunds = nil,
    teamBlacklist = nil,
    teamAdSlots = nil,
    teamAdDuration = nil,
}

--[[  Permissions einschränken:

Config.Permissions = {
    open = nil,
    post = {
        groups = { 'user', 'admin' },
        default = true,
    },
    admin = {
        groups = { 'admin', 'superadmin' },
        ace = 'ec_lifeinvader.admin',
        default = false,
    },
    team = {
        groups = { 'admin', 'superadmin', 'lifeinvader' },
        default = false,
    },
    --- Nur Admins: Gutscheine · LifeInvader-Job: Rest
    teamVouchers = {
        groups = { 'admin', 'superadmin' },
        default = false,
    },
    teamCategories = {
        jobs = { 'lifeinvader' },
        default = false,
    },
}
]]

--------------------------------------------------------------------------------
-- 6) Zahlung — Framework-Geld (Ein-/Auszahlung aufs LifeInvader-Konto)
--
--    preferred           → cash | bank (bevorzugte Quelle)
--    allowBoth           → beide Quellen erlauben
--    preferredWhenBoth   → bei allowBoth: zuerst cash oder bank
--
--    Anzeigen schalten kostet LifeInvader-Guthaben (Tabelle lifeinvader),
--    nicht direkt Cash/Bank — siehe Config.Deposit / Config.Withdraw.
--------------------------------------------------------------------------------

Config.Payment = {
    preferred = 'bank',
    allowBoth = true,
    preferredWhenBoth = 'bank',
}

Config.Deposit = {
    cash = true,
    bank = true,
}

Config.Withdraw = {
    cash = true,   --- Standard: Auszahlung als Bargeld
    bank = false,  --- bank = true erlaubt Auszahlung auf Bankkonto
}

--[[  Nur Bargeld:

Config.Deposit = { cash = true, bank = false }
Config.Withdraw = { cash = true, bank = false }
]]

--------------------------------------------------------------------------------
-- 7) Infrastruktur
--------------------------------------------------------------------------------

--- true = zusätzliche Client-Konsolen-Ausgaben (Spawn, Bridge, NUI) + Blip-Test-Commands
Config.Debug = false

--- Welt-Spawn: Server-Konsole (Blips/NPCs + Koordinaten) — für Live: false
Config.World = {
    debug = false,
}

--- Demo-Daten beim Start (fake_esx.sql / fake_qbcore.sql / fake_qbox.sql)
--- Nur wenn lifeinvader_categories noch leer ist. Dev/Test: true, Live: false
Config.fake = false

--- Versionsvergleich mit GitHub-Releases (öffentliches Repo ec_lifeinvader)
Config.VersionCheck = {
    enabled = true,
    repository = 'EuroCent82/ec_lifeinvader',
    delayMs = 1500,
    printWhenUpToDate = true,
    logErrors = true,
}

--------------------------------------------------------------------------------
-- 8) Blips — Sprite 77 = rotes „L“ (LifeInvader-Style, GTA-Blip-Referenz)
--
--    Pro Standort ein Blip. Gleiches sprite+label → GTA kann gruppieren (< 1/2 >).
--    blipLabel pro Standort bricht Gruppierung (optional).
--
--    sprite / color / scale → https://docs.fivem.net/docs/game-references/blips/
--    nameMode: auf Build b3407 kein Custom-Name (Crash) → Legende zeigt Sprite-Text
--------------------------------------------------------------------------------

Config.Blip = {
    enabled = true,
    sprite = 77,
    color = 1,
    scale = 0.85,
    --- 3 = nur große Karte (fern); Thread schaltet auf 2 (Minimap) in minimapDistance
    display = 3,
    --- Meter: Blip erscheint auf der Minimap nur in dieser Nähe (große Karte immer)
    minimapDistance = 200,
    shortRange = false,
    label = 'LifeInvader',
    --- auto | native | none
    --- auto: deaktiviert Blip-Namen auf problematischen Builds (siehe disableNameForBuilds)
    nameMode = 'auto',
    --- map (oder Liste) mit Game-Builds, auf denen EndTextCommandSetBlipName übersprungen wird
    disableNameForBuilds = { [3407] = true },
}

--------------------------------------------------------------------------------
-- 9) Standorte — NPCs, Objekte, Item-only
--
--    type         → npc | object | item
--    interaction  → target | native | item (optional, sonst Config.Interaction.mode)
--    enabled      → false = Standort ignorieren
--    coords       → vector4(x, y, z, heading)
--    scenario     → optional, nur NPC (z. B. WORLD_HUMAN_STAND_MOBILE)
--    spawnZOffset → optional Z-Korrektur (Standard -1.0; in MLO oft 0.0)
--    interactDistance → Target-/Native-Reichweite
--    nativePrompt   → optional: 3d | help (nur bei interaction = native)
--    blipLabel    → optional: eigener Kartenname (sonst Config.Blip.label)
--    blip = false → optional: kein Blip an diesem Standort
--
--    type = 'item'  → kein Welt-Spawn, UI über Config.Item
--------------------------------------------------------------------------------

Config.Locations = {
    {
        id = 'lifeinvader_vespucci',
        label = 'LifeInvader Vespucci',
        enabled = true,
        type = 'npc',
        --- LifeInvader-Mitarbeiter (Story/Online, Rockford-Hills-Büro)
        model = 's_m_m_lifeinvad_01',
        coords = vector4(-1084.8989, -256.6928, 37.7633, 209.2137),
        scenario = 'WORLD_HUMAN_STAND_MOBILE',
        interactDistance = 2.5,
        interaction = 'target',
    },
    {
        id = 'lifeinvader_pillbox',
        label = 'LifeInvader Pillbox',
        enabled = true,
        type = 'npc',
        model = 's_m_m_lifeinvad_01',
        coords = vector4(298.62, -584.41, 43.26, 70.0),
        spawnZOffset = 0.0,
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        interactDistance = 2.5,
        interaction = 'target',
    },
}

--[[  Standort-Beispiele:

-- Zweiter Standort (gleicher Kartenname „LifeInvader“, eigener Blip-Punkt)
{
    id = 'lifeinvader_terminal',
    label = 'LifeInvader Terminal',
    enabled = true,
    type = 'object',
    model = 'prop_laptop_01a',
    coords = vector4(298.62, -584.41, 43.26, 70.0),
    interactDistance = 2.0,
    interaction = 'native',
},

-- Eigener Name auf der Karte (selten nötig)
-- blipLabel = 'LifeInvader Pillbox',

-- Kein Blip an diesem Standort
-- blip = false,

-- Nur Item (kein NPC) — zusätzlich Config.Item.enabled = true
{
    id = 'lifeinvader_item_only',
    label = 'LifeInvader Tablet',
    enabled = true,
    type = 'item',
    interaction = 'item',
},
]]

--------------------------------------------------------------------------------
-- 10) Öffnungszeiten — GEPLANT (noch nicht im Code implementiert)
--
--     Wenn umgesetzt: nil = 24/7, sonst from/to (z. B. '08:00' / '20:00')
--------------------------------------------------------------------------------

Config.OpenHours = nil

--[[  Beispiel für spätere Implementierung:

Config.OpenHours = {
    from = '08:00',
    to = '20:00',
}
]]

--------------------------------------------------------------------------------
-- 10b) Live-Ticker — Lauftext unter der Kopfzeile
--
--     enabled = false       → Ticker komplett aus
--     maxActiveSlots = 5    → max. gleichzeitig laufende Live-Ticker-Anzeigen
--     Einträge = Premium Live-Ticker: +++ Anzeigen-Titel +++ (neueste zuerst)
--     Team-Panel: alle Einträge, aktiv/inaktiv, Reihenfolge — leer = kein Banner
--------------------------------------------------------------------------------

Config.Ticker = {
    enabled = true,
    maxActiveSlots = 5,
}

--------------------------------------------------------------------------------
-- 10a) Öffentlicher Feed — Limit beim Tablet-Öffnen (Performance)
--
--     maxPublicAds = 100   → neueste aktive Anzeigen (Spotlight zuerst)
--------------------------------------------------------------------------------

Config.Feed = {
    maxPublicAds = 100,
}

--------------------------------------------------------------------------------
-- 10c) Feed-Benachrichtigungen (Queue/Pipeline, um Overlap zu vermeiden)
--
--    Wenn neue Anzeigen geschaltet werden, zeigt der Client kurze Hinweise.
--    Diese laufen durch eine Queue, damit sich keine Popups überlagern.
--------------------------------------------------------------------------------

Config.FeedNotifications = {
    enabled = true,
    queueIntervalMs = 3200,
    title = 'LifeInvader',
    subtitle = 'Neue Anzeige online',
    templates = {
        'Neue Anzeige von %s: "%s" — check LifeInvader!',
        'Frischer Post auf LifeInvader: %s',
        '%s hat gerade etwas Neues gepostet.',
        'LifeInvader pingt dich: "%s" ist jetzt live.',
    },
}

--------------------------------------------------------------------------------
-- 11) Kategorien — aus der Datenbank (lifeinvader_categories), nicht aus Config
--
--     Anlegen/Bearbeiten: Team-Panel im Tablet (Icon-Auswahl aus CategoryIcons)
--     Erst-Installation / Demo: sql/fake_*.sql (wenn Config.fake = true)
--
--     id    → Font Awesome 6 (free-solid), z. B. "car", "mobile-screen"
--     label → Anzeige im Team-Panel (frei wählbar)
--------------------------------------------------------------------------------

Config.CategoryIcons = {
    { id = 'tags', label = 'Verkauf' },
    { id = 'handshake', label = 'Dienstleistung' },
    { id = 'briefcase', label = 'Jobs' },
    { id = 'calendar-days', label = 'Events' },
    { id = 'ellipsis', label = 'Sonstiges' },
    { id = 'star', label = 'Premium' },
    { id = 'bolt', label = 'Aktion' },
    -- Fahrzeuge
    { id = 'car', label = 'PKW' },
    { id = 'truck', label = 'LKW' },
    { id = 'motorcycle', label = 'Motorrad' },
    { id = 'bus', label = 'Bus' },
    { id = 'taxi', label = 'Taxi' },
    { id = 'bicycle', label = 'Fahrrad' },
    { id = 'ship', label = 'Boot' },
    { id = 'anchor', label = 'Anker / Hafen' },
    { id = 'helicopter', label = 'Helikopter' },
    { id = 'plane', label = 'Flugzeug' },
    { id = 'gas-pump', label = 'Tankstelle' },
    -- Elektronik & Kommunikation
    { id = 'microchip', label = 'Elektronik' },
    { id = 'mobile-screen', label = 'Handy' },
    { id = 'tablet-screen-button', label = 'Tablet' },
    { id = 'laptop', label = 'Laptop' },
    { id = 'desktop', label = 'Computer (PC)' },
    { id = 'keyboard', label = 'Tastatur' },
    { id = 'headphones', label = 'Audio' },
    { id = 'camera', label = 'Kamera' },
    { id = 'video', label = 'Video' },
    { id = 'envelope', label = 'Mail' },
    { id = 'paper-plane', label = 'Senden' },
    { id = 'trash-can', label = 'Mülleimer' },
    -- Freizeit & RP
    { id = 'gamepad', label = 'Controller / Gaming' },
    { id = 'puzzle-piece', label = 'Spielzeug' },
    { id = 'masks-theater', label = 'RP / Theater' },
    { id = 'users', label = 'Gruppe / Team' },
    { id = 'user-tie', label = 'Business' },
    -- Handwerk & Sicherheit
    { id = 'wrench', label = 'Werkzeug' },
    { id = 'hammer', label = 'Hammer / Bau' },
    { id = 'screwdriver-wrench', label = 'Mechanik' },
    { id = 'toolbox', label = 'Toolbox' },
    { id = 'gun', label = 'Waffen' },
    { id = 'shield-halved', label = 'Sicherheit' },
    { id = 'user-shield', label = 'Schutz / VIP' },
    -- Immobilien & Handel
    { id = 'building', label = 'Immobilien' },
    { id = 'house', label = 'Haus' },
    { id = 'store', label = 'Laden' },
    { id = 'cart-shopping', label = 'Shop' },
    { id = 'gem', label = 'Luxus' },
    { id = 'shirt', label = 'Kleidung' },
    { id = 'sack-dollar', label = 'Finanzen' },
    { id = 'wallet', label = 'Geld / Wallet' },
    -- Gastronomie & Lifestyle
    { id = 'utensils', label = 'Gastronomie' },
    { id = 'beer-mug-empty', label = 'Bar / Club' },
    { id = 'wine-glass', label = 'Wein / Bar' },
    { id = 'tree', label = 'Natur / Outdoor' },
    { id = 'paw', label = 'Tiere' },
    { id = 'heart', label = 'Gesundheit / Social' },
    { id = 'hospital', label = 'Medizin' },
    { id = 'stethoscope', label = 'Arzt' },
    { id = 'graduation-cap', label = 'Bildung' },
    { id = 'key', label = 'Schlüssel / Zugang' },
    { id = 'lock', label = 'Sicher / Privat' },
    { id = 'map-location-dot', label = 'Standort' },
    { id = 'newspaper', label = 'News / Medien' },
    { id = 'rectangle-ad', label = 'Werbung' },
}

--------------------------------------------------------------------------------
-- 12) Anzeigen schalten — Laufzeit, Text, Limits
--
--     hours     → interne Laufzeit in Stunden (24, 48, 72, 168)
--     baseCost  → Grundpreis für die gewählte Anzeigen-Laufzeit
--
--     Premium (Spotlight / Anonym) wird ZUSÄTZLICH berechnet:
--       Kosten = costPerDay × gewählte Premium-Tage
--       Max. Premium-Tage hängen von der Anzeigen-Laufzeit ab (siehe §13)
--
--     Bezahlung vom LifeInvader-Konto (nicht direkt Cash/Bank)
--------------------------------------------------------------------------------

Config.Durations = {
    { id = '24h', label = '24 Stunden', hours = 24,  baseCost = 200 },
    { id = '48h', label = '48 Stunden', hours = 48,  baseCost = 350 },
    { id = '3d',  label = '3 Tage',     hours = 72,  baseCost = 600 },
    { id = '7d',  label = '7 Tage',     hours = 168, baseCost = 1200 },
}

Config.CharCost = 2
Config.MaxTitleLength = 40
Config.MaxContentLength = 500

--------------------------------------------------------------------------------
-- 13) Premium-Zusatzoptionen
--
--     pricing = 'per_day'  → Preis = costPerDay × gewählte Premium-Tage
--
--     spotlight:
--       Spieler wählt 1 … N Tage Spotlight (N = Anzeigen-Laufzeit in Tagen)
--       Beispiel: Anzeige 7 Tage → Spotlight 1–7 Tage wählbar
--       Beispiel: Anzeige 24h   → Spotlight nur 1 Tag
--
--     anonym:
--       Max. 48 Stunden (2 Tage), nie länger als die Anzeige selbst
--       Beispiel: Anzeige 24h → Anonym max 1 Tag
--       Beispiel: Anzeige 7 Tage → Anonym max 2 Tage (48h-Cap)
--
--     Gespeichert in DB (premium JSON), z. B.:
--       { "spotlight": { "days": 3 }, "anonym": { "days": 1 } }
--------------------------------------------------------------------------------

Config.PremiumFeatures = {
    spotlight = {
        label = 'Premium Spotlight',
        costPerDay = 350,
        pricing = 'per_day',
        minDays = 1,
        desc = 'Deine Anzeige wird hervorgehoben. Dauer wählbar bis zur Laufzeit der Anzeige.',
    },
    anonym = {
        label = 'Anonym posten',
        costPerDay = 150,
        pricing = 'per_ad',
        desc = 'Dein Name wird für die gesamte Laufzeit der Anzeige nicht im Feed angezeigt.',
    },
    liveticker = {
        label = 'Live-Ticker',
        costPerDay = 200,
        pricing = 'per_day',
        minDays = 1,
        desc = 'Deine Anzeige erscheint im Live-Ticker. Dauer wählbar bis zur Laufzeit der Anzeige.',
    },
}

--[[  Preis-Beispiel (Server/UI):
  Anzeige 7 Tage (168h) + Spotlight 3 Tage + Anonym 1 Tag:
    baseCost(7d) + (Zeichen × CharCost) + (350 × 3) + (150 × 1)
]]

--------------------------------------------------------------------------------
-- 13b) Anzeigen-Slots — max. gleichzeitig aktive Anzeigen pro Spieler
--
--     defaultMax     → Standard ohne Team-Bonus (z. B. 2)
--     minimum        → Untergrenze des effektiven Limits (auch mit Bonus)
--     maximum        → Obergrenze des effektiven Limits (auch mit Team-Bonus, z. B. 8)
--     teamCanAdjust  → Team darf pro Spieler Bonus-Slots vergeben (+1 / +8)
--     teamGrantOptions → erlaubte Vergabe-Stufen (nur diese Werte)
--------------------------------------------------------------------------------

Config.AdSlots = {
    defaultMax = 2,
    minimum = 1,
    maximum = 8,
    teamCanAdjust = true,
    teamGrantOptions = { 1, 8 },
    teamRemoveOptions = { 1, 8 },
}

--------------------------------------------------------------------------------
-- 13c) Anzeigen-Laufzeit — max. buchbare Tage pro Anzeige
--
--     defaultMaxDays  → Standard ohne Team-Bonus (z. B. 7)
--     teamGrantOptions → z. B. +7 Tage Bonus (nur dieser Spieler, max. 30 gesamt)
--------------------------------------------------------------------------------

Config.AdDuration = {
    defaultMaxDays = 7,
    minimum = 1,
    maximum = 30,
    teamCanAdjust = true,
    teamGrantOptions = { 1, 7 },
    teamRemoveOptions = { 1, 7 },
}

--------------------------------------------------------------------------------
-- 14) Team-Panel (Admin) — Config.Permissions.team + ggf. teamCategories, teamVouchers, …
--
--     Berechtigte sehen im Tablet einen extra Tab „Team“ / Admin-Panel.
--     Config.Admin.features = Bereich serverweit an/aus (Modul).
--     Config.Permissions.team* = wer welchen Bereich nutzen darf (nil = wie team).
--------------------------------------------------------------------------------

Config.Admin = {
    enabled = true,
    tabLabel = 'Team',

    features = {
        categories = true,
        vouchers = true,
        ticker = true,
        ads = true,
        messages = true,
        refunds = true,
        blacklist = true,
        adSlots = true,
        adDuration = true,
    },
}

--------------------------------------------------------------------------------
-- 14b) Team: Tablet von überall — Befehl (Config.Permissions.teamOpen / team)
--------------------------------------------------------------------------------

Config.TeamRemoteOpen = {
    enabled = true,
    command = 'lifeinvader',
}

--------------------------------------------------------------------------------
-- 14c) Blacklist — Spieler von Open/Post ausschließen (Team-Tab)
--------------------------------------------------------------------------------

Config.Blacklist = {
    enabled = true,
    maxDays = 30,
    --- Team mit Config.Permissions.team darf trotz Sperre das Tablet öffnen (Moderation)
    teamBypass = true,
}

--------------------------------------------------------------------------------
-- 14d) Rückerstattungen — Team erstattet auf lifeinvader.balance
--------------------------------------------------------------------------------

Config.Refunds = {
    enabled = true,
    --- Benachrichtigung an den erstatteten Spieler (GTA-Feed wie Nachrichten)
    notifications = {
        enabled = true,
        sender = 'LifeInvader',
        subject = 'Rückerstattung',
        template = '+%s $ auf dein LifeInvader-Konto. Grund: %s',
    },
}

--------------------------------------------------------------------------------
-- 15) Gutscheine — vom Team erstellt, Spieler lösen ein (LifeInvader-Guthaben)
--
--     Code-Format: LIV-1234-5678 (automatisch generiert)
--     prefix      → immer „LIV“
--     segments    → Anzahl Zifferngruppen à 4 Ziffern
--
--     Beim Erstellen (Team-Panel) wählbar:
--       value       → Guthaben-Betrag $X
--       expiresAt   → gültig bis Datum (nil = permanent)
--       maxUses     → Stückzahl / Einlösungen (nil = unbegrenzt)
--
--     Einlösung: Code eingeben → Betrag auf lifeinvader.balance
--     DB: sql/install_esx.sql | install_qbcore.sql | install_qbox.sql
--------------------------------------------------------------------------------

Config.Vouchers = {
    enabled = true,
    prefix = 'LIV',
    segmentDigits = 4,
    segmentCount = 2,

    --- Platzhalter-Anzeige im UI
    codeExample = 'LIV-1234-5678',

    --- Standard beim Erstellen (Team kann überschreiben)
    defaults = {
        value = 500,
        expiresAt = nil,
        maxUses = 1,
    },
}

--[[  Gutschein-Beispiele (Team erstellt in UI, Server speichert):

-- 500$ · einmalig · permanent
{ value = 500, expiresAt = nil, maxUses = 1 }

-- 1000$ · max. 50 Einlösungen · bis 31.12.2026
{ value = 1000, expiresAt = '2026-12-31 23:59:59', maxUses = 50 }

-- 250$ · unbegrenzt · 30 Tage gültig
{ value = 250, expiresAt = '2026-06-30 23:59:59', maxUses = nil }
]]

--------------------------------------------------------------------------------
-- 16) Datenbank — automatischer SQL-Import beim Resource-Start
--
--     Beim Start prüft das Script jede Tabelle einzeln in information_schema.
--     Fehlt mindestens eine → passendes install_*.sql ausführen (CREATE IF NOT EXISTS).
--     Sind alle 8 Tabellen da → nichts tun.
--
--       esx     → sql/install_esx.sql
--       qbcore  → sql/install_qbcore.sql
--       qbox    → sql/install_qbox.sql
--
--     Tabellen: lifeinvader, lifeinvader_feeds, lifeinvader_categories, lifeinvader_ticker,
--               lifeinvader_vouchers, lifeinvader_voucher_redemptions, lifeinvader_refunds,
--               lifeinvader_blacklist
--
--     autoInstall     → true: fehlende Tabellen automatisch anlegen
--     skipIfInstalled → legacy (true): nur anlegen wenn Tabellen fehlen (Standard)
--     installFile     → nil = automatisch aus Framework (empfohlen)
--
--     Config.fake = true  → Demo-Kategorien & Beispiel-Anzeigen (fake_*.sql)
--
--     Live-Ticker: Premium-Anzeigen (ticker_until, ticker_enabled, ticker_sort_order)
--
--     Admin/txAdmin: livdb check (Status) | livdb fix (Tabellen + Spalten-Patches)
--     Berechtigung: Config.Permissions.dbCheck (Gruppe admin/superadmin oder ACE)
--------------------------------------------------------------------------------

Config.Database = {
    autoInstall = true,
    skipIfInstalled = true,
    installFile = nil,
    ownerColumn = 'identifier',
    --- Konsolen-/Admin-Befehl: livdb check | livdb fix
    checkCommand = 'livdb',
    --- true = nur Server-Konsole (txAdmin), kein /livdb im Spiel
    checkConsoleOnly = false,
}

--[[  Custom Bridge — für exotische Setups:

Config.Adapters = {
    framework = 'standalone',
    target = 'custom',
    inventory = 'custom',
    mysql = 'oxmysql',
    library = 'ox_lib',
    customBridge = {
        ClientRegisterTargetEntity = function(entity, location, label, onSelect)
            return true
        end,
        ClientRemoveTargetEntity = function(entity) end,
        RegisterServerCallback = function(name, handler)
            return false
        end,
    },
}
]]

--------------------------------------------------------------------------------
-- Legacy-Aliase (Kompatibilität — nicht manuell ändern)
--------------------------------------------------------------------------------

Config.Framework = Config.Adapters.framework
Config.Target = Config.Adapters.target
Config.Inventory = Config.Adapters.inventory
Config.MySQL = Config.Adapters.mysql
Config.Library = Config.Adapters.library
Config.Custom = Config.Adapters.customBridge
