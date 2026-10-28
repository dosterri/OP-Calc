# Entwicklungsleitfaden OP Calc

Übernommen 2026-10-28 19:05 aus LeanGymLog / Mileage Log (dort entstanden und erprobt), auf OP Calc gekürzt. Architektur und Bedienung: `README.md`.

> **An den nächsten Chat:** Lies dieses Dokument vollständig, bevor du Code schreibst. Es beschreibt Fehler, die bereits einmal passiert sind.

## 1. Build und Installation (am Mac)
- Projektordner am Mac klonen bzw. `git pull --ff-only`, dann im Projektordner:
  - `bash "03 Code/tools/mac/mac_build.sh" alles` – Stolpersteine prüfen, Simulator-Build, XCTest, unsignierter Gerätebuild. Logs: `build/logs/`.
  - `APP_GERAET=<Kennung> bash "03 Code/tools/mac/mac_build.sh" signiert` – signierter Build fürs iPhone per Kabel (Team-ID aus `~/.leangymlog-team-id`, wie LeanGymLog); installiert erst mit `APP_INSTALLIEREN=ja`. Kennung: `xcrun devicectl list devices`.
- GitHub Actions (`.github/workflows/ios-build.yml`) nur als Rückfall und nur auf Riccos Ansage. Die Anleitung mit Sideloadly im README gilt nur für diesen Rückfall.
- Am Windows-Rechner: nicht kompilierbar. Vor jedem Commit `python "03 Code/tools/lint.py" --since HEAD`, bei Projektdatei-Änderungen `python "03 Code/tools/pbx_check.py"`.
- `OPCalc/` und `OPCalcTests/` sind synchronisierte Ordner: neue Dateien werden automatisch kompiliert, die `project.pbxproj` muss nicht angepasst werden.

## 5. Architektur und Code-Konventionen
- Rechenkern (`Models/Numbers`, `Services/Evaluator…`) ohne SwiftUI-Abhängigkeit, damit er testbar bleibt. Jede neue Rechenregel bekommt einen XCTest.
- Kein `fatalError`/`!` im Rechenpfad: Fehler als Ergebnis („nicht reell“, „zu groß“) zurückgeben.

### SwiftData-Regeln (wichtig, sonst Abstürze oder Datenverlust)
1. **Jede gespeicherte Eigenschaft braucht einen Standardwert** (`var name: String = ""`) oder muss optional sein. Nur so migriert SwiftData bestehende Daten beim Update automatisch. Eigenschaften nie umbenennen oder ihren Typ ändern, ohne ein `VersionedSchema` mit Migrationsplan.
2. **Neue Modelle** in der `Schema([...])`-Liste in der App (`OPCalc/App/`) eintragen.
3. **Beziehungen erst nach `context.insert(...)` setzen**, nie im `init`. Das Muster: `let entry = Kind(...); context.insert(entry); entry.parent = parent`.
4. **Die inverse Beziehung nur auf einer Seite** mit `@Relationship(deleteRule:inverse:)` deklarieren.
5. **Reihenfolge** über ein eigenes `order: Int` abbilden, denn SwiftData-Arrays sind ungeordnet. Dazu gibt es sortierte Hilfseigenschaften (`sortedEntries`).
6. **Löschen nach dem Schließen:** Erst `dismiss()`, dann nach ca. 0,5 s per `Task { @MainActor in … }` löschen. Sonst greift die ausblendende View auf ein gelöschtes Objekt zu und die App stürzt ab.
7. **Stabile IDs** für Fokus- und UserDefaults-Zwecke als eigene `uid: UUID` speichern. `persistentModelID` ändert sich bei neuen Objekten nach dem Speichern.
8. **Datenmigrationen**, also das nachträgliche Befüllen von Feldern, als idempotente Funktion beim App-Start ausführen. Einmalige Schritte werden über ein UserDefaults-Flag abgesichert.

