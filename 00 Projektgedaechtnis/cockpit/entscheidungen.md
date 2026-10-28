# Entscheidungen (E-nnn)

> Master-Datei. IDs nie neu vergeben. Status: **gilt** · **vorläufig** (Claude-Vorschlag, Bestätigung durch Ricco offen) · **abgelöst durch E-mmm**.

| ID | Thema | Entscheidung | Alternativen | Begründung / Beleg | Entschieden durch | Datum | Status |
|---|---|---|---|---|---|---|---|
| E-001 | Ort des App-Codes | Code im Wurzelordner (`OPCalc/`, `OPCalcTests/`, `.xcodeproj`); `03 Code/` enthält Doku, Karten, Werkzeuge | Code nach `03 Code/` | wie LeanGymLog E-001: synchronisierte Ordner und Build hängen an den Pfaden; Bestand so | Methode | 2026-10-28 19:05 | gilt |
| E-002 | Technik | Nativ Swift/SwiftUI, iPhone, iOS 17+ (Etappe 1) | Flutter für iOS + Windows (Idee in `OP Calc.txt`) | so umgesetzt (Commit 29d52e5); Windows-Fassung offen (OP-003) | Bestand | 2026-10-28 19:05 | gilt |
| E-003 | Vorgehensregeln | Methode und Regeln aus LeanGymLog übernommen: Gedächtnis, Karten, Build am Mac, Claude Code pflegt Gedächtnis und pusht selbst | eigene, schlankere Regeln | Ricco 2026-10-28: „jedes Projekt jeweils mit dem Allgemeinen Vorgehensregeln, wie bei LeanGymLog ausstatten“ | Ricco | 2026-10-28 19:05 | gilt |
