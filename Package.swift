// swift-tools-version: 6.0
// Driftwall: plays a video as a live macOS desktop wallpaper, behind the desktop icons.
import PackageDescription

let package = Package(
    name: "Driftwall",
    platforms: [
        .macOS(.v13),
    ],
    targets: [
        // pure domain + application logic. no AppKit/AVFoundation imports here so it
        // stays testable and framework independent.
        .target(
            name: "DriftwallCore"
        ),
        // presentation + infrastructure adapters. depends on AppKit/AVFoundation/IOKit.
        .executableTarget(
            name: "DriftwallApp",
            dependencies: ["DriftwallCore"]
        ),
        // tests run as a plain executable so they work under the command line tools
        // toolchain (no XCTest / swift-testing macro plugin required). run: swift run DriftwallCoreTests
        .executableTarget(
            name: "DriftwallCoreTests",
            dependencies: ["DriftwallCore"],
            path: "Tests/DriftwallCoreTests"
        ),
    ]
)
