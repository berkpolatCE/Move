// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Move",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "MoveCore"),
        .executableTarget(name: "Move", dependencies: ["MoveCore"]),
        .testTarget(name: "MoveCoreTests", dependencies: ["MoveCore"]),
    ]
)
