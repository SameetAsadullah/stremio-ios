# Contributing

This is a personal project. Issues and pull requests are welcome, but there is no promise that a
change will be accepted.

## Set up

Follow "Getting started" in the [README](README.md). Then:

```bash
make generate
make test
```

## Code

- Change `project.yml`, never the generated `Stremio.xcodeproj` or `Info.plist`.
- Run `make format` and `make lint` before you commit.
- Put new logic that does not need UIKit in small functions, and add unit tests in
  `Tests/StremioTests`.
- Log through `Log.<category>` (`os.Logger`). Leave URLs and titles at the default privacy.
- Write comments only for what the code cannot say: constraints and non-obvious reasons.

### Player self-test

Add `VLC_SELFTEST` to `SWIFT_ACTIVE_COMPILATION_CONDITIONS` and set the environment variable
`STREMIO_SELFTEST_URL` to a stream URL in the scheme. The app then plays that URL through the
same proxy and VLC path as a Play tap, with no UI steps.

## Commits

- One change per commit. Each commit must build and pass the tests.
- Subject: imperative mood, at most 72 characters, for example "Fix the subtitle delay".
- Add a body only when the reason for the change is not clear from the diff.

## Pull requests

Describe what the change does and why in 2 to 4 sentences. Say how you tested it on a device.
