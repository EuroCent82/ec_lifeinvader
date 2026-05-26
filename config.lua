--[[
  ec_lifeinvader — Hauptkonfiguration

  Ausführliche Erklärungen: siehe readme_config.md
]]

Config = {}

--------------------------------------------------------------------------------
-- Infrastruktur
--------------------------------------------------------------------------------

Config.Debug = false

Config.VersionCheck = {
    enabled = true,
    repository = 'EuroCent82/ec_lifeinvader',
    delayMs = 1500,
    printWhenUpToDate = true,
    logErrors = true,
}

--- MySQL: `"oxmysql"` (Standard) oder `"mysql-async"`.
Config.MySQL = 'oxmysql'

--------------------------------------------------------------------------------
-- Öffnungszeiten (LifeInvader nutzbar)
-- `nil` für from/to = immer offen · gesamtes Config.OpenHours = nil → 24/7
--------------------------------------------------------------------------------

Config.OpenHours = {
    from = '08:00',
    to = '20:00',
}
-- Config.OpenHours = nil

--------------------------------------------------------------------------------
-- Kategorien (Feed-Filter + Formular)
--------------------------------------------------------------------------------

Config.Categories = {
    { id = 'verkauf',          label = 'Verkauf',          icon = 'tags' },
    { id = 'dienstleistungen', label = 'Dienstleistungen', icon = 'handshake' },
    { id = 'jobs',             label = 'Jobs',             icon = 'briefcase' },
    { id = 'events',           label = 'Events',           icon = 'calendar-days' },
    { id = 'sonstiges',        label = 'Sonstiges',        icon = 'ellipsis' },
}

--------------------------------------------------------------------------------
-- Laufzeiten beim Anzeige schalten (Tage → Grundpreis)
--------------------------------------------------------------------------------

Config.Durations = {
    { days = 7,  baseCost = 500 },
    { days = 14, baseCost = 900 },
    { days = 30, baseCost = 1500 },
}

--- Zusätzliche Kosten pro Zeichen im Anzeigentext.
Config.CharCost = 2

--- Maximale Zeichenlänge Titel / Inhalt.
Config.MaxTitleLength = 40
Config.MaxContentLength = 500

--------------------------------------------------------------------------------
-- LifeInvader-Konto — Ein- & Auszahlung
--------------------------------------------------------------------------------

Config.Deposit = {
    cash = true,
    bank = true,
}

Config.Withdraw = {
    cash = true,
    bank = false,
}

--------------------------------------------------------------------------------
-- Premium-Zusatzoptionen beim Schalten
-- Key = interner Name · wird in DB gespeichert und im Feed ausgewertet
--------------------------------------------------------------------------------

Config.PremiumFeatures = {
    spotlight = {
        label = 'Premium Spotlight',
        cost = 350,
        desc = 'Deine Anzeige wird auffällig animiert und im Spotlight hervorgehoben.',
    },
    anonym = {
        label = 'Anonym posten',
        cost = 150,
        desc = 'Dein Name wird nicht im Feed angezeigt.',
    },
}
