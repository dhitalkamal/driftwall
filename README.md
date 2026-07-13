# Driftwall

Live video wallpaper for macOS. Pick an .mp4 or .mov and it plays, looping seamlessly,
behind your desktop icons on every display, while you keep using your Mac normally.

## Tiers

- Free: one video across all displays, fit mode, volume, dim, pause on battery/occlusion,
  launch at login.
- Pro (license): a different video per display, playlists with scheduled rotation, playback
  FX, and (planned) Lock Screen video. See docs/SELLING.md for the go-to-market plan.

## Requirements

- macOS 13 or later.
- Swift toolchain. The Xcode command line tools are enough to build and test; full Xcode is
  only needed to notarize for distribution.

## Build and run

    scripts/build_app.sh        # produces dist/Driftwall.app (ad-hoc signed for local use)
    open dist/Driftwall.app

Or run without bundling:

    swift run DriftwallApp

The app lives in the menu bar (no dock icon). Click the icon, choose a video or open
Preferences. Quitting removes the wallpaper and reveals your normal desktop; the app never
changes the system desktop-picture setting.

## Tests

    swift run DriftwallCoreTests

Exit code 0 means all passed. The runner is a small dependency-free harness (see
`Tests/DriftwallCoreTests/TestRunner.swift`) so tests run under the command line tools, where
neither XCTest nor the swift-testing macro plugin is available. It ports to XCTest easily.

## How it works

macOS has no public API to set a video as the desktop picture, so Driftwall uses the standard
(unofficial) technique: a borderless NSWindow per screen at the desktop window level.

- Window level `CGWindowLevelForKey(.desktopWindow)` sits above the static desktop picture
  and below the icons. Collection behavior `[.canJoinAllSpaces, .stationary, .ignoresCycle]`;
  `.stationary` is required or the window vanishes in Mission Control. The window ignores
  mouse events so clicks pass through.
- Video plays through `AVQueuePlayer` + `AVPlayerLooper` for gapless looping, with a dim
  overlay layer and per-fit-mode video gravity.
- Playback pauses when occluded, on a fullscreen app, or on battery, driven by a pure
  playback policy fed by IOKit power state and window occlusion.

## Architecture

Hexagonal layering, imports flow inward only:

- `Sources/DriftwallCore` (pure, no AppKit): domain and application logic. Domain holds
  PlaybackPolicy, WallpaperConfig, FitMode, Playlist/RotationState, PlaybackSettings, and
  License/FeatureGate. Application holds WallpaperController, WallpaperResolver, and the ports.
- `Sources/DriftwallApp` (AppKit/AVFoundation/IOKit/CryptoKit): adapters that implement the
  ports, the SwiftUI preferences window, the menu bar, and the license verifier.

## Packaging and selling

- `scripts/build_app.sh` signs with `$DEVELOPER_ID_IDENTITY` if set (hardened runtime always
  on), else ad-hoc for local use.
- `scripts/notarize.sh` and `scripts/make_dmg.sh` produce a notarized, stapled DMG.
- `scripts/license/` generates the issuer keypair and issues offline license tokens.
- `docs/SELLING.md` is the full checklist to go from this repo to a paid product.

## Limitations

- Desktop only. Lock Screen video is planned but not shipped (it needs the macOS 26 native
  wallpaper APIs, pending a research spike).
- Not sandboxed and not Mac App Store distributable, by nature of the desktop window
  technique. Sold direct (notarized), not through the App Store.
- The desktop window level is an undocumented technique. Stable for years across many apps,
  but retest on each annual macOS release.
