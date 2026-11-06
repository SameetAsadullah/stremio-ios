# Stremio iOS App (unofficial)

A native iPhone/iPad app for [Stremio](https://www.stremio.com), built around the **real Stremio
web app** with a **VLC player** underneath — so streams Safari can't play (MKV, x265/HEVC,
AC3/EAC3/DTS, multi-audio) just work. It runs Stremio's **streaming server on the device
itself**, so torrents play with no home server and no debrid. Because it's the official web UI, it
stays current whenever Stremio ships updates; only the server + playback are native.

> Unofficial. Not affiliated with or endorsed by Stremio. Bring your own streams/addons.

## Features

- Official Stremio web UI (`web.stremio.com`)
- Native VLC playback: MKV, HEVC/x265 (hardware-decoded on device), AC3/DTS/EAC3, any container
- **Audio & subtitle track pickers** for multi-audio releases
- Tap to show/hide controls · double-tap or ⤢ for Fit / Fill · pinch to zoom · ±10 s · scrub
- Cold torrents don't error out: the app holds the connection and shows live buffering
  ("Buffering from 23 sources · 2.1 MB/s") until data flows
- Skips the server-side ffmpeg transcode entirely — VLC plays the raw file, keeping your
  streaming server's CPU free
- Close works instantly, even mid-buffer

## How it works

```
Stremio web app (served from 127.0.0.1 by the app) → in-app server.js → VLC
   └─ Play → injected JS grabs the raw file URL from the /hlsv2 request and cancels the transcode
        └─ loopback relay (127.0.0.1) holds the connection while a cold torrent starts
             └─ MobileVLCKit decodes natively → full-screen player
```

On first launch the app downloads Stremio's streaming server (`server.js`, about 7 MB) and checks
its SHA-256. Downloads pause when the app is in the background (iOS limit).

## Play on a TV

- **AirPlay / HDMI (any file, any codec):** Control Center -> Screen Mirroring -> your Apple TV or
  AirPlay TV (or plug in a USB-C/Lightning->HDMI adapter). The phone keeps decoding with VLC and
  renders full-quality video onto the TV as an external display; you keep the controls. Works for
  MKV / x265 / AC3 / DTS because the TV never decodes anything.

## Build & install

```bash
brew install xcodegen
scripts/fetch-vlc.sh          # downloads MobileVLCKit.xcframework (~1.3 GB, gitignored)
xcodegen generate
open Stremio.xcodeproj        # Signing & Capabilities → pick your Team → Run on your iPhone
```

Or from the command line:

```bash
xcodebuild -project Stremio.xcodeproj -scheme Stremio -destination "id=<device-udid>" \
  -derivedDataPath build-device DEVELOPMENT_TEAM=<TEAM_ID> CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates build
xcrun devicectl device install app --device <device-udid> \
  build-device/Build/Products/Debug-iphoneos/Stremio.app
```

Change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` to your own. A free Apple ID signs for
7 days; a paid developer team for a year.

`VLC_SELFTEST` (Swift compilation condition) auto-plays a stream through the same
proxy/VLC path — handy for iterating on the player without the UI.

## Notes

- The iOS Simulator has no hardware HEVC decoder, so 4K x265 stutters there. Real devices decode it in hardware.
- If your streaming server sits on a small box, keep transcoding off — every web-player play
  used to spawn an ffmpeg job that starved the torrent engine. This app never triggers it.

## License

MIT
