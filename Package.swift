// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FloatingRecorder",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "FloatingRecorder",
            targets: ["FloatingRecorder"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1")
    ],
    targets: [
        .executableTarget(
            name: "FloatingRecorder",
            dependencies: [
                .product(name: "HotKey", package: "HotKey")
            ],
            path: "FloatingRecorder",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-enable-bare-slash-regex"])
            ]
        ),
    ]
) 