// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacHealthGuardian",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MacHealthGuardian",
            targets: ["MacHealthGuardian"]
        ),
        .library(
            name: "MacHealthGuardianCore",
            targets: ["MacHealthGuardianCore"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MacHealthGuardian",
            dependencies: ["MacHealthGuardianCore"],
            linkerSettings: [
                .linkedFramework("ServiceManagement")
            ]
        ),
        .target(
            name: "MacHealthGuardianCore",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "MacHealthGuardianCoreTests",
            dependencies: ["MacHealthGuardianCore"]
        ),
        .testTarget(
            name: "MacHealthGuardianTests",
            dependencies: ["MacHealthGuardian", "MacHealthGuardianCore"]
        )
    ]
)
