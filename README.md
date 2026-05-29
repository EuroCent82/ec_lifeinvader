<h1 align="center">EC LifeInvader</h1>

<p align="center">
  <strong>LifeInvader Werbesystem für FiveM</strong> — Anzeigen schalten, Feed, Guthaben, Buchungshistorie.
</p>

<p align="center">
  <a href="https://github.com/EuroCent82/ec_lifeinvader/releases"><img src="https://img.shields.io/badge/Version-1.1.32-ff3b30?style=for-the-badge" alt="Version 1.1.32" /></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT License" /></a>
</p>

<p align="center">
  <img src="./docs/screenshots/01-feed.png" alt="LifeInvader Anzeigenfeed" width="720" />
</p>

---

## Überblick

**EC LifeInvader** bringt ein vollwertiges In-Game-Werbesystem im Stil von GTA Online LifeInvader auf deinen Server: Tablet-NUI, Kategorien, Premium-Optionen und ein separates LifeInvader-Guthaben.

| Feature | Beschreibung |
| --- | --- |
| **Anzeigenfeed** | Live-Anzeigen mit Kategorien, Suche, Spotlight und Detail-Popup |
| **Anzeige schalten** | Laufzeit, Zeichenpreis, Premium (Spotlight, Anonym, Live-Ticker) |
| **Buchungshistorie** | Jede Anzeige mit **LIV-ID**, Status, Laufzeit — inkl. **Erneuern** abgelaufener Ads |
| **LifeInvader-Konto** | Einzahlen vom Bar-/Bankkonto, Abbuchung beim Schalten |
| **Meine Anzeigen** | Eigene aktive Inserate verwalten und löschen |
| **Telefon-Bridge** | SMS/Anruf per Icon (gcphone, z-phone, lsfive-phone, roadphone, lb-phone) |

Resource-Name: **`ec_lifeinvader`**

---

## Screenshots

| Feed | Anzeige schalten |
| --- | --- |
| ![Feed](./docs/screenshots/01-feed.png) | ![Create](./docs/screenshots/02-create.png) |

| Buchungshistorie | Detail-Popup |
| --- | --- |
| ![History](./docs/screenshots/03-history.png) | ![Detail](./docs/screenshots/04-detail.png) |

---

## Installation

