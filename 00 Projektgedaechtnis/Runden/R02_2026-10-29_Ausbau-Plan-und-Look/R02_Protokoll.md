# R02 – Ausbau-Plan und Apple-Look

> Datum: 2026-10-29 10:01 · Werkzeug: Claude Code (Planer + Umsetzung, Auftrag direkt von Ricco) · Vorrunde: R01
> Kontext: L0 + L1 (Übergabeblock R01, cockpit, `02 Produkt/*`) + L2 (Leitfaden, README) + L3 (Views, Tastatur, Modell) – weil Planung mehrerer Etappen und Umbau der Oberfläche.

## Auftrag
Ricco 2026-10-29: „Kannst du die App so anpassen, dass sie aussieht wie der Apple Taschenrechner? Einen 2d und 3d Grafikrechner hinzufügen mit Funktionen wie Schnittpunkt, Wendestellen, Max/minimum etc., Gleichungssystemlöser, DGL-Löser, Stochastik und liste Funktionen die du noch einbauen könntest, die nützlich wären. Finde außerdem einen besseren normaleren Namen“

## Verlauf
### 1 · Entscheidungen und Plan (2026-10-29 10:01)
- Vorgehen: vier Multiple-Choice-Fragen mit Empfehlung an Ricco.
- Ergebnis: Name „Rechner“ (Freitext, nicht der Vorschlag „Rechenwerk“) → E-004; Apple-Stil, Editor bleibt → E-005; Modus-Menü unten links → E-006; Reihenfolge Look → 2D → Gleichungen → Stochastik → DGL → 3D → E-007.
- Karten AK-01…AK-06 in `03 Code/aufgaben/`, Anforderungen US-008…US-012 und Ideenliste ID-01…ID-16 in `02 Produkt/anforderungen.md`, Roadmap MS-2…MS-7.
- Neue IDs: E-004…E-007, US-008…US-012, ID-01…ID-16, MS-2…MS-7, OP-004, OP-005.

### Ergebnis AK-01 (Claude Code, 2026-10-29 10:10)
- Umgesetzt: Anzeigename „Rechner“ (nur `CFBundleDisplayName`), App fest dunkel (`UIUserInterfaceStyle = Dark` + `preferredColorScheme`), Tasten als Kapseln/Kreise in Apple-Farben (Ziffern dunkelgrau, Funktionen mittelgrau, Operatoren und „=“ orange, AC/⌫ hellgrau mit schwarzer Schrift, gedrückt heller), Navigationszeile schmaler, Formel ohne Kartenhintergrund rechts unten, Ergebnis 56 pt dünn. Modus-Taste unten links (Menü der Bereiche, `AppMode`, Wahl in UserDefaults `appMode`). Tastenbelegung: unten `[Modus, 0, ",", ≈, +, =]`; ×10ˣ wandert auf die f(x)-Ebene (ersetzt dort den doppelten Bruch).
- Dateien: `OPCalc.xcodeproj/project.pbxproj`, `OPCalc/App/RootView.swift`, `OPCalc/Models/AppMode.swift` (neu), `OPCalc/Models/CalculatorKey.swift`, `OPCalc/Services/CalculatorModel.swift`, `OPCalc/Utilities/MathLayouts.swift`, `OPCalc/Views/Calculator/CalculatorView.swift`, `…/DisplayView.swift`, `OPCalc/Views/Formula/FormulaEditorView.swift`, `…/MathRowView.swift`, `OPCalc/Views/Keyboard/KeyboardView.swift`, `README.md`.
- Tests/Build: `mac_build.sh alles` grün (sim, tests, geraet), 103 XCTests grün (Verifikation/Test); `lint.py` 0, `pbx_check.py` OK. Simulator iPhone 18 Pro: Bildschirmfotos, 3/4 + 1 = 7/4 exakt, Modus-Menü öffnet (Validierung im Simulator).
- Texte (M-C11): „Bereich wählen“ (Bedienungshilfe der Modus-Taste), Menüeintrag „Rechner“.
- Neue Annahmen: keine. Farben nach Augenmaß (keine Apple-Grafiken übernommen).
- Abweichungen: Modus-Taste zeigt ein festes Raster-Symbol statt des Rechner-Symbols „±“ – das sah aus wie eine Vorzeichen-Taste.
- Nicht geprüft: kleiner Bildschirm (iPhone SE), echtes iPhone (OP-004). Das Menü enthält bis AK-02 nur „Rechner“.
- Git-Stand: Zweig `entwicklung`, Commit `AK-01: Apple-Look, Name Rechner, Modus-Menü`.


