# AK-nn – <Titel>
> Aufgabenkarte für Claude Code · erstellt in Runde Rnn · Arbeitspaket AP-n.m · Bezug: E-…, US-…, OP-…
> Ergebnisblock am Ende an `00 Projektgedaechtnis/Runden/Rnn_…/Rnn_Protokoll.md` anhängen.

## 0 · So startest du (für Ricco)
1. Im Projektordner ein Terminal öffnen und `claude` starten (bzw. in der Desktop-App einen Claude-Code-Chat im Projektordner).
2. In den **Plan-Modus** wechseln (Shift+Tab) und schreiben:
   > Lies `CLAUDE.md` und `03 Code/aufgaben/AK-nn_<Titel>.md` und setze die Karte um. Stell zuerst die Fragen aus Abschnitt 7 und zeig den Plan.

## 1 · Ziel und zu stützende Entscheidungen
| Entscheidung | wofür | was das Ergebnis liefern muss |
|---|---|---|
| | | |
Was muss enthalten sein, damit diese Fragen beantwortbar sind? <sonst Lücke nennen>

## 2 · Vorab lesen
- `CLAUDE.md`, `03 Code/ENTWICKLUNGSLEITFADEN.md` (Pflicht)
- …

## 3 · Arbeitspakete
| ID | Paket | Priorität |
|---|---|---|
| AK-nn.1 | | Muss |
| AK-nn.2 | | Soll |
| AK-nn.3 | | Kann |

## 4 · Akzeptanzkriterien
| ID | Kriterium | Nachweis | Nachweisart |
|---|---|---|---|
| K1 | | | Verifikation / Test / Validierung |

## 5 · Arbeitsweise und Regeln
- Zweig `ak-nn-<kurz>`, am Ende Merge nach `main`; Commits `AK-nn: …`.
- Reservierte Annahme-IDs: A-1nn…A-1nn.
- Parameter nie unkommentiert im Code (Beleg `L-Key` oder `A-nnn`).
- Keine Entscheidungen von Tragweite allein – als Frage an Ricco.
- Gedächtnis-Dateien (`00 Projektgedaechtnis/`, `01 Evidenz/quellen.md`, `02 Produkt/*`) **nicht** bearbeiten; Vorschläge in den Ergebnisblock.
- Vor jedem Commit `python "03 Code/tools/lint.py" --since HEAD`; bei Projektdatei-Änderungen `python "03 Code/tools/pbx_check.py"`.

## 6 · Ergebnisblock (Vorlage, ans Rundenprotokoll anhängen)
```
### Ergebnis AK-nn (Claude Code, JJJJ-MM-TT)
- Umgesetzt: …
- Dateien: …
- Tests/Build: … (Nachweisart)
- Kennwerte: … (Nachweisart)
- Neue Annahmen (Vorschlag): A-1nn …
- Neue Quellen (Vorschlag): …
- Abweichungen von der Karte (mit Grund): …
- Offene Punkte: …
- Git-Stand: Zweig, letzter Commit
```

## 7 · Offene Fragen für den Plan-Modus
1. …
