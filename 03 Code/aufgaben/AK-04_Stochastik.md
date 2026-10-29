# AK-04 – Stochastik und Statistik
> Aufgabenkarte für Claude Code · erstellt in Runde R02 (2026-10-29 10:01) · Bezug: E-007, US-010

## 1 · Ziel
Bereich „Stochastik“ im Modus-Menü, dazu nCr/nPr im Rechner (Funktionsebene, exakt mit BigInt).
- **Verteilungen:** Binomial, Normal, Poisson, hypergeometrisch, geometrisch. Je: P(X = k), P(X ≤ k), P(a ≤ X ≤ b), Erwartungswert, Standardabweichung; Normal zusätzlich Quantil (inverse Verteilung). Diagramm (Säulen bzw. Glockenkurve) mit markierter Fläche.
- **Statistik:** Liste eingeben (Werte, optional Häufigkeiten) → n, Summe, Mittelwert, Median, Modus, Quartile, Spannweite, empirische und Stichproben-Standardabweichung, Boxplot.
- **Regression:** Wertepaare (x, y) → lineare Regression mit r und r², im Graph 2D zeigen (Soll: quadratisch, exponentiell).

## 2 · Technischer Weg
- Binomial-/hypergeometrische Wahrscheinlichkeiten exakt als Bruch über BigInt, wenn n ≤ 1000 (Grenze als benannte Konstante, M-C10), sonst über log-Gamma mit „≈“.
- Normalverteilung über `erfc` (Foundation), Quantil über Acklam + ein Newton-Schritt.
- Rechenkern ohne SwiftUI, alles mit XCTest.

## 3 · Akzeptanzkriterien
| ID | Kriterium | Nachweis | Nachweisart |
|---|---|---|---|
| K1 | Build grün | Log | Verifikation |
| K2 | XCTest gegen Tabellenwerte: B(10; 0,5) P(X ≤ 3) = 176/1024; Φ(1,96) ≈ 0,97500; Quantil 0,975 ≈ 1,95996; Poisson λ=2 P(X=3) ≈ 0,180447; Stichproben-σ von 2,4,4,4,5,5,7,9 ≈ 2,1381 | Log | Test |
| K3 | Diagramme auf iPhone SE lesbar | Simulator | Validierung |
