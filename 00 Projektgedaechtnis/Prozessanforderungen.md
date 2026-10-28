# Prozessanforderungen (Regeln der Arbeitsweise)

> Master-Datei für Regeln. IDs `M-Xnn` werden nie neu vergeben; geänderte Regeln bekommen einen Vermerk „geändert in Rnn“.
> Stand: 2026-10-28 19:05 (R01). Übernommen aus LeanGymLog (über den Stand von Mileage Log) auf Riccos Auftrag und auf OP Calc angepasst.

## A · Arbeitsweise
| ID | Regel |
|---|---|
| M-A01 | Das Gedächtnis liegt in Dateien, nicht im Chat. Was bleiben soll, steht im Projektordner. |
| M-A02 | Jeder Chat ist eine Runde `Rnn` mit Protokoll, PDCA und Übergabeblock (Vorlage: `Vorlagen/Rnn_Protokoll_Vorlage.md`). |
| M-A03 | Gestuftes Laden L0–L3 (siehe `00_START_HIER.md` §4). Zu Beginn die Ladetiefe in einer Zeile nennen. |
| M-A04 | Kleine, überprüfbare Schritte. Bei unklaren Designfragen erst Varianten `Vn` erzeugen und bewerten, nicht per Bauchgefühl festlegen. |
| M-A05 | Rückfragen als Multiple Choice mit markierter Empfehlung. Echte Zielkonflikte vorher fragen, sonst mit sinnvollen Standardwerten arbeiten und das im Protokoll nennen. |
| M-A06 | Sprache: Deutsch, per Du. Schritte für Ricco konkret und nummeriert; Befehle als einzelne `bash`-Blöcke. |
| M-A07 | Ehrlich berichten: Was geprüft wurde, was nicht (z. B. „nicht kompiliert“, „nicht auf dem Gerät getestet“). |

## G · Gedächtnis
| ID | Regel |
|---|---|
| M-G01 | Single Source of Truth: jede Informationsart genau eine Master-Datei (`00_START_HIER.md` §7). Verweise per ID statt Kopie. |
| M-G02 | `Projektstatus.md` ≤ 80 Zeilen, zum Rundenabschluss neu schreiben und im Claude-Projekt spiegeln. |
| M-G03 | Vor dem Überschreiben einer Datei prüfen, ob sie seit dem Lesen geändert wurde. Nie blind überschreiben. |
| M-G04 | Tabellen als Markdown/CSV im Repo, kein Excel (binär, nicht mergebar). |
| M-G05 | Speicherfilter: nur, was eine Folgerunde braucht (siehe `00_START_HIER.md` §5). |
| M-G06 | **Zeitstempel:** Jede Notiz im Projektgedächtnis (Protokolleintrag, Ergebnisblock, neue oder geänderte Cockpit-Zeile, „Stand“-Zeile, Übergabeblock) trägt Datum und Uhrzeit im Format `JJJJ-MM-TT HH:MM` (Ortszeit Europe/Berlin), per `date` abgefragt, nicht geschätzt. Bei Widersprüchen gilt der jüngere Eintrag. Ältere Einträge werden nicht nachdatiert. (übernommen 2026-10-28 19:05 aus LeanGymLog auf Riccos Auftrag) |
| M-G07 | **Ein Projektordner:** Gearbeitet wird nur in `A:\Dev\OP Calc` (Windows) bzw. der Arbeitskopie am Mac, Abgleich über GitHub, nur an einem Rechner gleichzeitig – vor jedem Wechsel commit + push, am anderen `git pull --ff-only`. Keine Git-Worktrees, auch nicht für parallele Chats oder wenn eine Karte es vorschlägt; parallele Stränge trennen sich über Pfade. Nie `git add -A`/`git add .`, nur eigene Pfade einzeln hinzufügen. (übernommen 2026-10-28 19:05 aus LeanGymLog auf Riccos Auftrag) |

