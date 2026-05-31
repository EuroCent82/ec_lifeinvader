# ec_lifeinvader — Befehle

Übersicht aller Chat- und Konsolenbefehle der Resource. Namen in **Kursiv** sind in `config.lua` änderbar (Standardwerte unten).

---

## Team & Tablet

### `/lifeinvader`

| | |
| --- | --- |
| **Seite** | Client → Server |
| **Konfiguration** | `Config.TeamRemoteOpen` (`command`, `enabled`, `helpText`) |
| **Berechtigung** | `Config.Permissions.teamOpen` **oder** `Config.Permissions.team` |
| **Wer** | Spieler mit Team-Recht |

**Was passiert:**

1. Prüft, ob das Tablet-NUI bereits offen ist — dann Abbruch.
2. Sendet `ec_lifeinvader:server:teamRemoteOpen` an den Server.
3. Server prüft `TeamRemoteOpen.enabled`, Berechtigung (`teamOpen` / `team`) und ob der Spieler das Tablet öffnen darf (Blacklist, Sperren usw.).
4. Bei Erfolg: Tablet-NUI öffnet sich — **ohne** am Standort/NPC zu sein (Remote-Open für Moderation).

Deaktivieren: `Config.TeamRemoteOpen.enabled = false`.

---

## Datenbank (Admin)

Basisbefehl konfigurierbar über `Config.Database.checkCommand` (Standard: **`livdb`**).

| Befehl | Berechtigung | Beschreibung |
| --- | --- | --- |
| `livdb check` | `dbCheck` oder `admin`, Server-Konsole immer | Liest den DB-Schema-Report: Framework, Install-Datei, vorhandene/fehlende Tabellen und Spalten-Patches. Ausgabe im Chat (rot) oder in der Konsole. |
| `livdb fix` · `livdb repair` | wie oben | Startet `RepairSchema`: legt fehlende Tabellen an und wendet Spalten-Patches an. Gibt angewendete Patches und abschließenden Status aus. |
| `livdb unread-reset` | wie oben | Setzt `ad_owner_last_read_at` und `guest_last_read_at` in **allen** Chats auf `NULL` → alle Unterhaltungen erscheinen wieder als ungelesen (Tests). |
| `livdb unread-reset [id]` | wie oben | Wie oben, aber nur für die Konversation mit der angegebenen numerischen ID. |

**Konsole vs. Spiel:** Mit `Config.Database.checkConsoleOnly = true` funktioniert der Befehl nur in der Server-Konsole (txAdmin), nicht als `/livdb` im Spiel.

**Berechtigung:** `Config.Permissions.dbCheck` (Standard: Gruppe `admin` / `superadmin` oder ACE `ec_lifeinvader.dbcheck`). Server-Konsole (`source == 0`) ist immer berechtigt.

---

## Benachrichtigungen (Test)

### `/linotify`

| | |
| --- | --- |
| **Seite** | Client |
| **Konfiguration** | `Config.Messages.notifications.testCommand` (Standard: `linotify`) |
| **Berechtigung** | Keine — jeder Spieler (nur zum Testen der GTA-Feed-Notify) |
| **Voraussetzung** | `Config.Messages.notifications.enabled = true` und `testCommand` gesetzt |

Zeigt eine **Nachrichten-Benachrichtigung** (`CHAR_LIFEINVADER`) lokal an — ohne echten Chat. Nützlich zum Prüfen von Texten in `Config.Messages.notifications.templates`.

**Syntax:** `/linotify [type] [zusatz]`

| Typ | Zusatz | Effekt |
| --- | --- | --- |
| `owner_single` | optional: Anzeigentitel | Inserent: eine neue Anfrage zu „Titel“. |
| `owner_multi` | optional: Anzahl (Standard 3) | Inserent: mehrere ungelesene Nachrichten. |
| `inquirer_reply` | optional: Anzeigentitel | Interessent: Antwort auf „Titel“. |
| `inquirer_multi` | optional: Anzahl (Standard 3) | Interessent: mehrere ungelesene Antworten. |
| `custom` | Freitext (Rest der Zeile) | Beliebiger Notify-Text. |

**Alias:** `guest_reply` → `inquirer_reply`, `guest_multi` → `inquirer_multi` (Legacy).

---

### `ec_li_testnotify` *(Server)*

| | |
| --- | --- |
| **Seite** | Server |
| **Berechtigung** | `Config.Permissions.admin` oder Server-Konsole |
| **Syntax** | `ec_li_testnotify [Titel …]` |

Sendet eine **Feed-Benachrichtigung** („Neue Anzeige online“) an alle Clients — wie bei einer echten neuen Anzeige (`Config.FeedNotifications`). Autor ist der ausführende Spieler bzw. „System“ von der Konsole. Ohne Titel: Standardtext *„Frische Anzeige aus Los Santos“*.

---

## Welt & Standorte (Entwicklung)

### `/ec_li_world_respawn`

| | |
| --- | --- |
| **Seite** | Client |
| **Berechtigung** | Keine |

Entfernt gespawnte NPCs, Objekte und Blips der LifeInvader-Standorte und spawnt sie neu (`EcLifeInvader.World.SpawnAll`). Hilfreich nach Config-Änderungen an Standorten, ohne die ganze Resource neu zu starten.

---

### `/ec_li_world_debug`

| | |
| --- | --- |
| **Seite** | Client → Server |
| **Berechtigung** | Keine (Ausgabe nur wenn Debug aktiv) |
| **Voraussetzung** | `Config.Debug = true` **oder** `Config.World.debug = true` |

Meldet an den Server, welche Blips, NPCs und Objekte clientseitig gespawnt wurden. Der Server druckt einen detaillierten Report in die **Server-Konsole** (Koordinaten, Modell, OK/FEHLT). Ohne aktives Debug wird das Event ignoriert.

---

## Debug-only (`Config.Debug = true`)

Die Dateien `client/blip_test.lua` und `server/blip_test.lua` werden nur geladen, wenn `Config.Debug = true`. In Produktion **`Config.Debug = false`** lassen — dann existieren diese Befehle nicht.

### `/ec_li_blip_test`

Erstellt an der **aktuellen Spielerposition** einen Test-Blip (Sprite 40, gelb, Label „Hallo“) zum Vergleich mit LifeInvader-Blips (Legenden-Name, Native-Reihenfolge). Log-Ausgabe in F8 und Server-Konsole.

### `/ec_li_blip_test_clear`

Entfernt den zuletzt erzeugten Test-Blip.

---

## Kurzreferenz

| Befehl | Wer | Zweck |
| --- | --- | --- |
| `/lifeinvader` | Team | Tablet von überall öffnen |
| `livdb check` | Admin / Konsole | DB-Schema prüfen |
| `livdb fix` | Admin / Konsole | DB-Schema reparieren |
| `livdb unread-reset [id]` | Admin / Konsole | Gelesen-Status zurücksetzen |
| `/linotify …` | Alle (Test) | Nachrichten-Notify-Vorschau |
| `ec_li_testnotify …` | Admin / Konsole | Feed-Notify an alle senden |
| `/ec_li_world_respawn` | Dev | Standorte neu spawnen |
| `/ec_li_world_debug` | Dev | Spawn-Report in Server-Konsole |
| `/ec_li_blip_test` | Dev (`Debug`) | Isolierter Blip-Test |
| `/ec_li_blip_test_clear` | Dev (`Debug`) | Test-Blip löschen |

---

Siehe auch: **`config.lua`** (Permissions, `TeamRemoteOpen`, `Database`, `Messages.notifications`, `FeedNotifications`) · **`readme_config.md`**
