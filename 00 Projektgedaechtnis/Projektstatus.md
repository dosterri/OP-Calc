# Projektstatus OP Calc

> Stand: 2026-10-28 19:17 nach R01 · ≤ 80 Zeilen, zum Rundenabschluss neu schreiben (M-G02).

## Kurz
Etappe 1 (strukturierter Formel-Editor, exakte Arithmetik, Verlauf) ist programmiert, ~4 600 Zeilen + XCTest. Seit R01 nach LeanGymLog-Methode organisiert. **Am Mac noch nicht gebaut** (ob der frühere CI-Lauf je grün war, ist unbekannt).

## Prüfstand
| Prüfung | Ergebnis | Nachweisart |
|---|---|---|
| Kompilieren / XCTest | offen (OP-001) | – |
| Statische Durchsicht, ganzer Code | 2 Absturzstellen behoben, 3 kleine Befunde offen (R01-Protokoll) | Verifikation (Lesen) |
| BigInt-Division (Python-Nachbau) | 199 225 Zufallsfälle ohne Abweichung | Test |
| `lint.py` / `pbx_check.py` | 0 Auffälligkeiten / OK | Verifikation |
| iPhone | offen (OP-002) | Validierung |

## Technik
Swift 5, SwiftUI, SwiftData, iOS 17+, iPhone Hochformat, Bundle-ID `com.opcalc.app`, kein Team in der Projektdatei (kommt beim Bauen aus `~/.leangymlog-team-id`). Build: `03 Code/tools/mac/mac_build.sh`.

## Nächste Schritte
1. Am Mac bauen und testen (OP-001).
2. Per Kabel aufs iPhone (OP-002).
3. Ricco: nächste Etappe wählen – LGS-Löser, Plotter, Windows (OP-003).
