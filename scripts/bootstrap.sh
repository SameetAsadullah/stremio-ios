#!/usr/bin/env bash
# Downloads the two prebuilt frameworks into Frameworks/ (gitignored, about 1.4 GB unpacked).
# Skips a framework that is already there. Safe to run again.
# Frameworks:
#   - MobileVLCKit.xcframework (VideoLAN) — native player
#   - NodeMobile.xcframework (nodejs-mobile) — runs Stremio's server.js on-device
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p Frameworks && cd Frameworks

# Checksums recorded from the official downloads on 2026-11-06. Neither project publishes one.
verify() { echo "$1  $2" | shasum -a 256 -c - >/dev/null || { echo "Checksum mismatch: $2" >&2; rm -f "$2"; exit 1; }; }

VLC="3.7.3-319ed2c0-79128878"
if [ ! -d MobileVLCKit.xcframework ]; then
  echo "Downloading MobileVLCKit $VLC (~250 MB)..."
  curl -fL -o vlc.tar.xz "https://download.videolan.org/pub/cocoapods/prod/MobileVLCKit-$VLC.tar.xz"
  verify 0d04059906962ddc9a7bd1ebaa12e1f9ae85eb2466116a97a2f46886dd27a0a9 vlc.tar.xz
  tar -xf vlc.tar.xz && mv MobileVLCKit-binary/MobileVLCKit.xcframework . && rm -rf MobileVLCKit-binary vlc.tar.xz
fi

NODE="v18.20.4"
if [ ! -d nodejs-mobile/NodeMobile.xcframework ]; then
  echo "Downloading nodejs-mobile $NODE (~49 MB)..."
  curl -fL -o node.zip "https://github.com/nodejs-mobile/nodejs-mobile/releases/download/$NODE/nodejs-mobile-$NODE-ios.zip"
  verify 8c5ca3a0d1e38de7f182a5642593e82593b820efd375a14b3ecafc4bcfee620e node.zip
  rm -rf nodejs-mobile && unzip -q node.zip -d nodejs-mobile && rm node.zip
fi
echo "Done. Frameworks/ ready."
