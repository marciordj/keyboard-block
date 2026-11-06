// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KeyboardBlock",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "KeyboardBlock",
            path: "Sources/KeyboardBlock"
        )
    ]
)
