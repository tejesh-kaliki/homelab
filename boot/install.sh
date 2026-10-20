#!/usr/bin/env bash
# Install (or reinstall) the launchd agent that runs homelab-boot.sh at login.
# Paths are filled in from wherever this repo is checked out.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL="homelab.boot"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/homelab-boot.log"

mkdir -p "$(dirname "$PLIST")" "$(dirname "$LOG")"
sed -e "s|@SCRIPT@|$DIR/homelab-boot.sh|" -e "s|@LOG@|$LOG|" \
  "$DIR/$LABEL.plist.template" > "$PLIST"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed $PLIST (logs: $LOG)"
