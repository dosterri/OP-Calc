# Entscheidungen (E-nnn)

> Master-Datei. IDs nie neu vergeben. Status: **gilt** · **vorläufig** (Claude-Vorschlag, Bestätigung durch Ricco offen) · **abgelöst durch E-mmm**.

| ID | Thema | Entscheidung | Alternativen | Begründung / Beleg | Entschieden durch | Datum | Status |
|---|---|---|---|---|---|---|---|
| E-001 | Ort des App-Codes | Code im Wurzelordner (`OPCalc/`, `OPCalcTests/`, `.xcodeproj`); `03 Code/` enthält Doku, Karten, Werkzeuge | Code nach `03 Code/` | wie LeanGymLog E-001: synchronisierte Ordner und Build hängen an den Pfaden; Bestand so | Methode | 2026-10-28 19:05 | gilt |
| E-002 | Technik | Nativ Swift/SwiftUI, iPhone, iOS 17+ (Etappe 1) | Flutter für iOS + Windows (Idee in `OP Calc.txt`) | so umgesetzt (Commit 29d52e5); Windows-Fassung offen (OP-003) | Bestand | 2026-10-28 19:05 | gilt |
| E-003 | Vorgehensregeln | Methode und Regeln aus LeanGymLog übernommen: Gedächtnis, Karten, Build am Mac, Claude Code pflegt Gedächtnis und pusht selbst | eigene, schlankere Regeln | Ricco 2026-10-28: „jedes Projekt jeweils mit dem Allgemeinen Vorgehensregeln, wie bei LeanGymLog ausstatten“ | Ricco | 2026-10-28 19:05 | gilt |
| E-004 | Name der App | Anzeigename „Rechner“; Bundle-ID `com.opcalc.app`, Ordner/Target `OPCalc` bleiben (Verlauf bleibt erhalten) | Rechenwerk (Empfehlung), Formelrechner, Kalkül, Mathe+ | Ricco 2026-10-29 (Freitext statt Vorschlag): „Rechner“. Hinweis: Apples Rechner heißt auf deutschen iPhones ebenso | Ricco | 2026-10-29 10:01 | gilt |
| E-005 | Aussehen | Apple-Stil: schwarz, runde Tasten, orange Operatoren, große helle Ergebnisziffern; der strukturierte Formel-Editor bleibt | 1:1-Nachbau (Querformat-Wissenschaft, Editor im Hintergrund); nur Farben | Ricco 2026-10-29: „Apple-Stil, Editor bleibt“; Editor ist der Kern der App (US-001) | Ricco | 2026-10-29 10:01 | gilt |
| E-006 | Navigation zwischen Bereichen | Modus-Taste unten links öffnet Menü (Rechner, Graph 2D, Gleichungen, Stochastik, DGL, Graph 3D) | Tab-Leiste unten | Ricco 2026-10-29: „Modus-Menü wie bei Apple“; Tastatur behält die volle Höhe | Ricco | 2026-10-29 10:01 | gilt |
| E-007 | Reihenfolge der Etappen | AK-01 Look → AK-02 Graph 2D → AK-03 Gleichungen/LGS → AK-04 Stochastik → AK-05 DGL → AK-06 Graph 3D | Grafik zuerst; Löser zuerst | Ricco 2026-10-29: Empfehlung gewählt; 2D-Graph legt Variablen-Auswertung für alle Folgekarten | Ricco | 2026-10-29 10:01 | gilt |
