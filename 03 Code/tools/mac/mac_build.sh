#!/bin/bash
# Lokaler Build am Mac – Vorbild LeanGymLog (AK-26, E-073), auf dieses Projekt gekürzt.
# Aufruf im Projektordner:  bash "03 Code/tools/mac/mac_build.sh" <schritt> [<schritt> …]
# Schritte: pruefen | sim | tests | geraet | signiert | alles  (alles = pruefen sim tests geraet)
# signiert = signierter Build fürs iPhone per Kabel:  APP_GERAET=<Kennung> bash … signiert
#            baut und prüft nur; installiert wird erst mit APP_INSTALLIEREN=ja (vorher Sicherung in der App!).
# Team-ID liegt außerhalb des Repos, geteilt mit LeanGymLog (E-076 dort): ~/.leangymlog-team-id
# Logs: build/logs/<schritt>.log (build/ ist in .gitignore). Startet NIE einen GitHub-Lauf.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1
mkdir -p build/logs

PROJEKT=OPCalc          # Xcode-Projekt ohne .xcodeproj
ZIEL=OPCalc                # App-Target und Schema
BUNDLE=com.opcalc.app            # Bundle-ID der App (zum Starten nach dem Installieren)
ERWEITERUNG=""  # eingebettete Erweiterung (.appex) oder leer
TESTS=OPCalcTests              # XCTest-Target oder leer
FLAGS='$(inherited) -Xfrontend -warn-long-expression-type-checking=400 -Xfrontend -warn-long-function-bodies=800'

fehler() {  # Fehlerzeilen eines Logs kurz zeigen (Datei:Zeile: error: …), höchstens 40
  grep -E ': (error|fatal error):' "$1" | sort -u | head -n 40
}

lauf() {  # lauf <name> <befehl…>: Befehl ausführen, Log schreiben, Ergebnis melden
  local NAME="$1"; shift
  echo "▶ $NAME …"
  if "$@" > "build/logs/$NAME.log" 2>&1; then
    echo "✔ $NAME grün (Log: build/logs/$NAME.log)"
    return 0
  fi
  echo "✘ $NAME ROT (Log: build/logs/$NAME.log)"
  fehler "build/logs/$NAME.log"
  return 1
}

schritt_pruefen() {
  xcodebuild -version || { echo "Xcode fehlt"; return 1; }
  echo "Zweig: $(git branch --show-current) · Kopf: $(git log -1 --format='%h %s')"
  git status --short | head -n 20
  git ls-files -z "*.swift" | xargs -0 python3 "03 Code/tools/lint.py" || return 1
  [ ! -f "03 Code/tools/pbx_check.py" ] || python3 "03 Code/tools/pbx_check.py" || return 1
}

schritt_sim() {
  lauf sim xcodebuild -project "$PROJEKT.xcodeproj" -target "$ZIEL" -sdk iphonesimulator -configuration Debug \
    CODE_SIGNING_ALLOWED=NO "OTHER_SWIFT_FLAGS=$FLAGS" build
  local STATUS=$?
  # Langsame Ausdrücke früh sehen – sie werden sonst irgendwann zu „unable to type-check“ (Leitfaden §6)
  grep -E 'warning: (expression|instance method|global function|getter).*took [0-9]+ms' build/logs/sim.log | sort -u | head -n 10
  return $STATUS
}

schritt_tests() {
  [ -n "$TESTS" ] || { echo "– keine Tests in diesem Projekt"; return 0; }
  local SIM="${APP_TEST_SIM:-iPhone 17}"
  lauf tests xcodebuild test -project "$PROJEKT.xcodeproj" -scheme "$ZIEL" -configuration Debug \
    -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath build/dd-tests CODE_SIGNING_ALLOWED=NO
  local STATUS=$?
  grep -E "^Test case .* failed|Executed [0-9]+ tests" build/logs/tests.log | sort -u | tail -n 30
  return $STATUS
}

schritt_geraet() {  # unsignierter Release-Build fürs iPhone – zeigt, ob der Gerätebuild durchgeht
  lauf geraet xcodebuild -project "$PROJEKT.xcodeproj" -target "$ZIEL" -sdk iphoneos -configuration Release \
    SYMROOT="$PWD/build" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build || return 1
  [ -z "$ERWEITERUNG" ] || [ -d "build/Release-iphoneos/$ZIEL.app/PlugIns/$ERWEITERUNG.appex" ] \
    || { echo "✘ $ERWEITERUNG fehlt in der App"; return 1; }
}

schritt_signiert() {
  local TEAM_FILE="$HOME/.leangymlog-team-id" GERAET="${APP_GERAET:-}"
  [ -s "$TEAM_FILE" ] || { echo "✘ Team-ID fehlt: $TEAM_FILE"; return 1; }
  if [ -z "$GERAET" ]; then
    echo "Gerät wählen: APP_GERAET=<Kennung> setzen. Verbundene Geräte:"
    xcrun devicectl list devices
    return 1
  fi
  lauf signiert xcodebuild -project "$PROJEKT.xcodeproj" -scheme "$ZIEL" -configuration Release \
    -destination "id=$GERAET" -derivedDataPath build/dd-geraet \
    DEVELOPMENT_TEAM="$(cat "$TEAM_FILE")" CODE_SIGN_STYLE=Automatic \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration build || return 1
  local APP="build/dd-geraet/Build/Products/Release-iphoneos/$ZIEL.app"
  [ -z "$ERWEITERUNG" ] || [ -d "$APP/PlugIns/$ERWEITERUNG.appex" ] || { echo "✘ $ERWEITERUNG fehlt in der App"; return 1; }
  echo "Version $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist") ($(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist")) · Größe $(du -sh "$APP" | cut -f1)"
  if [ "${APP_INSTALLIEREN:-}" != "ja" ]; then
    echo "Gebaut, nicht installiert. Hat die App schon echte Daten: erst in der App sichern,"
    echo "dann mit APP_INSTALLIEREN=ja erneut aufrufen."
    return 0
  fi
  xcrun devicectl device install app --device "$GERAET" "$APP" || return 1
  xcrun devicectl device process launch --device "$GERAET" --terminate-existing "$BUNDLE"
}

[ $# -gt 0 ] || { sed -n '2,7p' "$0"; exit 1; }
STATUS=0
for S in "$@"; do
  case "$S" in
    alles) for T in pruefen sim tests geraet; do "schritt_$T" || STATUS=1; done ;;
    pruefen|sim|tests|geraet|signiert) "schritt_$S" || STATUS=1 ;;
    *) echo "Unbekannter Schritt: $S"; STATUS=1 ;;
  esac
done
exit $STATUS
