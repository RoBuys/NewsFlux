// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "NewsFlux",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NewsFlux",
            path: "Sources/NewsFlux"
        ),
    ]
)