## E · Evidenz
| ID | Regel |
|---|---|
| M-E01 | Mathematische Aussagen (exakte Werte, Rechenregeln, Grenzen) mit Beleg oder Test; Zahlenangaben im Store-Text mit Quelle (`L-Key`). |
| M-E02 | Quellenhierarchie: Q1 Norm (IEEE 754, ISO 80000-2), Plattform-Richtlinie · Q2 Fachbuch · Q3 Herstellerdoku (Apple) · Q4 Blog/Forum (nur Hinweis). |
| M-E03 | Kein Beleg → Annahme `A-nnn` mit Wert, Begründung, Prüfplan, Status; bleibt im Text sichtbar. |
| M-E04 | Fehlt eine Unterlage, konkret nennen: Titel, Bezugsweg, Grund. Ricco beschafft. |
| M-E05 | Neue Quellen prüfen, ob es wirklich die gemeinte ist (Version, Jahr, API-Stand). |
| M-E06 | In der App: Näherungen immer mit „≈“ kennzeichnen; exakt heißt exakt. |

## D · Entscheidungen
| ID | Regel |
|---|---|
| M-D01 | Die KI legt eine Entscheidungsvorlage vor (Optionen, Vor- und Nachteile, Empfehlung mit Begründung). Ricco entscheidet. |
| M-D02 | Jede Entscheidung als `E-nnn`: Thema · Entscheidung · Alternativen · Begründung/Quellen · entschieden durch · Status (ggf. „abgelöst durch E-mmm“). |
| M-D03 | Nutzwertanalyse bei ≥ 3 Varianten: nur robust unterscheidende Kriterien, Korrelation prüfen, absolute Wertfunktion 0–4, Sensitivität prüfen, Grenze der Aussage nennen. |
| M-D04 | Übernommene Anforderungen ohne Beleg hinterfragen und ggf. neu formulieren. |
| M-D05 | **Entscheidungsseiten nur mit neuen Fragen:** Eine Entscheidungsseite zeigt nur Fragen, die jetzt zu entscheiden sind. Beantwortete oder überholte Fragen werden vor dem Veröffentlichen entfernt; ist eine frühere Frage wieder offen, wird sie neu gestellt. (übernommen 2026-10-28 19:05 aus LeanGymLog auf Riccos Auftrag) |

