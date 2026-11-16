#!/bin/bash
# Installs or updates the launchd agent that keeps the app installed on the devices.
# Usage: setup-auto-reinstall.sh <device-id>[,<device-id>...]
# The agent runs every 30 minutes from 08:00 to 22:30, so a device that was locked or away at one
# run is tried again soon. It never runs at 23:00, when another project's build agent runs.
# Remove: launchctl bootout gui/$(id -u)/com.sameetasadullah.stremio.reinstall
#         rm ~/Library/LaunchAgents/com.sameetasadullah.stremio.reinstall.plist
set -euo pipefail

DEVICE="${1:?usage: setup-auto-reinstall.sh <device-id>[,<device-id>...]}"
LABEL="com.sameetasadullah.stremio.reinstall"
BASE="$HOME/Library/Application Support/stremio-ios"
SCRIPT="$BASE/install-on-iphone.sh"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$BASE" "$HOME/Library/LaunchAgents"
install -m 755 "$(dirname "$0")/install-on-iphone.sh" "$SCRIPT"

times=""
for hour in $(seq 8 22); do
    for minute in 0 30; do
        times+="        <dict><key>Hour</key><integer>$hour</integer><key>Minute</key><integer>$minute</integer></dict>
"
    done
done

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT</string>
        <string>$DEVICE</string>
        <string>2</string>
    </array>
    <key>StartCalendarInterval</key>
    <array>
$times    </array>
    <key>StandardOutPath</key>
    <string>$BASE/reinstall.log</string>
    <key>StandardErrorPath</key>
    <string>$BASE/reinstall.log</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Agent $LABEL runs every 30 minutes from 08:00 to 22:30 and reinstalls on each device that can be reached and whose build has 2 days or less left."
