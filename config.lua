--[[
  ec_lifeinvader — Hauptkonfiguration

  Alle Erklärungen und Beispiele stehen direkt hier in dieser Datei.
]]

Config = {}

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
--    mode = 'native'  → [E] in Nähe (nativeKey / nativeDistance)
--    mode = 'item'    → nur über Config.Item (Inventar)
--
--    WICHTIG: Config.Locations[i].interaction überschreibt mode pro Standort!
--------------------------------------------------------------------------------

Config.Interaction = {
    mode = 'native',
    nativeKey = 38,           --- Control-ID (38 = E)
    nativeKeyLabel = 'E',     --- Anzeige in der Hilfe
    nativeDistance = 2.5,     --- Meter
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
-- 4b) Telefon-Aktionen aus dem Feed (Anrufen / Nachricht)
--
-- provider (ESX Legacy — freie Alternativen zu NPWD):
--   none         -> Buttons zeigen Hinweis, keine Phone-Integration
--   gcphone      -> Re-Ignited-Phone / gcPhone (klassisch, ESX Legacy)
--   z-phone      -> Z-Phone (modern, Open Source, braucht ox_lib)
--   lsfive-phone -> LSFive Phone (Auto-ESX, Server-Export für SMS)
--   roadphone    -> RoadPhone (Paid, ESX Legacy)
--   lb-phone     -> LB Phone (Paid, Server-Export)
--   custom       -> eigene Client-Events
--
-- Empfehlung ESX Legacy (kostenlos):
--   1. gcphone  → https://github.com/Re-Ignited-Development/Re-Ignited-Phone
--   2. z-phone  → https://github.com/alfaben12/z-phone
--   3. lsfive-phone → https://github.com/Krigsexe/lsfive-phone
--------------------------------------------------------------------------------

Config.PhoneActions = {
    ---@type 'none'|'gcphone'|'z-phone'|'lsfive-phone'|'roadphone'|'lb-phone'|'custom'
    provider = 'none',

    defaultMessageTemplate = 'Hallo %s, ich schreibe dir wegen deiner Anzeige auf LifeInvader.',

    providers = {
        custom = {
            resource = nil,
            smsClientEvent = nil,
            callClientEvent = nil,
        },
        gcphone = {
            resource = 'gcphone',
        },
        ['z-phone'] = {
            resource = 'z-phone',
        },
        ['lsfive-phone'] = {
            resource = 'lsfive-phone',
        },
        roadphone = {
            resource = 'roadphone',
        },
        ['lb-phone'] = {
            resource = 'lb-phone',
        },
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

--- true = zusätzliche Konsolen-Ausgaben (Spawn, Bridge, NUI)
Config.Debug = false

--- Demo-Daten beim Start (fake_esx.sql / fake_qbcore.sql / fake_qbox.sql)
--- Nur wenn lifeinvader_categories noch leer ist.
Config.fake = true

--- Versionsvergleich mit GitHub-Releases (öffentliches Repo ec_lifeinvader)
Config.VersionCheck = {
    enabled = true,
    repository = 'EuroCent82/ec_lifeinvader',
    delayMs = 1500,
    printWhenUpToDate = true,
    logErrors = true,
}

--------------------------------------------------------------------------------
-- 8) Blips — eine Markierung pro Standort (gruppiert auf der Karte)
--
--    enabled = true     → jeder aktive Standort mit coords bekommt einen Blip
--    label             → Standard-Name für ALLE Standorte („gruppiert“ in der Legende)
--    category          → gleiche Kategorie = GTA fasst Blips zusammen (optional)
--
--    Pro Standort nur noch optional:
--      blipLabel = 'LifeInvader Vespucci'  → eigener Name (sonst Config.Blip.label)
--      blip = false                       → keinen Blip an diesem Standort
--------------------------------------------------------------------------------

Config.Blip = {
    enabled = true,
    debug = false,
    sprite = 77,
    color = 1,
    scale = 0.85,
    shortRange = false,
    label = 'LifeInvader',
    category = 12,
}

--------------------------------------------------------------------------------
-- 9) Standorte — NPCs, Objekte, Item-only
--
--    type         → npc | object | item
--    interaction  → target | native | item (optional, sonst Config.Interaction.mode)
--    enabled      → false = Standort ignorieren
--    coords       → vector4(x, y, z, heading)
--    scenario     → optional, nur NPC (z. B. WORLD_HUMAN_STAND_MOBILE)
--    interactDistance → Target-/Native-Reichweite
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
        model = 'cs_barry',
        coords = vector4(-1084.8989, -256.6928, 37.7633, 209.2137),
        scenario = 'WORLD_HUMAN_STAND_MOBILE',
        interactDistance = 2.5,
        interaction = 'target',
        --- blipLabel = 'LifeInvader Vespucci',  --- nur wenn abweichend von Config.Blip.label
    },
    {
        id = 'lifeinvader_pillbox',
        label = 'LifeInvader Pillbox',
        enabled = false,
        type = 'object',
        model = 'prop_laptop_01a',
        coords = vector4(298.62, -584.41, 43.26, 70.0),
        interactDistance = 2.0,
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
-- 10) Öffnungszeiten — wann LifeInvader nutzbar ist
--
--     Config.OpenHours = nil  → 24/7
--     from / to einzeln nil   → keine Grenze auf dieser Seite
--------------------------------------------------------------------------------