## C · Code und Build
| ID | Regel |
|---|---|
| M-C01 | Programmieraufgaben > ca. 150 Zeilen gehen per Aufgabenkarte `AK-nn` an Claude Code. Claude Code startet im Plan-Modus und stellt die Fragen aus Abschnitt 7 der Karte. |
| M-C02 | **Claude Code pflegt das Gedächtnis mit** (übernommen 2026-10-28 19:05 aus LeanGymLog auf Riccos Auftrag, dort E-086): Claude Code trägt seine Ergebnisse selbst ein – Ergebnisblock, Rundenprotokoll, offene Punkte, PDCA, Projektstatus und Entscheidungen, die Ricco im Chat getroffen hat (mit Zitat und Zeitstempel). Vorher `git pull --ff-only`, nie blind überschreiben (M-G03), eine Master-Datei je Information (M-G01). Entscheidungen von Tragweite bleiben bei Ricco. *(Bis 2026-10-28: Claude Code bearbeitete keine Gedächtnis-Dateien.)* |
| M-C03 | Jede Karte nennt die Entscheidung, die das Ergebnis stützen soll, und prüft, ob die Grundlagen dafür enthalten sind (PM-04). |
| M-C04 | Nachweisart je Kennwert im Ergebnisblock (Verifikation / Test / validiert mit echten Daten) (PM-05). |
| M-C05 | **Build lokal am Mac** (übernommen 2026-10-28 19:05 aus LeanGymLog auf Riccos Auftrag, dort E-072/E-073): `bash "03 Code/tools/mac/mac_build.sh" alles`, aufs iPhone per Kabel mit `signiert`. GitHub Actions nur noch auf Riccos ausdrückliche Ansage. Am Windows-Rechner wird nicht kompiliert – dort vor jedem Commit `lint.py --since HEAD` und nach den Stolpersteinen aus `03 Code/ENTWICKLUNGSLEITFADEN.md` §6 suchen, große Änderungen zusätzlich per Review-Agent gegen die Deklarationen prüfen; gebaut wird beim nächsten Mac-Termin. Builds bündeln: erst alles fertig schreiben, dann bauen. |
| M-C06 | Rechenkern (BigInt, Rational, ExactValue, Auswertung) mit XCTest absichern (`OPCalcTests/`); neue Regeln bekommen einen Test. Einmal-Nachbauten in Python ins Scratchpad. |
| M-C07 | SwiftData: jede gespeicherte Eigenschaft mit Standardwert oder optional; Beziehungen erst nach `insert`; nie umbenennen ohne Migrationsplan (Leitfaden §5). |
| M-C08 | Laufzeitfehler sichtbar machen statt abstürzen (Fehlermeldung im Ergebnisfeld, kein `fatalError` im Rechenpfad). |
| M-C09 | Keine externen Pakete. Keine Werbung, kein Tracking, keine Analytics. |
| M-C10 | Grenzwerte (Stellenzahl, Fakultät, Rekursionstiefe) als benannte Konstanten mit kurzem Warum-Kommentar. |
| M-C11 | **Texte in der App:** Jeder sichtbare Text wird aus Sicht des Endnutzers geschrieben. (1) Klare Aussage, kurz und konkret. (2) Klingt nicht nach KI: keine Füllsätze, keine Vorteils-Aufzählungen, keine Gedankenstrich-Ketten, keine Wörter wie „basierend auf“, „optimal“, „ganzheitlich“. (3) Kein Insiderwissen: keine Begriffe oder Kürzel aus der Entwicklung. (4) Nicht überladen. (5) Gleicher Ton und gleiche Begriffe wie an den Nachbarstellen. (6) Keine Quellenangaben im Text. (7) Keine Einzelfreigabe: nach diesen Regeln schreiben, einbauen und im Bericht nennen; Ricco meldet sich, wenn etwas nicht passt. (übernommen 2026-10-28 19:05 aus LeanGymLog auf Riccos Auftrag, dort M-C11/E-075) |
| M-C12 | **Einführung mitziehen:** Ändert eine Karte Oberfläche, Abläufe oder Begriffe, die die Einführung (Onboarding) zeigt, wird die Einführung in derselben Karte angepasst und im Simulator geprüft. (übernommen 2026-10-28 19:05 aus LeanGymLog auf Riccos Auftrag) |

## R · Recht, Datenschutz
| ID | Regel |
|---|---|
| M-R01 | Release-Anforderungen mit Primärquelle belegen, bevor gebaut wird. |
| M-R02 | Datenschutz: alles lokal, keine Netzwerkzugriffe, kein Konto. |
| M-R03 | Keine Marken Dritter im App-Namen oder Store-Text. |

## T · Tests
| ID | Regel |
|---|---|
| M-T01 | Verifikation: Build am Mac grün, XCTest grün (`mac_build.sh tests`). Validierung: Rechnen auf Riccos iPhone. |
| M-T02 | Jede Etappe bringt eine Geräte-Testliste (`05 Tests/`), Ricco hakt ab, Befunde werden `OP-nnn`. |
| M-T03 | **Gerätetests kurz:** höchstens etwa fünf Punkte, nur was sich im Simulator nicht klären lässt (Ortung, Mitteilungen, Sperrbildschirm, echte Daten, Kamera). Alles andere prüft Claude Code im Simulator und legt Bildschirmfotos ab. Jeder Punkt als Ja/Nein-Frage. Vor dem Installieren an „Einstellungen → Sicherung“ erinnern. (übernommen 2026-10-28 19:05 aus LeanGymLog auf Riccos Auftrag, dort M-T03) |

## Git
| ID | Regel |
|---|---|
| M-X01 | Commit je Runde `Rnn: <Kurztitel>`; Claude Code je Karte `AK-nn: <Kurztitel>` (eigener Zweig, Merge nach `main`). |
| M-X02 | Nie parallel an zwei Orten arbeiten; vor Cloud-Sitzung pushen, danach pullen. |
| M-X03 | Nicht versionieren: Build-Ordner, Sperrdateien, `*.xcresult`. |
