# Third-party notices

The app uses the software below. This repository does not contain the code of any of them. The
frameworks download with `scripts/bootstrap.sh`, and the app downloads Stremio's streaming server
at first launch.

| Component | Version | License | How the app uses it |
| --- | --- | --- | --- |
| [MobileVLCKit](https://code.videolan.org/videolan/VLCKit) | 3.7.3 | LGPL-2.1-or-later | Embedded framework, plays video |
| [nodejs-mobile](https://github.com/nodejs-mobile/nodejs-mobile) | 18.20.4 | MIT, plus the licenses of the Node.js dependencies | Embedded framework, runs `server.js` |
| [Stremio web app](https://github.com/Stremio/stremio-web) | Current release | GPL-2.0 | Loaded from `web.stremio.com` at run time, not distributed |
| Stremio streaming server (`server.js`) | 4.21.1 | Proprietary, © Smart Code OOD | Downloaded from `dl.strem.io` at first launch, not distributed |

## MobileVLCKit

MobileVLCKit is free software under the GNU Lesser General Public License, version 2.1 or later.
Its source code is at <https://code.videolan.org/videolan/VLCKit>. Because the source code of
this app is also available, you can rebuild the app with a modified MobileVLCKit.

## Stremio

Stremio is a trademark of Smart Code OOD. This project is not affiliated with or endorsed by
Smart Code OOD.
