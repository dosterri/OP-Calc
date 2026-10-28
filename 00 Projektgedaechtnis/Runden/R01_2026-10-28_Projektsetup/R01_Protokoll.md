# R01 – Projektsetup nach LeanGymLog-Methode und Quickfixes

> Datum: 2026-10-28 19:05 · Werkzeug: Claude Code (Planer + Umsetzung, Auftrag direkt von Ricco, aus dem LeanGymLog-Chat) · Vorrunde: –
> Kontext: README, `OP Calc.txt`, ganzer Code – weil Erstaufnahme.

## Auftrag
Ricco 2026-10-28: „jedes Projekt jeweils mit dem Allgemeinen Vorgehensregeln, wie bei LeanGymLog ausstatten, dir den Code angucken, Quickfixes machen und anschließend auf mein iPhone laden per USB“.

## Verlauf
### 1 · Gerüst nach LeanGymLog (2026-10-28 19:05)
- Angelegt: `CLAUDE.md`, `00 Projektgedaechtnis/` (START_HIER, Prozessanforderungen, Cockpit, Vorlagen), `01 Evidenz/quellen.md`, `02 Produkt/` (Anforderungen, Roadmap), `03 Code/` (Leitfaden mit Stolpersteinen aus LeanGymLog, `AKTUELL.md`, `tools/lint.py`, `tools/pbx_check.py`, `tools/mac/mac_build.sh`).
- CI `ios-build.yml` nur noch von Hand (`workflow_dispatch`), README-Hinweis.
- Neue IDs: E-001…E-003, OP-001…OP-003, US-001…US-007, NF-01/02, MS-1/2.

### 2 · Quickfixes (2026-10-28 19:17)
- Statische Durchsicht des ganzen Codes durch einen Review-Agenten (Python-Nachbau der Knuth-Division, 199 225 Zufallsfälle ohne Abweichung).
- Behoben: `ExactValue.swift` – Int-Überlauf bei π-/e-Exponenten in `Monomial.times` und `ExactValue.power` (Absturz bei verschachtelten Potenzen) → Überlaufprüfung, Ausweichen auf Näherung. `HistoryView.swift` – Ternär aus der String-Interpolation gezogen (Leitfaden §6).
- Nachweis: Verifikation (Lesen, `lint.py` 0 Auffälligkeiten, `pbx_check.py` OK). **Nicht kompiliert, Tests nicht ausgeführt.**

## Offen (nicht geändert, Einschätzung des Reviews)
- Dezimalanzeige bei riesigen nicht-rationalen Werten (π^1000) zeigt „inf“-Unsinn statt Meldung → kleine Designfrage.
- (π+e+√2+√3)^64 kann den Hauptthread lange blockieren.
- ⌫ lange drücken: löst danach vermutlich zusätzlich einen Fehler-Haptikstoß aus.

## Übergabeblock an R02
- Stand: Gerüst steht, Quickfixes drin, Zweig `entwicklung`.
- Nächster Schritt: am Mac `mac_build.sh alles`, dann `signiert` aufs iPhone (OP-001, OP-002).
- Offene Fragen an Ricco: nächste Etappe (OP-003).