## 6. Bekannte Compiler-Stolpersteine (alle bereits einmal aufgetreten)

| Problem | Lösung |
|---|---|
| `var x: Bool { set.entry… }`: Swift liest `set`/`get` am Anfang eines Getter-Körpers als Accessor. | `self.set…` schreiben oder die Variable anders benennen. |
| „unable to type-check this expression in reasonable time“ | `body` in kleine Teile zerlegen. **Kein `??` und keine Ternär-Operatoren innerhalb von String-Interpolationen** (`"\(a ?? "")"`) – vorher in eine Hilfseigenschaft auslagern oder mit `+` verketten. Lange Modifier-Ketten (viele `.alert`/`.sheet`) auf Hilfsfunktionen verteilen. |
| Ternär mit impliziten Membern in generischen Parametern (`.foregroundStyle(x ? .secondary : .primary)`) | Typ ausschreiben: `x ? Color.secondary : Color.primary`. |
| Überladene Funktionsreferenzen (`.map(Format.set)`) | Closure schreiben: `.map { Format.set($0) }`. |
| Tupel in `ForEach`/`Chart` mit Keypath-IDs | Kleine `Identifiable`-Structs verwenden. |
| `NavigationLink` innerhalb eines `Menu` | Funktioniert nicht zuverlässig. Stattdessen `Button` plus `.navigationDestination(isPresented:)`. |
| Mehrere Buttons in einer List-Zeile lösen gemeinsam aus | Jedem Button `.buttonStyle(.borderless)` oder `.plain` geben. |
| `@MainActor`-Funktionen aus nicht isolierten Closures (`DispatchQueue.main.async`) | `Task { @MainActor in … }` verwenden. Services, die nur `ModelContext` brauchen, nicht mit `@MainActor` markieren. |
| Swift-Code in Python-Heredocs per Bash bearbeiten | `\(` und `$` werden leicht zerschossen. Größere Änderungen lieber per Write/Edit oder mit einem Python-Skript als **Datei** im Scratchpad. Sehr lange Heredocs brechen in der Bash ab. Manche Dateien (z. B. die Workflow-YAML) haben CRLF-Zeilenenden, dann findet ein Textersatz nichts – im Zweifel die Datei komplett neu schreiben. |
| `let items = items(of: …)` (lokale Konstante heißt wie die aufgerufene Methode) | Fehler „variable used within its own initial value“. Lokale Konstante anders benennen. |
| Modifier (`.onChange`, `.sheet`, `.onAppear`) direkt an einer `Section` in einer `List`/`Form` | SwiftUI wendet sie auf **jede Zeile** an, der Code läuft dann mehrfach. An eine bestimmte Zeile hängen oder in eine eigene Zeilen-View auslagern. |
| `GridRow` in einer eigenen View-Struktur | Wird vom `Grid` womöglich nicht als Zeile erkannt. `GridRow` direkt im `Grid` schreiben. |
| Neuer Fall in einem Enum (z. B. `Tracker`, `SetField`) | Alle `switch`-Anweisungen im Projekt per Grep suchen und ergänzen, sonst „switch must be exhaustive“. |
| APIs nur ab iOS 18/26 in `@State` oder Eigenschaften | Nicht direkt typisieren (Mindestversion 17). Als `AnyObject?` halten und im `if #available`-Block casten (Muster aus PureGym `AICoach.makeChatSession`). |
| `@State var x = EinSingleton.shared` (Singleton ist `@MainActor`) | Als berechnete Eigenschaft schreiben: `private var x: Typ { Typ.shared }`. `@Observable` verfolgt Änderungen trotzdem. |
| `@AppStorage(Typ.key)`, wobei `Typ` `@MainActor` ist | Schlüssel als `nonisolated static let key = "…"` deklarieren (Property-Wrapper-Argumente sind nicht isoliert). |
| `guard let x = x(…)` bzw. `let x = x(…)` | Wie oben „Selbstreferenz“; `if let x = x(…)` ist dagegen erlaubt. `lint.py` findet das. |
| `@ObservationIgnored` an `let` | Weglassen; nur an `var`. |
| **View-Statics** als Argument oder Startwert eines Property-Wrappers (`@AppStorage(MeineView.key)`, `@State var x = MeineView.standard`) | Views sind seit dem iOS-18-SDK `@MainActor` – deren Statics auch. Schlüssel nach `AppSettings.Key`, Startwerte als Literal (R01). |
| Regex mit `\s`, `\d` in normalem Swift-String | Ungültiges Escape → Compilerfehler. Raw-String verwenden: `#"apikey=[^&\s"]*"#` (R01). |
| Mehrzeiliger Getter nach Einfügen einer Zeile | Implizites `return` gilt nur bei **einem** Ausdruck – nach `_ = x` muss `return` davor (R01). |
| APIs aus einem neueren SDK (z. B. `MKReverseGeocodingRequest`, iOS 26) | `#available` reicht nur bei passendem SDK; zusätzlich `#if compiler(>=6.2)`, damit ein älteres Xcode in der CI weiter baut (R01). |
| `"\r\n"` in Swift ist **ein** `Character` | Beim Zeilen-Parsen `Character.isNewline` statt Vergleich mit `"\n"` verwenden (CSV aus Windows/Excel). |
| Timer-Text (`Text(date, style: .timer)`) in Widgets/Live Activities | Nimmt sonst die ganze Zeilenbreite ein: feste Breite per `.frame(width:alignment:)`. Nach Ablauf eines Datums zählt `.timer` automatisch wieder hoch; mit `staleDate` lässt sich die Darstellung (z. B. „+“) umschalten. |
| `.fullScreenCover(isPresented: Binding(get: { Singleton.shared.x }, …))` – nichts erscheint (AK-34) | Der Getter einer Bindung läuft nicht im `body`, die Ansicht beobachtet `x` dann nicht. Den Wert im `body` lesen und als Wert weitergeben (`TourPresentationHost(isShown: tour.isPresented)`). |
| `ScrollViewReader.scrollTo(id)` in `List`/`Form` erreicht Zeilen weiter unten nicht (AK-34) | Listen kennen nur gezeichnete Zeilen. Die vorderste `UIScrollView` schrittweise scrollen, bis die Stelle erscheint (`TourScroller`). |
| `sheet(item:)` meldet „requires that 'Exercise' conform to 'Identifiable'“, obwohl jedes `@Model` es ist (AK-43, nach einem neuen Feld der Übung) | Fehldiagnose in einer sehr langen Modifier-Kette: den Modifier in einen eigenen `ViewModifier` auslagern (`ExerciseDetailSheet` in `WorkoutSessionView`). |
| `.navigationDestination(isPresented:)` an einer `List`, Ziel ist eine Seite mit `@AppStorage`-Änderungen beim Erscheinen – App hängt, Ziel zeichnet sich endlos neu (AK-36) | Ziele mit Wert öffnen: `NavigationStack(path:)` plus `.navigationDestination(for: Ziel.self)` und `path.append(…)`; beim Erscheinen keine gespeicherten Werte schreiben, Startwerte als `@State` im `init` setzen. |
| In `NavigationStack(path:)` eine Seite per `NavigationLink { Ziel }` öffnen und darauf `NavigationLink(value:)` antippen – die neue Seite landet **unter** der alten, man muss mehrmals zurück (AK-38) | Im selben Stapel entweder nur Werte (`NavigationLink(value:)` + ein `navigationDestination(for:)`, z. B. `AnalysisRoute`) oder Wert-Links nur auf der Wurzelseite. Wege, die im Kreis führen (Station → Katalog → Station), führen zurück (`dismiss()`) statt neu zu öffnen. |

**Nach jeder größeren Änderung** selbst per Grep nach diesen Mustern suchen, bevor committet wird.
