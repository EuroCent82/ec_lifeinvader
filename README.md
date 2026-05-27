<h1 align="center">EC LifeInvader</h1>

<p align="center">
  <strong>LifeInvader Werbesystem</strong> — Anzeigen schalten, Feed, LifeInvader-Konto.
</p>

<p align="center">
  <a href="https://github.com/EuroCent82/ec_lifeinvader/releases"><img src="https://img.shields.io/badge/Version-1.0.0-ff3b30?style=for-the-badge" alt="Version 1.0.0" /></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT License" /></a>
</p>

---

## Überblick

**EC LifeInvader** ist ein FiveM-Script für In-Game-Werbeanzeigen im LifeInvader-Stil.

| Bereich | Beschreibung |
| --- | --- |
| **Feed** | Live-Anzeigen mit Kategorien, Suche, Spotlight |
| **Schalten** | Anzeige mit Laufzeit (7 / 14 / 30 Tage) und Premium-Optionen |
| **Konto** | Einzahlen / Auszahlen auf LifeInvader-Guthaben |

Resource-Name: **`ec_lifeinvader`**

---

## Installation

1. [Release](https://github.com/EuroCent82/ec_lifeinvader/releases) laden oder `ec_lifeinvader.zip` entpacken
2. Nach `resources/ec_lifeinvader/`
3. `config.lua` anpassen (Framework, Adapter)
4. `ensure ec_lifeinvader` — Tabellen werden beim ersten Start automatisch angelegt
   (Framework → `sql/install_esx.sql` / `install_qbcore.sql` / `install_qbox.sql`)

Manueller SQL-Import nur nötig, wenn `Config.Database.autoInstall = false`.

---

## Version

**1.0.0** — Erstes öffentliches Release (Feed, Anzeigen schalten/löschen, Konto, ESX/QBCore/Qbox, Phone-Bridges).

Entwicklung: privates Repo **`ec_lifeinvader_dev`**.
