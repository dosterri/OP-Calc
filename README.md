# Rechner (Projekt „OP Calc“)

Auf dem iPhone heißt die App „Rechner“ (E-004); Ordner, Target und Bundle-ID heißen weiter `OPCalc` bzw. `com.opcalc.app`.


Wissenschaftlicher Rechner für iPhone mit **strukturiertem Formel-Editor**: Brüche, Wurzeln,
Exponenten und Funktionen sind echte Bausteine, die man antippen und einzeln bearbeiten kann.
Es wird **exakt** gerechnet (3/4 + 1/3 = 13/12, √12 = 2√3, sin(π/6) = 1/2), bis man „≈“ drückt.

- Native App in Swift + SwiftUI, iOS 17+, iPhone im Hochformat
- 100 % lokal und offline, kein Konto, keine Werbung, keine externen Pakete
- Verlauf mit SwiftData, haptisches Feedback
- Aussehen wie der Apple-Rechner (schwarz, runde Tasten, orange Operatoren), Modus-Taste unten links für die Bereiche (AK-01)

## Bereiche (Modus-Taste unten links)

| Bereich | Umfang |
|---|---|
| Rechner | Formel-Editor, exakte Arithmetik, Verlauf (Etappe 1) |
| Graph | bis 6 Funktionen, Verschieben/Zoomen, Spur, Nullstellen, Hoch-/Tief-/Sattelpunkte, Wendepunkte, Schnittpunkte, y-Achsenabschnitt, Wert, Integral mit Fläche, Ableitung zeichnen (AK-02) |
| Graph 3D | bis 3 Flächen z = f(x, y), drehen, zoomen, Bereich ±1…±50 (AK-06) |
| Gleichungen | LGS bis 6×6 exakt mit Brüchen (eindeutig / keine / unendlich viele mit Parameter), Polynom bis Grad 6 (rationale Lösungen und Grad 2 exakt mit √, sonst ≈), beliebige Gleichung numerisch (AK-03) |
| Stochastik | Binomial-, Normal-, Poisson-, hypergeometrische, geometrische Verteilung mit Diagramm; Kombinatorik; Statistik mit Boxplot und Regression linear/quadratisch/exponentiell (AK-04) |
| Differentialgleichung | y′ = f(x, y) mit Richtungsfeld, y″ = f(x, y, y′), System x′/y′ mit Phasenbild; Startpunkt per Antippen; Wert an einer Stelle (AK-05) |

## Stand: Etappe 1 (MVP)

| Bereich | Umfang |
|---|---|
| Zahlen | Eigenes BigInt (beliebig groß), exakte Brüche, exakte Werte der Form Bruch · √n · πⁱ · eʲ |
| Editor | Formelbaum mit Cursorpfad, Antippen setzt Cursor, ◀ ▶ ▲ ▼, Markieren, Undo/Redo (200 Schritte) |
| Strukturen | Bruch, Potenz, √, ⁿ√, Klammern, Betrag, sin/cos/tan (+ Umkehrfunktionen), ln, log, n! |
| Auswertung | Exakt wo möglich (inkl. Tabellenwerte für Vielfache von 15°), sonst Näherung mit „≈“ |
| Verlauf | Jede Rechnung wird gespeichert und lässt sich wieder bearbeitbar laden |

### Bedienung in Kürze
- **Antippen** in der Formel setzt den Cursor an die nächstgelegene Stelle (auch in Nenner und Exponenten).
- **a/b** macht aus der Zahl links vom Cursor den Zähler; mit Markierung wird die Markierung zum Zähler.
- **⌫** am Anfang eines Nenners löst den Bruch auf (3/4 → 3÷4), statt ihn zu löschen. Lange drücken = alles löschen.
- **S⇔D** oder Tippen auf das Ergebnis wechselt zwischen exakt und dezimal.
- **f(x)** schaltet auf die Funktionsebene; nach einer Eingabe springt sie automatisch zurück.

## Projektaufbau

```
OPCalc/
├── App/          App-Einstieg, SwiftData-Container
├── Models/       Numbers/ (BigInt, Rational, ExactValue, Value), Formula/ (Editor-Baum, Cursor, AST), Verlauf
├── Services/     Parser, Auswertung, Tabellen, Editor-Logik, Ergebnisformat, CalculatorModel
├── Utilities/    Formelsatz-Layouts, Formen, Dezimalformatierung
└── Views/        Rechner, Formel, Tastatur, Verlauf
OPCalcTests/      Unit-Tests (XCTest)
```

Der Ordner `OPCalc/` ist ein **synchronisierter Ordner** (Xcode 16, objectVersion 77):
neue Dateien werden automatisch ins Projekt aufgenommen, die `project.pbxproj` muss nicht angepasst werden.
Gleiches gilt für `OPCalcTests/`.

## Build über GitHub Actions (nur noch Rückfall)

> Seit 2026-10-28 wird am Mac gebaut und per Kabel installiert (`03 Code/ENTWICKLUNGSLEITFADEN.md` §1). Der Workflow startet nur noch von Hand, auf Riccos Ansage.

Der Workflow `.github/workflows/ios-build.yml` (von Hand gestartet):

1. Build für den iOS-Simulator (inkl. Test-Target)
2. Unsignierter Build für echte iPhones → **IPA als Artifact `OPCalc-ipa`**
3. Unit-Tests im Simulator
4. Kompakte Übersicht (Testanzahl, Compiler-Fehler, fehlgeschlagene Tests) in der Zusammenfassung des Laufs

Die IPA wird vor den Tests gebaut – du bekommst sie also auch dann, wenn ein Test rot ist.

## Bauen am Mac
Im Projektordner `~/Dev/OP Calc`:
```bash
bash "03 Code/tools/mac/mac_build.sh" alles
```
Prüfskripte, Simulator-Build, Unit-Tests und unsignierter Gerätebuild; Logs in `build/logs/`.

Aufs iPhone per Kabel (Kennung aus `xcrun devicectl list devices`, Team-ID aus `~/.leangymlog-team-id`):
```bash
APP_GERAET=<Kennung> APP_INSTALLIEREN=ja bash "03 Code/tools/mac/mac_build.sh" signiert
```
Die IPA aus dem Rückfall-Workflow oben kann weiterhin per Sideloadly installiert werden.

## Grenzen (bewusst)

- Exakt sind nur Werte der Form Bruch · √n · πⁱ · eʲ und Summen davon. ∛2 + √3, sin(1), 2^π usw. werden als Näherung (≈) angezeigt.
- Exakte Zahlen bis ca. 12 000 Stellen; n! exakt bis 3000!.
- Keine komplexen Zahlen (√(−4) meldet „nicht reell“; Polynome nennen nur die Anzahl nicht reeller Lösungen).
- Graph, Analyse, DGL und 3D rechnen numerisch (Double); Ergebnisse tragen „≈“. Analyse sucht nur im sichtbaren Bereich.
- Eingaben in Gleichungen, Stochastik und DGL gelten nur bis zum Beenden der App; Graph-Funktionen werden gespeichert.
