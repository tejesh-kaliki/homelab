#!/usr/bin/env bash
# Install (or reinstall) the launchd agent that runs backup.sh daily at 03:30.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL="homelab.backup"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/homelab-backup.log"

mkdir -p "$(dirname "$PLIST")" "$(dirname "$LOG")"
sed -e "s|@SCRIPT@|$DIR/../backup.sh|" -e "s|@LOG@|$LOG|" \
  "$DIR/$LABEL.plist.template" > "$PLIST"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed $PLIST (logs: $LOG)"
