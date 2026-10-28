# CLAUDE.md – Startanweisung für Claude Code

Du arbeitest an einer iOS-App (Swift/SwiftUI/SwiftData) namens „OP Calc“, Ordner/Target `OPCalc`, Bundle-ID `com.opcalc.app`: wissenschaftlicher Rechner mit strukturiertem Formel-Editor und exakter Arithmetik (eigenes BigInt, Brüche, Wurzeln, π, e). Das Projekt läuft rundenbasiert nach `00 Projektgedaechtnis/00_START_HIER.md`. Die Vorgehensregeln folgen LeanGymLog (`A:\Dev\LeanGymLog`, übernommen 2026-10-28, E-003).

## Zuerst lesen (in dieser Reihenfolge)
1. `00 Projektgedaechtnis/Projektstatus.md` – aktueller Stand (kurz).
2. Die Aufgabenkarte, die Ricco nennt: `03 Code/aufgaben/AK-nn_*.md`. **Schreibt Ricco nur „Start“** (oder nennt keine Karte): `03 Code/aufgaben/AKTUELL.md` lesen und genau danach vorgehen. Am Ende einer Karte `AKTUELL.md` auf den neuen Stand bringen.
3. `03 Code/ENTWICKLUNGSLEITFADEN.md` – **Pflicht vor jedem Code**: Build am Mac, SwiftData-Regeln, Compiler-Stolpersteine (§6).
4. `README.md` – Architektur, Bedienung, bewusste Grenzen.

## Harte Regeln
- **Build lokal am Mac** (M-C05): `bash "03 Code/tools/mac/mac_build.sh" alles` (prüfen, Simulator, XCTest, Gerätebuild); aufs iPhone per Kabel mit `APP_GERAET=<Kennung> APP_INSTALLIEREN=ja bash "03 Code/tools/mac/mac_build.sh" signiert`. **Keine Builds über GitHub Actions** (`ios-build.yml` nur auf Riccos ausdrückliche Ansage). Läufst du am **Windows-Rechner**, kannst du nicht kompilieren – gebaut wird beim nächsten Mac-Termin. **Vor jedem Commit (auch am Mac):**
  - `python "03 Code/tools/lint.py" --since HEAD` (Stolpersteine),
  - bei Änderungen an `OPCalc.xcodeproj/project.pbxproj`: `python "03 Code/tools/pbx_check.py"`,
  - Rechenkern geändert: passender XCTest in `OPCalcTests/` (M-C06),
  - bei größeren Änderungen ein Review-Agent, der jede Aufrufstelle gegen die Deklaration prüft.
  - Builds bündeln: erst alles fertig schreiben, dann bauen, dann Fehler beheben.
- **Verlauf auf dem iPhone:** SwiftData-Modelle nur migrationssicher ändern (Standardwert oder optional, nie umbenennen).
- **Gedächtnis mitpflegen (M-C02):** Du darfst das Projektgedächtnis selbst aktualisieren (`00 Projektgedaechtnis/`, `01 Evidenz/quellen.md`, `02 Produkt/*`). Am Ende einer Karte oder eines Chats: Ergebnisblock ans Rundenprotokoll, neue offene Punkte, PDCA-Lehren, Riccos Entscheidungen aus dem Chat (mit Zitat), `Projektstatus.md` (≤ 80 Zeilen) und `AKTUELL.md`. Vorher `git pull --ff-only`, nicht blind überschreiben (M-G03), eine Master-Datei je Information (M-G01). Entscheidungen von Tragweite trifft weiter Ricco.
- **Einführung mitziehen (M-C12):** Sobald es eine Einführung gibt: Ändert eine Karte, was sie zeigt, wird sie in derselben Karte angepasst und im Simulator geprüft.
- Keine Entscheidungen von Tragweite allein – als Multiple-Choice-Frage mit Empfehlung an Ricco. **Entscheidungsseiten (M-D05):** nur Fragen, die jetzt zu entscheiden sind.
- **Texte in der App (M-C11):** aus Sicht des Endnutzers, klar, kurz, nicht nach KI klingend, kein Insiderwissen. Ohne Einzelfreigabe einbauen und im Bericht nennen.
- Näherungen immer mit „≈“ kennzeichnen (M-E06). Kein `fatalError` im Rechenpfad.
- Keine externen Pakete, keine Werbung, kein Tracking, keine Netzwerkzugriffe.
- Sprache: Deutsch, per Du. Kommentare im Code auf Deutsch, knapp, erklären das Warum.

## Projektaufbau
- App-Code im Wurzelordner (E-001): `OPCalc/` (App: `App/`, `Models/Numbers`, `Models/Formula`, `Services/`, `Utilities/`, `Views/`), `OPCalcTests/` (XCTest), `OPCalc.xcodeproj` (synchronisierte Ordner: neue Dateien werden automatisch kompiliert).
- Build: `03 Code/tools/mac/mac_build.sh`. CI `.github/workflows/ios-build.yml` nur noch als Rückfall, von Hand.
- `OP Calc.txt` = ursprüngliche Idee (Flutter, LGS-Löser, Plotter) – nicht Stand, sondern Ideenliste (OP-003).

## Git
- Arbeitszweig für alle Karten: **`entwicklung`**. `main` ist der zuletzt gebaute und auf dem iPhone geprüfte Stand. Commits `AK-nn: <Kurztitel>` bzw. `Rnn: <Kurztitel>`.
- Claude Code führt die Git-Befehle selbst aus, auch `git push`. Ohne Rückfrage nie: `--force`, `reset --hard`, `rebase`.
- Nie `git add -A` / `git add .`: Nur die eigenen Pfade einzeln hinzufügen.
- **Ein Projektordner (M-G07):** `A:\Dev\OP Calc` am Windows-Rechner, Arbeitskopie am Mac; Abgleich über GitHub, nur an einem Rechner gleichzeitig (vorher commit + push, am anderen `git pull --ff-only`). Keine Git-Worktrees.
- Commit-Nachrichten enden mit der Co-Author-Zeile aus der System-Vorgabe.

## Abschluss jeder Karte
Ergebnisblock (Vorlage `00 Projektgedaechtnis/Vorlagen/AK_Vorlage.md` §6) ans Rundenprotokoll anhängen: Umgesetzt, Dateien, Build/Tests mit **Nachweisart** (Verifikation / Test / Validierung), neue Annahmen und Quellen, Abweichungen, offene Punkte, Git-Stand. Ehrlich sagen, was nicht geprüft werden konnte. **Zeitstempel (M-G06):** Jeder Eintrag ins Gedächtnis trägt Datum und Uhrzeit `JJJJ-MM-TT HH:MM` (Ortszeit Berlin, per `date` abfragen).
