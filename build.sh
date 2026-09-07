#!/bin/bash
# Builds MediaKeyJack.app as a universal binary and packs it for a release.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/build"
APP="$OUT/MediaKeyJack.app"

rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS"

swiftc -O -target arm64-apple-macos13  -o "$OUT/arm64"  "$HERE/MediaKeyJack.swift"
swiftc -O -target x86_64-apple-macos13 -o "$OUT/x86_64" "$HERE/MediaKeyJack.swift"
lipo -create -output "$APP/Contents/MacOS/MediaKeyJack" "$OUT/arm64" "$OUT/x86_64"
rm -f "$OUT/arm64" "$OUT/x86_64"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>              <string>MediaKeyJack</string>
    <key>CFBundleExecutable</key>        <string>MediaKeyJack</string>
    <key>CFBundleIdentifier</key>        <string>io.github.roccccky.mediakeyjack</string>
    <key>CFBundleVersion</key>           <string>1.0.0</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>LSMinimumSystemVersion</key>    <string>13.0</string>
    <key>LSUIElement</key>               <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>MediaKeyJack controls Spotify with your keyboard's media keys.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
tar -czf "$OUT/MediaKeyJack.tar.gz" -C "$OUT" MediaKeyJack.app
echo "built $OUT/MediaKeyJack.tar.gz"
lipo -archs "$APP/Contents/MacOS/MediaKeyJack"