### 2 · AK-02 bis AK-06 ohne Rückfragen (2026-10-29 11:16)
- Auftrag: Ricco 2026-10-29: „Ja, AK-02 starten“, dann „Mach alle AKs ohne Rückfragen einfach fertig“. Offene Detailfragen nach Empfehlung entschieden → E-008 (vorläufig).

### Ergebnis AK-02 bis AK-06 (Claude Code, 2026-10-29 11:16)
- Umgesetzt:
  - AK-02 Graph 2D: Variablen-Tasten, `NumericEvaluator`, symbolische Ableitung (`Derivative.swift`, auch Gradmaß), Nullstellen (Brent + Berührstellen), Hoch-/Tief-/Sattel-/Wendepunkte, Schnittpunkte, y-Achsenabschnitt, Wert, Integral mit Fläche (Gauß-Kronrod), Ableitung zeichnen, Spur, Pan/Zoom mit gleichem Maßstab; Funktionen als SwiftData-Modell `GraphFunction` (Schema ergänzt, alle Felder mit Standardwert).
  - AK-03 Gleichungen: LGS bis 6×6 exakt (Gauß-Jordan über `Rational`, sonst Double mit Pivotsuche; keine/unendlich viele Lösungen mit Parametern), Polynom bis Grad 6 (Teilertest + Grad 2 mit √ exakt, Rest numerisch, Anzahl nicht reeller Lösungen), beliebige Gleichung numerisch, „Im Graph zeigen“.
  - AK-04 Stochastik: Binomial (exakt bis n = 200), Normal (inkl. Quantil), Poisson, hypergeometrisch (exakt bis N = 1000), geometrisch; Säulen-/Glockendiagramm; Kombinatorik (nCr, nPr, n!, nᵏ); Statistik (Kennzahlen, Quartile nach A-001, Boxplot), Regression linear/quadratisch/exponentiell mit Diagramm und „Im Graph zeigen“.
  - AK-05 DGL: Dormand-Prince 5(4); 1. Ordnung mit Richtungsfeld, 2. Ordnung, System mit Phasenbild; Startpunkt per Antippen; Wert an einer Stelle; Abbruchmeldung bei Polstellen.
  - AK-06 Graph 3D: eigene Projektion in `Canvas`, bis 3 Flächen, Höhenfarben, Schattierung, Drehen/Zoomen, Bereich ±1…±50.