1. **[Release](https://github.com/EuroCent82/ec_lifeinvader/releases)** laden (`ec_lifeinvader.zip`)
2. Entpacken nach `resources/ec_lifeinvader/`
3. `config.lua` anpassen (Framework, Standorte, Telefon-Provider)
4. `ensure ec_lifeinvader` in `server.cfg`

Tabellen werden beim ersten Start automatisch angelegt (`Config.Database.autoInstall = true`).

Manueller SQL-Import: `sql/install_esx.sql` / `install_qbcore.sql` / `install_qbox.sql`

---

## Framework & Abhängigkeiten

- **ESX Legacy**, **QBCore** oder **Qbox**
- **oxmysql** oder **mysql-async**
- Optional: **ox_target** / **qb-target**, Phone-Resource (siehe `readme_config.md`)

---

## Konfiguration

Alle Optionen sind in **`config.lua`** und **`readme_config.md`** dokumentiert (Standorte, Preise, Permissions, Fake-Demo-Daten, Blips).

---

## WICHTIG: Karten-Blip & FiveM Game Build

> **Unbedingt lesen**, bevor du Blip-Sprite oder Legenden-Namen als Bug meldest.

LifeInvader nutzt **Sprite 77** (rotes **„L“** auf der Karte). Der Name **„LifeInvader“** in der Legende kommt aus `Config.Blip.label` via `EndTextCommandSetBlipName`.

### Auf Game Build `b3407` (viele aktuelle FiveM-Installationen)

- **Legende zeigt oft „Lester“** (oder anderen GTA-Sprite-Text) statt **„LifeInvader“**.
- **Ursache:** Auf `b3407` crasht die Native `EndTextCommandSetBlipName`. Die Resource setzt den Namen deshalb **absichtlich nicht** (`Config.Blip.nameMode = 'auto'`, Build `3407` in `disableNameForBuilds`).
- **Das rote L auf der Karte ist korrekt** — nur der **Text in der Legende** fällt auf den GTA-Standard zurück.
- **Das ist kein Fehler der Standort-/Blip-Logik** — lokal reproduzierbares, build-spezifisches Native-Problem.

### Auf Build `b3323` (Beispiel: unauffällig)

- Custom-Name **„LifeInvader“** in der Legende funktioniert mit derselben Resource.

### Einstellungen in `config.lua`

| Option | Bedeutung |
| --- | --- |
| `sprite = 77` | Rotes L (LifeInvader-Style) |
| `nameMode = 'auto'` | Namen auf problematischen Builds überspringen (empfohlen) |
| `disableNameForBuilds = { [3407] = true }` | Standard: Schutz vor Crash auf `b3407` |
| `nameMode = 'native'` | Immer Namen setzen — **Crash-Risiko auf `b3407`** |

Eigenen Build prüfen: Client-Konsole / Server — FiveM **Game Build**-Nummer (z. B. `3407`).

---

## Version 1.1.32

- **Team Anzeigen:** Vollständiger Bearbeitungsdialog ohne Kosten
- **Gesperrt:** Kennzeichnung unter „Meine Anzeigen“, kein Live-Ticker mehr
- **Erstattungen:** Grund Pflicht · **Live-Ticker:** neues Design mit Animationen

## Version 1.1.31

- **Blacklist:** Spieler sperren (1–30 Tage / dauerhaft) und entsperren
- **Team:** Anzeigen moderieren, Rückerstattungen auf LifeInvader-Guthaben
- **Remote-Open:** Befehl `/lifeinvader` für berechtigtes Team

## Version 1.1.30

- **Fix Live-Ticker:** Lauftext läuft vollständig durch (kein doppelter Text bei einem Eintrag)
- **Kategorien:** `Config.CategoryIcons` + Icon-Picker im Team-Panel

## Version 1.1.29

- **Live-Ticker:** Nur gebuchte Anzeigen als `+++ Titel +++`, max. 5 gleichzeitig, kein Laufband wenn leer
- **Team:** Alle Live-Ticker-Anzeigen aktivieren/deaktivieren und sortieren (`livdb fix` für neue Spalten)

## Version 1.1.28

- **Fix Team:** Kategorien & Live-Ticker per Griff (⋮⋮) sortieren — zuverlässig in FiveM-NUI

## Version 1.1.27

- **Team:** Meldungen als Toast oben rechts im Tablet
- **Team Live-Ticker:** Einträge verwalten und sortieren (`lifeinvader_ticker`; bei bestehenden Servern `livdb fix`)
- **Team Kategorien:** Icons in der Liste, Sortierung per Drag & Drop

## Version 1.1.16

- **Fix Buchungen:** Historie war beim Öffnen leer — `history` fehlte in der NUI-Nachricht (Daten kommen aus `lifeinvader_feeds`, keine Extra-Tabelle nötig)

## Version 1.1.15

- **Meine Anzeigen:** Name, Ablaufdatum inkl. Uhrzeit, Live-Countdown
- **Buchungen:** Ablaufdatum in Liste & Detail; bei Anonym der echte Name nur in der Buchungsansicht

## Version 1.1.14

- Blip wieder Sprite **77** (rotes L)
- Zwei Standorte aktiv (Vespucci + Pillbox)
- NPC: **s_m_m_lifeinvad_01** (LifeInvader-Mitarbeiter, Story/Online)

## Version 1.1.13

- Cleanup: ungenutzter Code entfernt, Config bereinigt
- Kategorien nur aus DB (kein `Config.Categories` mehr)
- `Config.OpenHours` geplant, aktuell `nil`
- Blip-Test (`/ec_li_blip_test`) nur bei `Config.Debug = true`
- Live-Defaults: `Config.fake = false`, `Config.World.debug = false`

## Version 1.1.12

- Blip-Name-Guard fuer problematische GameBuilds (z. B. b3407)
- Neue Config: `Config.Blip.nameMode` (`auto`/`native`/`none`)
- Neue Config: `Config.Blip.disableNameForBuilds`

## Version 1.1.9

- Blips wie `nxt_driving_school`: Sprite 225 + `AddTextComponentString` (nicht Sprite 77/Lester)

## Version 1.1.8

- Fix: `decodePremium` (UI/History öffnet wieder)

## Version 1.1.7

- Fix: Native-Crash `EndTextCommandSetBlipName` — Spawn wieder wie v1.0
- Server-Log: „X Blips/NPCs gespawnt“ mit Koordinaten

## Version 1.1.6

- Blip-Sprite 77 (rotes L), Server-Debug für Blips/NPCs (`Config.World.debug`)
- NPC-Spawn verzögert + Collision-Wait + Retries

## Version 1.1.5

- NPC: v1.0-Spawn zurück, kein PlaceEntityOnGroundProperly; kein Respawn-Wipe
- Blip: ESX-Banking-Stil (AddTextComponentString), Sprite 521

## Version 1.1.4

- Blip-Name „LifeInvader“ via AddTextEntry (Sprite 407 zeigte „Information“)
- NPC-Spawn: Mutex entfernt, Retry, Native-Zone-Fallback, `spawnZOffset` für MLO

## Version 1.1.3

- Blips wie Banking: gleicher Name, kein Lester-Sprite (77), keine Custom-Category
- Kein Dreifach-Spawn beim Resource-Start

## Version 1.1.2

- Blip-Legende: `AddTextEntry` für Kategorie (kein „ : LifeInvader“ mehr)
- Beide Standorte mit Blip (Pillbox wieder aktiv)

## Version 1.1.1

- Blips: ein Marker pro Standort, gruppiert als „LifeInvader“ (`Config.Blip` + optional `blipLabel`)
- Buchungs-Popup: Rechnungsaufschlüsselung inkl. Premium-Kosten
- Tooltips für Kontakt-Icons (Feed + Modal)

## Version 1.1.0

- Buchungshistorie, Erneuern, Feed-Popup, Kontakt-Icons

---

<p align="center">Entwicklung: privates Repo <code>ec_lifeinvader_dev</code> · Runtime: <code>ec_lifeinvader</code></p>
