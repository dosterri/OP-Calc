# Anforderungen

> Master-Datei. Stand: 2026-10-29 11:16 (R02). Etappe 1 aus `README.md`, Ideen aus `OP Calc.txt` und Riccos Auftrag vom 2026-10-29.

| ID | Anforderung | Stand |
|---|---|---|
| US-001 | Formel als Baum eingeben: Bruch, Potenz, √, ⁿ√, Klammern, Betrag, Funktionen sind Bausteine; Antippen setzt den Cursor auch in Nenner und Exponenten | Etappe 1 |
| US-002 | Exakt rechnen (Brüche, √, π, e), Näherung erst mit „≈“; Umschalten exakt/dezimal | Etappe 1 |
| US-003 | Bearbeiten ohne Neuanfang: Markieren, Undo/Redo, Bruch auflösen statt löschen | Etappe 1 |
| US-004 | Verlauf: jede Rechnung gespeichert und wieder bearbeitbar | Etappe 1 |
| US-005 | LGS-Löser (n×n, Gauß-Jordan, exakt mit Brüchen, auf Wunsch Lösungsweg) | AK-03 umgesetzt (R02) |
| US-006 | Graph 2D: mehrere Funktionen, Verschieben/Zoomen, Nullstellen, Extrema, Wendestellen, Schnittpunkte, Ableitung, Integral (Fläche) | AK-02 umgesetzt (R02) |
| US-007 | Windows-Fassung | Idee (E-002) |
| US-008 | Aussehen wie der Apple-Rechner, Editor bleibt (E-005); Name „Rechner“ (E-004); Modus-Menü (E-006) | AK-01 umgesetzt (R02) |
| US-009 | Gleichungen: Polynom bis Grad 4 exakt bzw. Grad n numerisch, beliebige Gleichung f(x) = g(x) numerisch | AK-03 umgesetzt (R02) |
| US-010 | Stochastik: nCr, nPr, Binomial-, Normal-, Poisson-, hypergeometrische Verteilung (P(X=k), P(X≤k), Intervall), Liste → Mittelwert, Median, Standardabweichung, Quartile, lineare Regression | AK-04 umgesetzt (R02) |
| US-011 | DGL: y′ = f(x, y) und y″ = f(x, y, y′) mit Anfangswert numerisch (Runge-Kutta 4), Richtungsfeld, Lösungskurve im Graph | AK-05 umgesetzt (R02) |
| US-012 | Graph 3D: z = f(x, y) als Fläche, drehen und zoomen | AK-06 umgesetzt (R02) |
| NF-01 | Lokal und offline, kein Konto, keine Werbung, keine externen Pakete | gilt |
| NF-02 | iPhone Hochformat, haptisches Feedback; Darstellung dunkel wie der Apple-Rechner (E-005) | Etappe 1 / AK-01 |

## Ideen (nicht eingeplant, Ricco wählt)
| ID | Idee | Nutzen |
|---|---|---|
| ID-01 | Matrizen-Rechner: Determinante, Inverse, Rang, Eigenwerte | Lineare Algebra, baut auf LGS (AK-03) auf |
| ID-02 | Komplexe Zahlen (i, Polar-/kartesische Form) | E-Technik, Nullstellen von Polynomen vollständig |
| ID-03 | Einheiten umrechnen (Länge, Masse, Temperatur, Zeit …) | Alltag, wie Apples „Umrechnen“ |
| ID-04 | Ableiten und Integrieren symbolisch (Term statt Zahl) | Hausaufgaben-Kontrolle, Kurvendiskussion mit Term |
| ID-05 | Wertetabelle zu Funktionen | Schule, schneller Überblick |
| ID-06 | Variablen speichern (A, B, …) und eigene Konstanten | längere Rechnungen in Schritten |
| ID-07 | Zahlensysteme: binär, hex, Bitoperationen | Informatik |
| ID-08 | Primfaktorzerlegung, ggT/kgV, Teiler | nutzt das vorhandene BigInt |
| ID-09 | Summe Σ und Produkt Π als Bausteine im Editor | Reihen, Folgen |
| ID-10 | Vektorrechnung / analytische Geometrie (Gerade, Ebene, Abstand, Schnitt) | Oberstufe, passt zu Graph 3D |
| ID-11 | Physikalische Konstanten (c, g, h, …) | Physik |
| ID-12 | Lösungsweg Schritt für Schritt (LGS, Ableitung, Gleichung) | Lernen |
| ID-13 | Hypothesentest, Konfidenzintervall, χ² | Stochastik vertieft |
| ID-14 | Prozent- und Zinsrechnung, Finanzmathematik | Alltag |
| ID-15 | Querformat mit mehr Tasten (wie Apple) | schnellerer Zugriff auf Funktionen |
| ID-16 | Widget / Kurzbefehl „letztes Ergebnis“ | Komfort |
