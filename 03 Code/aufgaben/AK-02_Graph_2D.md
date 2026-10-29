# AK-02 – Graph 2D mit Kurvendiskussion
> Aufgabenkarte für Claude Code · erstellt in Runde R02 (2026-10-29 10:01) · Bezug: E-006, E-007, US-006
> Voraussetzung: AK-01 (Modus-Menü).

## 1 · Ziel
Bis zu 6 Funktionen f(x), g(x), … mit dem Formel-Editor eingeben und zeichnen. Verschieben und Zoomen mit den Fingern. Auf Knopfdruck: Nullstellen, Extrema (Hoch-/Tiefpunkt), Wendestellen, Schnittpunkte zweier Graphen, y-Achsenabschnitt, Wert an einer Stelle, Ableitung zeichnen, Integral (Fläche) zwischen zwei Grenzen. Diese Grundlage (Rechnen mit Variablen) nutzen AK-03, AK-05, AK-06.

## 2 · Technischer Weg (Vorschlag, im Plan bestätigen)
- **Variable x im Editor:** Taste `x` (Funktionsebene und Graph-Tastatur); `ItemKind.variable` und `Expr.variable` gibt es schon, Parser prüfen (implizites Mal: `2x`, `x sin(x)`).
- **Numerische Auswertung:** neuer `NumericEvaluator` (`Expr` + Belegung `[String: Double]` → `Double`), schnell, ohne exakte Arithmetik, nie `fatalError` (nicht definiert → `nan`).
- **Ableitung symbolisch:** `Expr.derivative(by:)` plus leichte Vereinfachung; f′ und f″ für Extrema/Wendestellen (genauer als Differenzenquotient).
- **Nullstellensuche:** Abtasten im sichtbaren Bereich, Vorzeichenwechsel → Brent-Verfahren; doppelte Nullstellen über Extremum von f mit |f| ≈ 0. Extrema = Nullstellen von f′ mit Vorzeichenwechsel, Wendestellen = Nullstellen von f″ mit Vorzeichenwechsel, Schnittpunkte = Nullstellen von f − g.
- **Integral:** adaptives Gauß-Kronrod oder Simpson, Ergebnis mit „≈“ (M-E06), Fläche schraffiert.
- **Zeichnen:** `Canvas`, adaptives Abtasten (mehr Punkte bei starker Krümmung), Sprungstellen trennen (tan, 1/x), Achsen und Gitter mit „runden“ Schrittweiten, Punkte antippbar mit Koordinaten.
- **Speichern:** Funktionen als neues SwiftData-Modell `GraphFunction` (uid, order, Formel als JSON wie im Verlauf, Farbe, sichtbar) – nach Leitfaden §5, in `Schema([...])` eintragen.

## 3 · Arbeitspakete
| ID | Paket | Priorität |
|---|---|---|
| AK-02.1 | Taste x, Parser/Evaluator für Variablen, `NumericEvaluator` | Muss |
| AK-02.2 | Symbolische Ableitung + Vereinfachung | Muss |
| AK-02.3 | Graph-Ansicht: Funktionsliste, Zeichnen, Pan/Zoom, Standardfenster, „Alles zeigen“ | Muss |
| AK-02.4 | Analyse: Nullstellen, Extrema, Wendestellen, Schnittpunkte, Wert an Stelle, Integral | Muss |
| AK-02.5 | Spur (Finger fährt die Kurve entlang, Koordinaten werden angezeigt) | Soll |
| AK-02.6 | Wertetabelle (ID-05) | Kann |
| AK-02.7 | Parameter a mit Schieberegler (f(x) = a·x²) | Kann |

## 4 · Akzeptanzkriterien
| ID | Kriterium | Nachweis | Nachweisart |
|---|---|---|---|
| K1 | `mac_build.sh alles` grün | Log | Verifikation |
| K2 | XCTest: Ableitungen (Polynom, sin, e^x, ln, Kettenregel), Nullstellen x³−x, Extrema/Wendestellen x³−3x, Schnittpunkt x² und x+2, ∫₀^π sin = 2 (± 1e−9) | Log | Test |
| K3 | tan(x) und 1/x ohne senkrechte Verbindungslinien | Bildschirmfoto | Validierung (Simulator) |
| K4 | Pan/Zoom flüssig mit 6 Funktionen | Simulator | Validierung |

## 5 · Offene Fragen für den Plan-Modus
1. Funktionen speichern über App-Neustart (SwiftData) oder nur für die Sitzung? Empfehlung: speichern.
2. Analyse-Ergebnisse exakt, wo möglich (z. B. Nullstellen von x²−2 als ±√2)? Empfehlung: erst numerisch mit „≈“, exakt in AK-03 für Polynome.
