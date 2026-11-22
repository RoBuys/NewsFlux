// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "NewsFlux",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Mises à jour automatiques.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "NewsFlux",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/NewsFlux",
            linkerSettings: [
                // Sparkle.framework est copié dans Contents/Frameworks de la .app.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
    ]
)