- Dateien: neu `OPCalc/Services/Analysis/*`, `OPCalc/Services/Solvers/*`, `OPCalc/Views/{Graph,Graph3D,Equations,Stochastics,Differential,Common}/*`, `OPCalc/Models/{GraphFunction,WorkspaceState}.swift`, `OPCalcTests/{AnalysisTests,SolverTests}.swift`; geändert `AppMode`, `CalculatorKey`, `CalculatorModel`, `KeyboardView`, `RootView`, `OPCalcApp`, README, Leitfaden §6.
- Tests/Build: `mac_build.sh alles` grün, 151 XCTests grün (Verifikation/Test). Simulator iPhone 18 Pro: alle sechs Bereiche bedient – x³−3x mit Hoch-/Tiefpunkt, x² − 2 → ±√2 exakt, B(10; 0,5) P(X ≤ 3) = 11/64, y′ = x − y mit Richtungsfeld, Fläche x² − y² gedreht (Validierung im Simulator).
- Review-Agent (alle Aufrufstellen gegen Deklarationen, Rechenkern nachgerechnet): 13 Befunde, behoben: Absturz bei geometrischer Verteilung mit p < 10⁻¹⁸, ∫√x / Halbkreis / ∫ln x lieferten „existiert nicht“, DGL meldete am Bereichsende fälschlich „bricht ab“, DGL wurde bei jedem Verschiebe-Bild neu gelöst, quadratische Regression mit Jahreszahlen, Poisson-Summe bei großem λ abgeschnitten, Teilertest-Explosion, Int-Umwandlungen ohne Absicherung, riesige nᵏ, 3D-z-Bereich pro Bild sortiert, Extremum-Art nur über linke Ableitung, Winkelmaß bei „t bis“. 5 neue Regressionstests.
- Texte (M-C11): Bereichsnamen, „Analyse“, Menüeinträge der Analyse, Hinweise („Tippe auf +, um eine Funktion einzugeben.“, „Leere Felder zählen als 0. Brüche und Wurzeln sind erlaubt.“, „Tippe in den Graphen, um den Startpunkt zu setzen.“), Fehlermeldungen der Eingaben.
- Neue Annahmen: A-001 (Quartile), A-002 (Abtastung), A-003 (DGL-Toleranz).
- Abweichungen von den Karten (Kann/Soll, nicht umgesetzt → OP-006): nCr/nPr nur im Bereich Stochastik, nicht als Rechnertaste (bräuchte neuen Baustein mit zwei Feldern); LGS-Lösungsweg; Wertetabelle; Parameter-Schieberegler; exakte DGL-Lösung; 3D-Punkt antippen, Höhenlinien, kritische Punkte.
- Nicht geprüft: echtes iPhone, iPhone SE, Bildrate beim 3D-Drehen auf dem Gerät (AK-06 K3).
- Git-Stand: Zweig `entwicklung`, Commit `AK-02–AK-06: …`.

### 3 · Aufs iPhone (2026-10-29 12:03)
- Ricco: „Ja, aufs iPhone“. `mac_build.sh signiert` auf „iPhone von Ricco“ (iPhone 16): grün, installiert und gestartet (Verifikation). Bedienung auf dem Gerät durch Ricco steht aus (OP-004, OP-007).

## Übergabeblock an R03 (ersetzt den obigen)
- Stand: AK-01 bis AK-06 fertig auf `entwicklung`, Build und 151 Tests grün, im Simulator bedient.
- Nächster Schritt: per Kabel aufs iPhone, alle Bereiche anfassen (OP-002, OP-004, OP-007); danach `entwicklung` nach `main`.
- Offene Fragen an Ricco: E-008 bestätigen; OP-005 (Zusatzideen); OP-006 (fehlende Kann-Punkte nachziehen?).

## Zusammenfassung
- Ausbau in sechs Karten geplant, freigegeben und vollständig umgesetzt (AK-01…AK-06); Review-Befunde behoben; Simulator geprüft, iPhone offen.

## PDCA
| | KI | Ricco |
|---|---|---|
| Was lief gut | Entscheidungen vor dem Code gebündelt abgefragt; Build beim ersten Lauf grün | – |
| Was lief schlecht | Erstes Modus-Symbol (±) erst auf dem Bildschirmfoto als missverständlich erkannt; ein Testerwartungswert falsch von Hand gerechnet; Review fand Absturz und falsche Ergebnisse bei Randfällen, die Tests nicht abdeckten | – |
| Maßnahme | PM-01: Bei numerischen Verfahren immer Randfälle testen (Wurzel-/Log-Ränder, Intervallende, extreme Parameter, Int-Umwandlung) | – |

## Manuelle Aufgaben für Ricco
1. Am Mac per Kabel installieren und ansehen: `APP_GERAET=<Kennung> APP_INSTALLIEREN=ja bash "03 Code/tools/mac/mac_build.sh" signiert` (OP-002, OP-004).
2. Aus der Ideenliste ID-01…ID-16 wählen, was nach AK-06 kommt (OP-005).

## Übergabeblock an R03
- Stand: AK-01 fertig auf `entwicklung`, Karten AK-02…AK-06 liegen bereit.
- Nächster Schritt: AK-02 Graph 2D (`03 Code/aufgaben/AK-02_Graph_2D.md`, zwei Fragen in §5).
- Offene Fragen an Ricco: OP-004 (Look auf dem iPhone ok?), OP-005 (Zusatzideen).
- Zu ladende Dateien: `AKTUELL.md`, AK-02-Karte, Leitfaden.
