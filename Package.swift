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
        )
    ],
    targets: [
        .executableTarget(
            name: "MacHealthGuardian",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
