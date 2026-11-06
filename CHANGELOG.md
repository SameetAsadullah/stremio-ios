# Changelog

All notable changes are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-11-06

### Added

- Stremio's web app in a web view, served from a loopback proxy.
- Stremio's streaming server 4.21.1 on the device through nodejs-mobile.
- Native VLC playback with audio and subtitle track pickers and subtitles from add-ons.
- AirPlay mirroring and HDMI output through an external display scene.
- A Safari sheet for new windows, so Facebook and Apple login work.
- Unit tests, `swift-format` configuration and a Makefile.

### Security

- The streaming server and the proxy accept connections only from the device.
- The app checks the SHA-256 of `server.js`, and `scripts/bootstrap.sh` checks the SHA-256 of
  both frameworks.
- Native requests outside the device must use HTTPS.

[1.0.0]: https://github.com/SameetAsadullah/stremio-ios/releases/tag/v1.0.0
