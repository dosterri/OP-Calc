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

## Zusammenfassung
- Ausbau in sechs Karten geplant und von Ricco in der Reihenfolge freigegeben; AK-01 fertig und im Simulator geprüft.

## PDCA
| | KI | Ricco |
|---|---|---|
| Was lief gut | Entscheidungen vor dem Code gebündelt abgefragt; Build beim ersten Lauf grün | – |
| Was lief schlecht | Erstes Modus-Symbol (±) erst auf dem Bildschirmfoto als missverständlich erkannt | – |
| Maßnahme | Bei neuen Tasten Symbol gegen bestehende Tastenbedeutungen prüfen (kein neuer PM-Eintrag, Einzelfall) | – |

## Manuelle Aufgaben für Ricco
1. Am Mac per Kabel installieren und ansehen: `APP_GERAET=<Kennung> APP_INSTALLIEREN=ja bash "03 Code/tools/mac/mac_build.sh" signiert` (OP-002, OP-004).
2. Aus der Ideenliste ID-01…ID-16 wählen, was nach AK-06 kommt (OP-005).

## Übergabeblock an R03
- Stand: AK-01 fertig auf `entwicklung`, Karten AK-02…AK-06 liegen bereit.
- Nächster Schritt: AK-02 Graph 2D (`03 Code/aufgaben/AK-02_Graph_2D.md`, zwei Fragen in §5).
- Offene Fragen an Ricco: OP-004 (Look auf dem iPhone ok?), OP-005 (Zusatzideen).
- Zu ladende Dateien: `AKTUELL.md`, AK-02-Karte, Leitfaden.
