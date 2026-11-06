# Architecture

The app has 4 parts. They run in one process and talk to each other only over `127.0.0.1`.

| Part | Code | Job |
| --- | --- | --- |
| Web app | `Stremio/Features/Web` | Shows Stremio's web app in a `WKWebView` and catches Play |
| Loopback proxy | `Stremio/Services/StreamProxy.swift` | Serves the web app from `127.0.0.1` and relays streams to VLC |
| Streaming server | `Stremio/Services/NodeServer.swift` | Runs Stremio's `server.js` with nodejs-mobile |
| Player | `Stremio/Features/Player` | Plays the stream with MobileVLCKit |

## Startup

1. If `server.js` is missing, the first-run screen downloads it from
   `https://dl.strem.io/server/<version>/desktop/server.js`. The app keeps the file only when its
   SHA-256 matches `ServerScript.sha256`.
2. `NodeServer` starts Node.js on a background thread. A preload script runs before `server.js`.
   It binds the server's HTTP ports (11470 to 11474) to `127.0.0.1` and sends the console output
   to `Library/Caches/stremio-server.log`.
3. The app sets these environment variables for `server.js`:

   | Variable | Value | Reason |
   | --- | --- | --- |
   | `NO_CORS` | `1` | The web app and the server have different origins |
   | `CASTING_DISABLED` | `1` | No casting on this app |
   | `NO_HTTPS_SERVER` | `1` | No HTTPS endpoint on port 12470 |
   | `HLS_V2_DISABLED` | `1` | The transcoder needs ffmpeg, and iOS cannot start child processes |

4. `StreamProxy` starts on `127.0.0.1:11471`. If that port is busy, it uses a free port and
   remembers it. The web app's origin includes the port, so a stable port keeps the Stremio login
   in `localStorage`.
5. The web view loads the web app from the proxy. A user script sets the profile's streaming
   server URL to `http://127.0.0.1:11470/`.

## Why the proxy serves the web app

`web.stremio.com` is an HTTPS page. WebKit blocks an HTTPS page from calling
`http://127.0.0.1:11470` (mixed content). A page from `http://127.0.0.1` is a secure context and
can call the server. The proxy accepts only paths on `web.stremio.com`. It rejects absolute and
scheme-relative request targets.

## Playback

1. The user presses Play. Stremio's web player asks the server for an HLS transcode at
   `/hlsv2/...m3u8?mediaURL=<raw file URL>`.
2. `intercept.js` catches that request in `fetch` and `XMLHttpRequest`. It sends the raw file URL
   to the app and stops the web player, so the server never starts a transcode.
3. `PlaybackController` opens the player. The player registers the URL with the proxy and gives
   VLC the proxy URL.
4. The relay holds VLC's connection while the torrent has no data, and retries the server until
   data arrives. If the stream breaks later, the relay continues it with a `Range` request, so
   VLC does not see the break.
5. Until the first frame shows, the player reads `/<info hash>/stats.json` from the server every
   2 seconds and shows the peer count and the download speed.
6. `intercept.js` also reads the responses of subtitle add-ons and sends the subtitle URLs to the
   player. VLC loads them as extra subtitle tracks.

## New windows

Stremio's web app opens the Facebook and Apple logins, add-on configuration pages and share links
with `window.open`. The web view shows these in an `SFSafariViewController` sheet. Facebook does
not allow a login in an embedded web view. The web app checks Stremio's API for the finished
login while the sheet is open.

## External display

With AirPlay mirroring or an HDMI adapter, iOS gives the app a second, non-interactive window
scene. The player draws the decoded video into that scene, and the phone keeps the controls. The
TV decodes nothing, so every codec that VLC plays works.

## Network security

- The server's HTTP ports and the proxy listen only on `127.0.0.1`.
- App Transport Security allows plain HTTP only for local hosts and inside the web view.
- `scripts/bootstrap.sh` checks the SHA-256 of MobileVLCKit and nodejs-mobile.

## Logs

| Source | Where |
| --- | --- |
| App | `os.Logger`, subsystem `com.sameetasadullah.stremio`, categories `web`, `player`, `server`, `proxy`, `tv` |
| Streaming server | `Library/Caches/stremio-server.log` in the app container |

To copy the server log from a device:

```bash
xcrun devicectl device copy from --device <device-id> --domain-type appDataContainer \
  --domain-identifier com.sameetasadullah.stremio \
  --source Library/Caches/stremio-server.log --destination stremio-server.log
```
