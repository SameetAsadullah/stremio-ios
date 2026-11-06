#!/bin/bash
# Builds origin/main from a separate clean checkout and installs it over the app on the device.
# Usage: install-on-iphone.sh <device-id> [days-left]
# With days-left, it skips while the installed build has more than that many days left.
# The launchd agent runs a copy in ~/Library/Application Support/stremio-ios, because launchd jobs
# cannot read ~/Documents without a privacy prompt. Run scripts/setup-auto-reinstall.sh after a change.
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

DEVICE="${1:?usage: install-on-iphone.sh <device-id> [days-left]}"
DAYS_LEFT="${2:-0}"
BUNDLE_ID="com.sameetasadullah.stremio"
REPO_URL="https://github.com/SameetAsadullah/stremio-ios.git"
BASE="$HOME/Library/Application Support/stremio-ios"
CHECKOUT="$BASE/checkout"
DERIVED="$BASE/DerivedData"
APP="$DERIVED/Build/Products/Debug-iphoneos/Stremio.app"
# Expiry of the installed build's provisioning profile, in seconds since 1970.
EXPIRES="$BASE/expires"
PROFILES="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"

log() { echo "$(date '+%F %T') $1"; }
notify() { osascript -e "display notification \"$1\" with title \"Stremio reinstall\"" >/dev/null 2>&1 || true; }
fail() { log "FAILED: $1"; notify "Failed: $1"; exit 1; }
profile_field() { security cms -D -i "$1" 2>/dev/null | plutil -extract "$2" raw -o - - 2>/dev/null; }

if (( DAYS_LEFT > 0 )) && [[ -f "$EXPIRES" ]]; then
    hours_left=$(( ($(cat "$EXPIRES") - $(date +%s)) / 3600 ))
    if (( hours_left > DAYS_LEFT * 24 )); then
        log "installed build expires in $(( hours_left / 24 )) days, skipped"
        exit 0
    fi
fi

log "start"
xcodebuild -checkFirstLaunchStatus || fail "Xcode needs its update to finish. Open Xcode once."

mkdir -p "$BASE"
[[ -d "$CHECKOUT/.git" ]] || git clone -q "$REPO_URL" "$CHECKOUT" || fail "git clone"
git -C "$CHECKOUT" fetch -q origin main || fail "git fetch"
git -C "$CHECKOUT" reset -q --hard origin/main
# Frameworks/ holds 1.3 GB of downloads. Keep it, and let bootstrap.sh fetch only what is missing.
git -C "$CHECKOUT" clean -qfdx -e Frameworks/
commit=$(git -C "$CHECKOUT" rev-parse --short HEAD)
"$CHECKOUT/scripts/bootstrap.sh" || fail "framework download"

# A free profile lasts 7 days from its creation and Xcode reuses it until then.
# Removing the cached one makes Xcode fetch a new profile, so each install gets 7 full days.
for profile in "$PROFILES"/*.mobileprovision; do
    [[ -f "$profile" ]] || continue
    [[ "$(profile_field "$profile" Name)" == "iOS Team Provisioning Profile: $BUNDLE_ID" ]] && rm -f "$profile"
done

(cd "$CHECKOUT" && xcodegen generate --quiet) || fail "xcodegen"
xcodebuild -project "$CHECKOUT/Stremio.xcodeproj" -scheme Stremio -configuration Debug \
    -destination "generic/platform=iOS" -derivedDataPath "$DERIVED" -allowProvisioningUpdates -quiet build \
    || fail "build of $commit. Check the Apple ID in Xcode → Settings → Accounts."
xcrun devicectl device install app --device "$DEVICE" "$APP" \
    || fail "install. Is the device on the same Wi-Fi and unlocked?"

expiry=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$(profile_field "$APP/embedded.mobileprovision" ExpirationDate)" +%s) \
    || fail "could not read the profile expiry of $commit"
echo "$expiry" > "$EXPIRES"
until_text=$(date -r "$expiry" '+%-d %b %H:%M')
log "installed $commit, runs until $until_text"
notify "Installed $commit. It runs until $until_text."
