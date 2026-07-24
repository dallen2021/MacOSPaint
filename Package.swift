// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MacOSPaint",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "PaintModel", targets: ["PaintModel"]),
        .library(name: "PaintEngine", targets: ["PaintEngine"]),
        .library(name: "PaintIO", targets: ["PaintIO"]),
        .executable(name: "MacOSPaint", targets: ["MacOSPaintApp"])
    ],
    targets: [
        .target(
            name: "PaintModel"
        ),
        .target(
            name: "PaintEngine",
            dependencies: ["PaintModel"]
        ),
        .target(
            name: "PaintIO",
            dependencies: ["PaintModel", "PaintEngine"]
        ),
        .executableTarget(
            name: "MacOSPaintApp",
            dependencies: ["PaintModel", "PaintEngine", "PaintIO"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PaintModelTests",
            dependencies: ["PaintModel"]
        ),
        .testTarget(
            name: "PaintEngineTests",
            dependencies: ["PaintEngine", "PaintModel"]
        ),
        .testTarget(
            name: "PaintIOTests",
            dependencies: ["PaintIO", "PaintEngine", "PaintModel"]
        )
    ],
    swiftLanguageModes: [.v6]
)
