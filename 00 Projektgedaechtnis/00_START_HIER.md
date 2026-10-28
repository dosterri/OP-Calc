# 00 · START HIER – OP Calc (wissenschaftlicher Rechner, Ordner/Target „OPCalc“)

> **An die KI:** Lies diese Datei und `Projektstatus.md` zu Beginn **jedes** Chats. Befolge das Vorgehen unten.
> Stand: 2026-10-28 19:05 · Version 1.0 · Methode übernommen aus LeanGymLog (`A:\Dev\LeanGymLog\00 Projektgedaechtnis\00_START_HIER.md`).

## 1 · Worum es geht
Native iOS-App (Swift/SwiftUI/SwiftData) für iPhone: wissenschaftlicher Rechner mit **strukturiertem Formel-Editor** (Brüche, Wurzeln, Exponenten als antippbare Bausteine) und **exakter Arithmetik** (eigenes BigInt, Brüche, Werte der Form Bruch · √n · πⁱ · eʲ) bis man „≈“ drückt. Lokal, offline, kein Konto, keine Werbung, keine externen Pakete. Ursprüngliche Idee (Flutter, iOS + Windows, LGS-Löser, Plotter): `OP Calc.txt`; umgesetzt ist Etappe 1 nativ in Swift (`README.md`).

## 2 · Rollen
| Rolle | Wer | Aufgaben |
|---|---|---|
| Entscheider | Ricco | entscheidet, beantwortet Rückfragen, erledigt manuelle Aufgaben (Mac-Termin, iPhone anschließen) |
| Planer | Claude in **Cowork** oder Claude Code, wenn Ricco den Auftrag dort gibt (im Protokoll vermerken) | Runden führen, prüfen, Entscheidungsvorlagen, Gedächtnis pflegen, Aufgabenkarten (`AK-nn`) |
| Umsetzung | **Claude Code** im Projektordner | Programmieraufgaben nach Aufgabenkarte, Commits und Push; hängt einen Ergebnisblock an das Rundenprotokoll und **pflegt das Gedächtnis mit** (M-C02). Liest zuerst `CLAUDE.md` |

## 3 · Rundenstart (Pflicht, in dieser Reihenfolge)
1. **L0 laden:** diese Datei + `Projektstatus.md`.
2. **Runde festlegen:** `Rnn` = letzte Zeile in `cockpit/runden.md` + 1. Ordner `Runden/Rnn_JJJJ-MM-TT_Kurztitel/` mit Protokoll aus `Vorlagen/Rnn_Protokoll_Vorlage.md` anlegen.
3. **Übergabeblock** der Vorrunde lesen (letzter Abschnitt des letzten Protokolls).
4. **Ladetiefe in einer Zeile nennen:** „Kontext: L0 + L1 (…) – weil …“.
5. Bei unklarem Auftrag: **eine** Rückfrage als Multiple Choice mit markierter Empfehlung, dann arbeiten.

## 4 · Gestuftes Laden
| Stufe | Inhalt | Wann |
|---|---|---|
| L0 | `00_START_HIER.md`, `Projektstatus.md` | immer |
| L1 | Übergabeblock, 1–3 Planungsdateien (nur relevante Zeilen): `cockpit/*`, `02 Produkt/*` | fast immer |
| L2 | ältere Protokolle, `Prozessanforderungen.md`, `03 Code/ENTWICKLUNGSLEITFADEN.md`, `README.md` (Architektur) | bei Bezug oder Unklarheit |
| L3 | Code (`OPCalc/`, `OPCalcTests/`) | gezielt, in Ausschnitten |

## 5 · Nach jeder Antwort · Rundenabschluss
- **Nach jeder Antwort** nur das Rundenprotokoll ergänzen (Anfrage · Vorgehen · Ergebnis · geänderte Dateien · neue IDs, 3–8 Zeilen). Neue Entscheidung sofort → `cockpit/entscheidungen.md`.
- **Rundenabschluss:** PDCA, Übergabeblock, `cockpit/*` pflegen, `Projektstatus.md` neu schreiben (≤ 80 Zeilen), `03 Code/aufgaben/AKTUELL.md`, Commit `Rnn: <Kurztitel>` und Push.
- **Zeitstempel (M-G06):** Jeder neue Eintrag trägt Datum und Uhrzeit `JJJJ-MM-TT HH:MM` (Ortszeit Berlin, per `date`).
- **Speicherfilter:** nur, was eine Folgerunde braucht.

## 6 · Kernregeln (Details: `Prozessanforderungen.md`)
1. **Single Source of Truth:** jede Informationsart genau eine Master-Datei (Tabelle unten).
2. **Die KI schlägt vor, Ricco entscheidet** (`E-nnn` mit Alternativen und Begründung).
3. **Verifikation ≠ Validierung:** Build/Tests grün = Verifikation. „Rechnet auf dem iPhone richtig“ = Validierung. Jede Aussage nennt ihre Nachweisart.
4. **Build lokal am Mac** (`03 Code/tools/mac/mac_build.sh`), aufs iPhone per Kabel. GitHub Actions nur auf Riccos Ansage. Am Windows-Rechner wird nicht kompiliert.
5. **Verlauf auf dem iPhone ist echte Nutzung:** SwiftData-Modelle nur migrationssicher ändern (Standardwert/optional).

## 7 · Wo steht was (Master-Dateien)
| Information | Master-Datei | IDs |
|---|---|---|
| Aktueller Gesamtstand | `Projektstatus.md` | – |
| Regeln der Arbeitsweise | `Prozessanforderungen.md` | `M-Xnn` |
| Runden, PDCA, offene Punkte, Entscheidungen, Annahmen | `cockpit/runden.md`, `pdca.md`, `offene_punkte.md`, `entscheidungen.md`, `annahmen.md` | `Rnn`, `PM-nn`, `OP-nnn`, `E-nnn`, `A-nnn` |
| Details einer Runde | `Runden/Rnn_…/Rnn_Protokoll.md` | – |
| Quellen | `01 Evidenz/quellen.md` | `L-Key` |
| Anforderungen, Roadmap | `02 Produkt/anforderungen.md`, `02 Produkt/roadmap.md` | `US-nnn`, `MS-n` |
| Aufgaben für Claude Code | `03 Code/aufgaben/AK-nn_*.md`, Einstieg `AKTUELL.md` | `AK-nn`, `K1…Kn` |
| Technik, Build, Stolpersteine | `03 Code/ENTWICKLUNGSLEITFADEN.md`, Architektur: `README.md` | – |

**Code liegt im Wurzelordner** (`OPCalc/`, `OPCalcTests/`, `OPCalc.xcodeproj`), nicht in `03 Code/` (E-001).

## 8 · Git
- Repo `github.com/dosterri/OP-Calc` (privat). Arbeitszweig `entwicklung`, `main` = zuletzt gebauter und geprüfter Stand.
- Nie parallel an zwei Rechnern arbeiten; vor jedem Wechsel commit + push, am anderen `git pull --ff-only`.
