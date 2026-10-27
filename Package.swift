// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EMLViewer",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "EMLCore", targets: ["EMLCore"]),
        .executable(name: "emlcheck", targets: ["emlcheck"]),
        .executable(name: "EMLViewer", targets: ["EMLViewer"]),
    ],
    targets: [
        .target(name: "EMLCore"),
        .testTarget(
            name: "EMLCoreTests",
            dependencies: ["EMLCore"],
            path: "Tests/EMLCoreTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
        .executableTarget(name: "emlcheck", dependencies: ["EMLCore"]),
        .executableTarget(
            name: "EMLViewer",
            dependencies: ["EMLCore"],
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
    ]
)
