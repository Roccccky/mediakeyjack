#!/bin/bash
# Removes MediaKeyJack.
set -euo pipefail
LABEL="io.github.roccccky.mediakeyjack"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Applications/MediaKeyJack.app"
rm -f "$HOME/Library/Logs/MediaKeyJack.log"
echo "MediaKeyJack removed. Its leftover entry under Accessibility can be deleted by hand."
