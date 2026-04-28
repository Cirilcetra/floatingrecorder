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
    dependencies: [],
    targets: [
        .executableTarget(
            name: "FloatingRecorder",
            dependencies: [],
            path: "FloatingRecorder",
            exclude: [
                "Info.plist"
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-enable-bare-slash-regex"])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "FloatingRecorder/Info.plist"
                ])
            ]
        ),
    ]
)
