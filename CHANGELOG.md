# Changelog

All notable changes are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- A torrent with few seeders starts to play as soon as its first data arrives. Before, VLC waited
  for 4 MB at a time.

## [1.1.0] - 2026-11-06

### Added

- Watch progress syncs to the Stremio account, so Continue Watching and resume work with VLC.
- A Next Episode button during the credits. With binge watching on, the next episode plays at
  the end.
- Lock screen and Control Center controls with the title and poster.
- The show and episode as the player title.
- One Audio & Subtitles menu with subtitle size and playback speed.
- Audio and subtitles in the languages from Stremio's settings.
- Double-tap the left or right side of the player to skip 10 s.
- A Start Over button when a video resumes.
- A splash screen while Stremio loads.

### Changed

- The player opens in landscape. Stremio returns to its earlier orientation when the player
  closes.
- The player keeps the screen awake during playback.
- The player's top bar is simpler.
- The reinstall scripts accept several devices.
- The streaming server keeps the previous log.

### Fixed

- Large streams no longer use up the app's memory. VLC gets streams in bounded chunks.
- Seeks stay on target while the stream buffers, and the player shows the buffering status. The
  time follows the scrub bar during a drag.
- Stremio no longer shows a playback error after VLC closes.

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

[Unreleased]: https://github.com/SameetAsadullah/stremio-ios/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/SameetAsadullah/stremio-ios/releases/tag/v1.1.0
[1.0.0]: https://github.com/SameetAsadullah/stremio-ios/releases/tag/v1.0.0
