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
        ),
        .executable(
            name: "MacHealthGuardianCoreTestRunner",
            targets: ["MacHealthGuardianCoreTestRunner"]
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
        .executableTarget(
            name: "MacHealthGuardianCoreTestRunner",
            dependencies: ["MacHealthGuardianCore"],
            path: "Tests/MacHealthGuardianCoreTestRunner"
        )
    ]
)
