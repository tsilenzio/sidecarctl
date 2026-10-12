// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "sidecarctl",
    // IOKit's kIOMainPortDefault, used to find an iPad on USB, arrived in macOS 12
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(name: "sidecarctl", dependencies: ["SidecarctlLogic", "CGVirtualDisplayPrivate"]),
        // What can be decided without a device, kept apart so it can be tested
        .target(name: "SidecarctlLogic"),
        .target(name: "CGVirtualDisplayPrivate"),
        .testTarget(name: "SidecarctlLogicTests", dependencies: ["SidecarctlLogic"]),
    ],
    swiftLanguageVersions: [.v5]
)
