// swift-tools-version: 6.0
// live wallpaper for macOS: plays an mp4 behind the desktop icons.
import PackageDescription

let package = Package(
    name: "LiveWallpaper",
    platforms: [
        .macOS(.v13),
    ],
    targets: [
        // pure domain + application logic. no AppKit/AVFoundation imports here so it
        // stays testable and framework independent.
        .target(
            name: "LiveWallpaperCore"
        ),
        // presentation + infrastructure adapters. depends on AppKit/AVFoundation/IOKit.
        .executableTarget(
            name: "LiveWallpaperApp",
            dependencies: ["LiveWallpaperCore"]
        ),
        // tests run as a plain executable so they work under the command line tools
        // toolchain (no XCTest / swift-testing macro plugin required). run: swift run LiveWallpaperCoreTests
        .executableTarget(
            name: "LiveWallpaperCoreTests",
            dependencies: ["LiveWallpaperCore"],
            path: "Tests/LiveWallpaperCoreTests"
        ),
    ]
)
