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
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.6"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.4")
    ],
    targets: [
        .target(
            name: "GestureFlowCore",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ]
        ),
        .executableTarget(
            name: "GestureFlowApp",
            dependencies: [
                "GestureFlowCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement")
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
