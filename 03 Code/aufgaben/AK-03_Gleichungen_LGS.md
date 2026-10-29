# AK-03 – Gleichungen: LGS, Polynome, beliebige Gleichungen
> Aufgabenkarte für Claude Code · erstellt in Runde R02 (2026-10-29 10:01) · Bezug: E-007, US-005, US-009
> Voraussetzung: AK-02 (Variablen, NumericEvaluator, Nullstellensuche).

## 1 · Ziel
Ein Bereich „Gleichungen“ im Modus-Menü mit drei Arten:
1. **Lineares Gleichungssystem** n×m (bis 6×6), Einträge mit dem Formel-Editor (Brüche, √ erlaubt), Lösung exakt per Gauß-Jordan: eindeutig, keine Lösung oder unendlich viele (mit Parameter t).
2. **Polynom** bis Grad 4: Grad 1–2 exakt (mit √ über `ExactValue`), rationale Nullstellen exakt (Teilertest), Rest numerisch (Durand-Kerner) mit „≈“; komplexe Lösungen nur als Hinweis „keine reelle Lösung“, bis ID-02 entschieden ist.
3. **Beliebige Gleichung** links = rechts in x, numerisch in einem Intervall (Werkzeug aus AK-02).

## 2 · Arbeitspakete
| ID | Paket | Priorität |
|---|---|---|
| AK-03.1 | `LinearSystemSolver` (Rational exakt; Einträge mit √/π → numerisch mit „≈“) | Muss |
| AK-03.2 | Matrix-Eingabe (Zellen antippen, Größe ±) | Muss |
| AK-03.3 | `PolynomialSolver` | Muss |
| AK-03.4 | Allgemeine Gleichung, Lösung im Graph zeigen (Sprung nach Graph 2D) | Soll |
| AK-03.5 | Lösungsweg Schritt für Schritt für das LGS (US-005, ID-12) | Kann |

## 3 · Akzeptanzkriterien
| ID | Kriterium | Nachweis | Nachweisart |
|---|---|---|---|
| K1 | Build grün | Log | Verifikation |
| K2 | XCTest: 3×3 eindeutig mit Brüchen, singulär ohne Lösung, unendlich viele; x²−2 → ±√2 exakt; 2x³−3x²−11x+6 → −2, 1/2, 3 exakt; x⁵−x−1 ≈ 1,1673 | Log | Test |
| K3 | Matrix 4×4 auf iPhone SE bedienbar | Simulator | Validierung |
