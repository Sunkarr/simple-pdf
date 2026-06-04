// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SimplePDF",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SimplePDF", targets: ["SimplePDF"])
    ],
    targets: [
        .executableTarget(
            name: "SimplePDF",
            dependencies: [],
            path: "Sources"
        )
    ]
)
