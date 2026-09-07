#!/bin/bash
# Downloads the latest MediaKeyJack and starts it.
set -euo pipefail

URL="https://github.com/Roccccky/mediakeyjack/releases/latest/download/MediaKeyJack.tar.gz"
LABEL="io.github.roccccky.mediakeyjack"
APP="$HOME/Applications/MediaKeyJack.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
UID_NUM="$(id -u)"

launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "$URL" -o "$TMP/MediaKeyJack.tar.gz"

mkdir -p "$HOME/Applications"
rm -rf "$APP"
tar -xzf "$TMP/MediaKeyJack.tar.gz" -C "$HOME/Applications"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>            <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array><string>$APP/Contents/MacOS/MediaKeyJack</string></array>
    <key>RunAtLoad</key>        <true/>
    <key>KeepAlive</key>        <true/>
    <key>ThrottleInterval</key> <integer>5</integer>
    <key>ProcessType</key>      <string>Interactive</string>
    <key>StandardErrorPath</key><string>$HOME/Library/Logs/MediaKeyJack.log</string>
</dict>
</plist>
PLIST_EOF

launchctl bootstrap "gui/$UID_NUM" "$PLIST"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true

echo
echo "MediaKeyJack is installed and starts at login."
echo "Switch it on in the window that just opened, under Accessibility."
