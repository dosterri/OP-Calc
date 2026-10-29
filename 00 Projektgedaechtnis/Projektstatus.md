# Projektstatus „Rechner“ (Projekt OP Calc)

> Stand: 2026-10-29 10:10 nach R02 · ≤ 80 Zeilen, zum Rundenabschluss neu schreiben (M-G02).

## Kurz
Wissenschaftlicher Rechner mit Formel-Editor und exakter Arithmetik. Seit R02 heißt die App auf dem iPhone „Rechner“ (E-004) und sieht aus wie der Apple-Rechner (E-005, AK-01). Ausbau geplant: Graph 2D → Gleichungen/LGS → Stochastik → DGL → Graph 3D (E-007, AK-02…AK-06). Bereiche wählt man über die Modus-Taste unten links (E-006).

## Prüfstand
| Prüfung | Ergebnis | Nachweisart |
|---|---|---|
| `mac_build.sh alles` (sim, tests, geraet) | grün (R02) | Verifikation |
| XCTest | 103 grün | Test |
| BigInt-Division (Python-Nachbau) | 199 225 Zufallsfälle ohne Abweichung (R01) | Test |
| Apple-Look, Modus-Menü | Simulator iPhone 18 Pro geprüft; iPhone SE und echtes iPhone offen (OP-004) | Validierung (Simulator) |
| iPhone | offen (OP-002) | Validierung |

## Technik
Swift 5, SwiftUI, SwiftData, iOS 17+, iPhone Hochformat, fest dunkel. Bundle-ID `com.opcalc.app`, Target `OPCalc` (bleiben trotz neuem Namen). Build: `03 Code/tools/mac/mac_build.sh`.

## Nächste Schritte
1. AK-02 Graph 2D (`03 Code/aufgaben/AK-02_Graph_2D.md`).
2. Per Kabel aufs iPhone, Look ansehen (OP-002, OP-004).
3. Ricco: Zusatzideen ID-01…ID-16 wählen (OP-005).
