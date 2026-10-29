# AK-06 – Graph 3D
> Aufgabenkarte für Claude Code · erstellt in Runde R02 (2026-10-29 10:01) · Bezug: E-007, US-012
> Voraussetzung: AK-02 (NumericEvaluator, Variablen x und y).

## 1 · Ziel
Bereich „Graph 3D“ im Modus-Menü: z = f(x, y) als farbige Fläche (Farbe nach Höhe), mit einem Finger drehen, mit zwei Fingern zoomen, Achsen mit Beschriftung, Bereich für x und y einstellbar. Bis zu 3 Flächen.

## 2 · Technischer Weg (im Plan bestätigen)
- Eigene Darstellung in `Canvas`: Gitter 40×40 (Konstante, M-C10), Projektion mit Drehmatrix, Maler-Algorithmus (Vierecke nach Tiefe sortiert), einfache Schattierung über Flächennormale. Kein SceneKit (von Apple nicht mehr weiterentwickelt), RealityKit-`RealityView` erst ab iOS 18 – Mindestversion ist 17.
- Nicht definierte Werte (nan, ±∞) lassen Lücken statt Spitzen.
- Kann: Höhenlinien, Punkt antippen → (x, y, z), partielle Ableitungen und kritische Punkte (Gradient = 0) numerisch, Parameterkurven im Raum.

## 3 · Akzeptanzkriterien
| ID | Kriterium | Nachweis | Nachweisart |
|---|---|---|---|
| K1 | Build grün | Log | Verifikation |
| K2 | XCTest: Projektion, Tiefensortierung, Gitter mit nan-Werten | Log | Test |
| K3 | sin(x)·cos(y) dreht flüssig (≥ 50 fps auf dem iPhone) | iPhone | Validierung |
