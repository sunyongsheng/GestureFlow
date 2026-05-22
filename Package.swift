// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GestureFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "GestureFlowCore", targets: ["GestureFlowCore"]),
        .executable(name: "GestureFlowApp", targets: ["GestureFlowApp"])
    ],
    targets: [
        .target(
            name: "GestureFlowCore"
        ),
        .executableTarget(
            name: "GestureFlowApp",
            dependencies: ["GestureFlowCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .testTarget(
            name: "GestureFlowCoreTests",
            dependencies: ["GestureFlowCore"]
        ),
        .testTarget(
            name: "GestureFlowAppTests",
            dependencies: ["GestureFlowApp"]
        )
    ]
)
