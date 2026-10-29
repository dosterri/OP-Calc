# Projektstatus „Rechner“ (Projekt OP Calc)

> Stand: 2026-10-29 11:16 nach R02 · ≤ 80 Zeilen, zum Rundenabschluss neu schreiben (M-G02).

## Kurz
Die App heißt auf dem iPhone „Rechner“ (E-004) und sieht aus wie der Apple-Rechner, mit strukturiertem Formel-Editor und exakter Arithmetik (E-005). Über die Modus-Taste unten links (E-006) gibt es sechs Bereiche: Rechner, Graph (Kurvendiskussion), Graph 3D, Gleichungen (LGS, Polynome, beliebige Gleichung), Differentialgleichung, Stochastik (Verteilungen, Kombinatorik, Statistik, Regression). AK-01 bis AK-06 sind in R02 umgesetzt; Detailfragen ohne Rückfrage nach Empfehlung entschieden (E-008, vorläufig).

## Prüfstand
| Prüfung | Ergebnis | Nachweisart |
|---|---|---|
| `mac_build.sh alles` (sim, tests, geraet) | grün (R02) | Verifikation |
| XCTest | 151 grün (davon 48 neu für Graph, Löser, Stochastik, DGL, 3D) | Test |
| Review-Agent über alle neuen Dateien | 13 Befunde, alle behoben, 5 Regressionstests | Verifikation (Lesen, Nachrechnen) |
| Alle Bereiche im Simulator iPhone 18 Pro | bedient, Ergebnisse stimmen mit Handrechnung | Validierung (Simulator) |
| iPhone 16 (Ricco) | läuft, freigegeben 2026-10-29 12:04; iPhone SE und 3D-Bildrate nicht gemessen | Validierung |

## Technik
Swift 5, SwiftUI, SwiftData, iOS 17+, iPhone Hochformat, fest dunkel. Bundle-ID `com.opcalc.app`, Target `OPCalc`. Neues SwiftData-Modell `GraphFunction` (Graph- und 3D-Funktionen). Rechenkern ohne SwiftUI: `Services/Analysis` (numerische Auswertung, symbolische Ableitung, Nullstellen, Integral), `Services/Solvers` (LGS, Polynome, Stochastik, Statistik, DGL, 3D-Gitter). Build: `03 Code/tools/mac/mac_build.sh`.

## Nächste Schritte
1. Ricco: E-008 bestätigen (OP-008), fehlende Kann-Punkte (OP-006) und Zusatzideen ID-01…ID-16 (OP-005) wählen.
