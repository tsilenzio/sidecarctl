// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "sidecarctl",
    // IOKit's kIOMainPortDefault, used to find an iPad on USB, arrived in macOS 12
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(name: "sidecarctl", dependencies: ["CGVirtualDisplayPrivate"]),
        .target(name: "CGVirtualDisplayPrivate"),
    ],
    swiftLanguageVersions: [.v5]
)
