#!/bin/bash
# Builds the itch.io uploads into dist/:
#   dist/LeapLine-web.zip     HTML5 build (QBJS), for "This file will be played in the browser"
#   dist/LeapLine-mac.zip     Leap Line.app (macOS, this Mac's architecture)
#   dist/LeapLine-linux.zip   when run on Linux
# and draws the store art into itch/art (cover, banner, icon).
#
# Usage: tools/release.sh [version]      (run from anywhere)
# Needs QB64-PE (QB64PE=..., default ~/git/QB64pe) and a QBJS checkout
# (QBJS=..., default ~/git/qbjs) with node installed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QB64PE="${QB64PE:-$HOME/git/QB64pe}"
QBJS="${QBJS:-$HOME/git/qbjs}"
VERSION="${1:-1.0}"
DIST="$ROOT/dist"
BUILD="$DIST/build"

rm -rf "$DIST"
ART="$ROOT/itch/art"
mkdir -p "$BUILD" "$ART"

qb64() { # source, output
    (cd "$QB64PE" && ./qb64pe -x "$1" -o "$2" > "$BUILD/qb64pe.log" 2>&1) || {
        cat "$BUILD/qb64pe.log"; exit 1; }
}

echo "== store art"
qb64 "$ROOT/tools/art.bas" "$BUILD/art"
"$BUILD/art" "$ART"

echo "== game"
# every build ships the committed sfx/ WAVs, so the game never has to spend
# its first launch generating them
qb64 "$ROOT/mrJumpS.bas" "$BUILD/LeapLine"

echo "== web (QBJS)"
WEB="$BUILD/web"
mkdir -p "$WEB/sfx"
(cd "$QBJS" && node qbc.js "$ROOT/mrJumpS.bas" "$WEB/program.js") | tee "$BUILD/qbjs.log"
if grep -q "^ERROR" "$BUILD/qbjs.log"; then echo "QBJS compile failed"; exit 1; fi
# the same files the QBJS IDE puts in an exported program (export/dependencies.txt)
while IFS=, read -r src dst || [ -n "$src" ]; do
    src="${src//\"/}"; dst="$(echo "${dst//\"/}" | xargs)"
    mkdir -p "$WEB/$(dirname "$dst")"
    cp "$QBJS/$src" "$WEB/$dst"
done < "$QBJS/export/dependencies.txt"
sed "s|<head>|<head>\n        <title>Leap Line</title>|" "$QBJS/export/play.html" > "$WEB/index.html"
cp "$ROOT"/sfx/*.wav "$WEB/sfx/"
(cd "$WEB" && zip -qr "$DIST/LeapLine-web.zip" .)

case "$(uname)" in
Darwin)
    echo "== macOS app"
    APP="$BUILD/Leap Line.app"
    mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
    cp "$BUILD/LeapLine" "$APP/Contents/MacOS/LeapLine"
    cp -R "$ROOT/sfx" "$APP/Contents/Resources/sfx"
    ICONSET="$BUILD/LeapLine.iconset"
    mkdir -p "$ICONSET"
    for s in 16 32 128 256 512; do
        sips -z $s $s "$ART/icon.png" --out "$ICONSET/icon_${s}x${s}.png" > /dev/null
        sips -z $((s * 2)) $((s * 2)) "$ART/icon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" > /dev/null
    done
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/LeapLine.icns"
    cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Leap Line</string>
    <key>CFBundleDisplayName</key><string>Leap Line</string>
    <key>CFBundleIdentifier</key><string>io.itch.leapline</string>
    <key>CFBundleExecutable</key><string>LeapLine</string>
    <key>CFBundleIconFile</key><string>LeapLine</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>11.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.arcade-games</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF
    # ad-hoc signature: not notarized, so players right-click > Open the first time
    codesign --force --deep -s - "$APP"
    (cd "$BUILD" && ditto -c -k --keepParent "Leap Line.app" "$DIST/LeapLine-mac.zip")
    ;;
Linux)
    echo "== Linux"
    L="$BUILD/LeapLine-linux"
    mkdir -p "$L"
    cp "$BUILD/LeapLine" "$L/"
    cp -R "$ROOT/sfx" "$L/sfx"
    (cd "$BUILD" && zip -qr "$DIST/LeapLine-linux.zip" LeapLine-linux)
    ;;
esac

echo
ls -lh "$DIST"/*.zip "$ART"/*.png
