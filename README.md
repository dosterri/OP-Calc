# OP Calc

Wissenschaftlicher Rechner für iPhone mit **strukturiertem Formel-Editor**: Brüche, Wurzeln,
Exponenten und Funktionen sind echte Bausteine, die man antippen und einzeln bearbeiten kann.
Es wird **exakt** gerechnet (3/4 + 1/3 = 13/12, √12 = 2√3, sin(π/6) = 1/2), bis man „≈“ drückt.

- Native App in Swift + SwiftUI, iOS 17+, iPhone im Hochformat
- 100 % lokal und offline, kein Konto, keine Werbung, keine externen Pakete
- Verlauf mit SwiftData, Dark Mode, haptisches Feedback

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

## Build über GitHub Actions

Der Workflow `.github/workflows/ios-build.yml` läuft bei jedem Push auf `main`:

1. Build für den iOS-Simulator (inkl. Test-Target)
2. Unsignierter Build für echte iPhones → **IPA als Artifact `OPCalc-ipa`**
3. Unit-Tests im Simulator
4. Kompakte Übersicht (Testanzahl, Compiler-Fehler, fehlgeschlagene Tests) in der Zusammenfassung des Laufs

Die IPA wird vor den Tests gebaut – du bekommst sie also auch dann, wenn ein Test rot ist.

## Aufs iPhone (Sideloadly, kostenlose Apple-ID)

1. Auf GitHub im Repository **Actions** öffnen, den neuesten grünen Lauf anklicken.
2. Unten bei **Artifacts** auf **OPCalc-ipa** klicken und die ZIP-Datei herunterladen.
3. ZIP entpacken → `OPCalc.ipa`.
4. iPhone per Kabel anschließen, **Sideloadly** starten, die IPA hineinziehen, Apple-ID eintragen, **Start**.
5. Auf dem iPhone: *Einstellungen → Allgemein → VPN und Geräteverwaltung* → deiner Apple-ID vertrauen.
6. Nach 7 Tagen läuft die Signatur ab → Schritt 4 wiederholen (der Verlauf bleibt erhalten).

## Grenzen (bewusst)

- Exakt sind nur Werte der Form Bruch · √n · πⁱ · eʲ und Summen davon. ∛2 + √3, sin(1), 2^π usw. werden als Näherung (≈) angezeigt.
- Exakte Zahlen bis ca. 12 000 Stellen; n! exakt bis 3000!.
- Keine komplexen Zahlen (√(−4) meldet „nicht reell“).
