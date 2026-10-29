# AK-05 – Differentialgleichungen
> Aufgabenkarte für Claude Code · erstellt in Runde R02 (2026-10-29 10:01) · Bezug: E-007, US-011
> Voraussetzung: AK-02 (Graph, NumericEvaluator).

## 1 · Ziel
Bereich „DGL“ im Modus-Menü:
- **1. Ordnung** y′ = f(x, y) mit y(x₀) = y₀: Richtungsfeld + Lösungskurve; Antippen im Feld setzt einen neuen Anfangswert.
- **2. Ordnung** y″ = f(x, y, y′) mit y(x₀), y′(x₀).
- **System** x′ = f(t, x, y), y′ = g(t, x, y) mit Phasenbild (Soll).
- Wertetabelle der Lösung, Wert an einer Stelle mit „≈“.

## 2 · Technischer Weg
- Variablen `y` und `y′` als Editor-Bausteine (`ItemKind.variable`), Belegung im `NumericEvaluator`.
- Löser: Dormand-Prince 5(4) mit Schrittweitensteuerung, Abbruch bei Polstelle/Überlauf mit Meldung statt Absturz; Toleranzen als benannte Konstanten (M-C10).
- Zeichnen über die Graph-Ansicht aus AK-02 (Richtungsfeld als zusätzliche Ebene).
- Kann: exakte Lösung für lineare DGL mit konstanten Koeffizienten (charakteristisches Polynom aus AK-03).

## 3 · Akzeptanzkriterien
| ID | Kriterium | Nachweis | Nachweisart |
|---|---|---|---|
| K1 | Build grün | Log | Verifikation |
| K2 | XCTest: y′ = y, y(0)=1 → y(1) ≈ e (± 1e−8); y″ = −y, y(0)=0, y′(0)=1 → y(π) ≈ 0 (± 1e−7); y′ = y², y(0)=1 bricht vor x = 1 mit Meldung ab | Log | Test |
| K3 | Richtungsfeld flüssig beim Verschieben | Simulator | Validierung |