Config.OpenHours = {
    from = '08:00',
    to = '20:00',
}

--- Config.OpenHours = nil

--------------------------------------------------------------------------------
-- 10b) Live-Ticker — Lauftext unter der Kopfzeile
--
--     enabled = false  → Ticker ausblenden
--     items           → statische Nachrichten (derzeit aus Config)
--
--     Geplant: automatische Einträge aus Spotlight-Anzeigen / Server-Events
--     (Server sendet beim Öffnen payload.ticker an die NUI)
--------------------------------------------------------------------------------

Config.Ticker = {
    enabled = true,
    items = {
        '+++ BRANDNEU: LifeInvader bietet jetzt Premium Spotlight-Anzeigen für alle Bürger an! +++',
        "+++ Benny's Motorworks sucht Verstärzung! Bewerbungen im Jobs-Tab einreichen +++",
        '+++ Wetteraussichten: Sonnig in Los Santos mit leichter Brise am Vespucci Beach +++',
        '+++ LS Customs meldet Rekordumsätze bei Tuningteilen +++',
    },
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
-- 11) Kategorien — Feed-Filter & Formular (beliebig erweiterbar)
--
--     id    → interner Key (DB, Filter)
--     label → Anzeige in der UI
--     icon  → FontAwesome-Name (ohne fa-)
--------------------------------------------------------------------------------

Config.Categories = {
    { id = 'verkauf',          label = 'Verkauf',          icon = 'tags' },
    { id = 'dienstleistungen', label = 'Dienstleistungen', icon = 'handshake' },
    { id = 'jobs',             label = 'Jobs',             icon = 'briefcase' },
    { id = 'events',           label = 'Events',           icon = 'calendar-days' },
    { id = 'sonstiges',        label = 'Sonstiges',        icon = 'ellipsis' },
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
        pricing = 'per_day',
        minDays = 1,
        maxHours = 48,
        desc = 'Dein Name wird nicht im Feed angezeigt. Maximal 48 Stunden.',
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
-- 14) Team-Panel (Admin) — nur mit Config.Permissions.team
--
--     Berechtigte sehen im Tablet einen extra Tab „Team“ / Admin-Panel:
--       • Kategorien anlegen / bearbeiten / deaktivieren
--       • Gutscheine erstellen & verwalten
--       • Anzeigen einsehen, bearbeiten, sperren, löschen
--       • Rückerstattung auf LifeInvader-Konto
--------------------------------------------------------------------------------

Config.Admin = {
    enabled = true,
    tabLabel = 'Team',

    features = {
        categories = true,
        vouchers = true,
        ads = true,
        refunds = true,
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
--     Sind alle 6 Tabellen da → nichts tun.
--
--       esx     → sql/install_esx.sql
--       qbcore  → sql/install_qbcore.sql
--       qbox    → sql/install_qbox.sql
--
--     Tabellen: lifeinvader, lifeinvader_feeds, lifeinvader_categories,
--               lifeinvader_vouchers, lifeinvader_voucher_redemptions, lifeinvader_refunds
--
--     autoInstall     → true: fehlende Tabellen automatisch anlegen
--     skipIfInstalled → legacy (true): nur anlegen wenn Tabellen fehlen (Standard)
--     installFile     → nil = automatisch aus Framework (empfohlen)
--
--     Config.fake = true  → Demo-Kategorien & Beispiel-Anzeigen (fake_*.sql)
--
--     Live-Ticker aus Anzeigen: Spalte ticker_until in lifeinvader_feeds
--     (keine extra Tabelle nötig — Premium-Option setzt ticker_until)
--------------------------------------------------------------------------------

Config.Database = {
    autoInstall = true,
    skipIfInstalled = true,
    installFile = nil,
    ownerColumn = 'identifier',
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
