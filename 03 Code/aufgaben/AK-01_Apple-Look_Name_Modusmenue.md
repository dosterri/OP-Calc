# AK-01 – Apple-Look, Name „Rechner“, Modus-Menü
> Aufgabenkarte für Claude Code · erstellt in Runde R02 (2026-10-29 10:01) · Bezug: E-004, E-005, E-006, US-008, NF-02
> Ergebnisblock am Ende an `00 Projektgedaechtnis/Runden/R02_2026-10-29_Ausbau-Plan-und-Look/R02_Protokoll.md` anhängen.

## 1 · Ziel
Die App sieht aus wie Apples Rechner (schwarz, runde Tasten, orange Operatoren, große helle Ergebnisziffern), behält aber den Formel-Editor. Sie heißt auf dem Home-Bildschirm „Rechner“. Eine Taste unten links öffnet ein Menü der Bereiche; die Bereiche der Folgekarten hängen sich dort ein.

## 2 · Vorab lesen
`CLAUDE.md`, `03 Code/ENTWICKLUNGSLEITFADEN.md`, `OPCalc/Views/Keyboard/KeyboardView.swift`, `Views/Calculator/*`, `App/RootView.swift`.

## 3 · Arbeitspakete
| ID | Paket | Priorität |
|---|---|---|
| AK-01.1 | `CFBundleDisplayName` = „Rechner“, Titel im Code anpassen; Bundle-ID, Target, Ordner bleiben | Muss |
| AK-01.2 | Farbschema dunkel fest (`preferredColorScheme(.dark)`), Hintergrund Schwarz | Muss |
| AK-01.3 | Tasten rund (Kapsel, bei quadratischer Fläche Kreis), Farben: Ziffern dunkelgrau, Operatoren und „=“ orange, AC/⌫ hellgrau mit schwarzer Schrift, Funktionen dunkler grau; gedrückt heller | Muss |
| AK-01.4 | Anzeige: Formel ohne Kartenhintergrund, Ergebnis groß, dünn, weiß, rechtsbündig | Muss |
| AK-01.5 | Navigationszeile schmaler und dezent (kleine Kapseln) | Soll |
| AK-01.6 | Modus-Taste unten links (`AppMode`), Menü mit allen fertigen Bereichen; `RootView` schaltet um; Wahl in `UserDefaults` | Muss |
| AK-01.7 | Verlauf weiter erreichbar (Symbol oben rechts) | Muss |

## 4 · Akzeptanzkriterien
| ID | Kriterium | Nachweis | Nachweisart |
|---|---|---|---|
| K1 | `mac_build.sh alles` grün | Log | Verifikation |
| K2 | Bestehende XCTests grün, keine Rechenkern-Änderung | Log | Test |
| K3 | Simulator-Bildschirmfoto zeigt Apple-Stil, alle Tasten erreichbar und lesbar (iPhone SE bis Pro Max) | Bildschirmfoto | Validierung (Simulator) |
| K4 | Home-Bildschirm zeigt „Rechner“ | Bildschirmfoto | Validierung (Simulator) |

## 5 · Regeln
Zweig `entwicklung`, Commit `AK-01: …`. Keine Apple-Grafiken oder -Symbole kopieren, nur Farben und Formen nachempfinden. Texte nach M-C11.
