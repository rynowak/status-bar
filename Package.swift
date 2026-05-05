// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "StatusBar",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.12.0"),
    ],
    targets: [
        .executableTarget(
            name: "StatusBar",
            dependencies: ["StatusBarKit"],
            path: "Sources/StatusBar",
            exclude: ["Info.plist"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "StatusBarKit",
            path: "Sources/StatusBarKit"
        ),
        .testTarget(
            name: "StatusBarKitTests",
            dependencies: [
                "StatusBarKit",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/StatusBarKitTests"
        ),
    ]
)
