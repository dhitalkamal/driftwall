# LiveWallpaper

A small macOS menu-bar app that plays an .mp4 (or .mov) as a live desktop wallpaper. It
renders the video in a borderless window pinned to the desktop window level, so the video
sits behind your desktop icons while you keep using the Mac normally.

## What it does

- Pick a video from the menu bar and it plays, looping seamlessly, behind the icons.
- Spans every display and follows display changes (plugging or unplugging a monitor).
- Pauses playback automatically when nothing can see it (a window or fullscreen app covers
  it) and, optionally, while on battery. This keeps CPU and power use low.
- Remembers the selected video and settings across launches.
- Optional launch at login.

## Requirements

- macOS 13 or later.
- Swift toolchain (the Xcode command line tools are enough to build; full Xcode is not
  required).

## Build

    scripts/build_app.sh

This produces `dist/LiveWallpaper.app`, ad-hoc signed for local use. Move it to
`/Applications` if you want, then double click to run. Because it is ad-hoc signed (not
notarized), the first launch may need a right click -> Open, or an approval in
System Settings -> Privacy and Security.

## Run without bundling

    swift run LiveWallpaperApp

## Usage

1. Launch the app. It lives in the menu bar (no dock icon).
2. Click the menu bar icon -> Choose Video... and pick an .mp4 or .mov.
3. The video appears behind your desktop icons on every screen.
4. Use the menu to toggle Pause on Battery and Launch at Login, or Quit.

Quitting removes the wallpaper window and reveals your normal desktop. The app never
changes the system desktop-picture setting, so there is nothing to undo.

## How it works

macOS has no public API to set a video as the desktop picture, so this app uses the
standard (unofficial) technique: a borderless NSWindow per screen at the desktop window
level.

- Window level: `CGWindowLevelForKey(.desktopWindow)`, which sits above the static desktop
  picture and below the icons.
- Collection behavior: `[.canJoinAllSpaces, .stationary, .ignoresCycle]`. The `.stationary`
  flag is required, otherwise a non-normal window level defaults to transient and the window
  disappears in Mission Control.
- The window ignores mouse events, so clicks pass through to the desktop and icons.
- Video plays through a single `AVQueuePlayer` driven by `AVPlayerLooper` for gapless
  looping, muted, with one `AVPlayerLayer` per screen sharing that player.
- Power management samples battery state (IOKit power sources) and window occlusion, and the
  playback policy decides play vs pause from those signals.

## Architecture

Hexagonal layering, imports flow inward only:

- `Sources/LiveWallpaperCore` (pure, no AppKit): the domain and application logic.
  - `Domain`: `PlaybackPolicy`, `PlaybackConditions`, `WallpaperConfig`, `EnvironmentSignals`.
  - `Application`: `WallpaperController` plus the `WallpaperRendering` and `ConfigStoring`
    ports.
- `Sources/LiveWallpaperApp` (AppKit/AVFoundation/IOKit): the adapters that implement the
  ports and the menu-bar presentation.

## Tests

The core logic is covered by tests that run without XCTest or full Xcode:

    swift run LiveWallpaperCoreTests

Exit code 0 means all passed. The runner is a small dependency-free harness (see
`Tests/LiveWallpaperCoreTests/TestRunner.swift`) chosen because this build environment has
only the command line tools, where neither XCTest nor the swift-testing macro plugin is
available. The tests are structured so they port to XCTest easily if you later prefer it.

## Limitations

- Desktop only. This does not touch the Lock Screen, which would require private APIs or
  system-file replacement that break across OS updates.
- Not sandboxed and not App Store distributable, by nature of the desktop window technique.
- The desktop window level is an undocumented technique, not an Apple-supported API. It has
  been stable for years but is not guaranteed across future macOS releases.
