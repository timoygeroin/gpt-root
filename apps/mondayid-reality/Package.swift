// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MondayIDRealityEdge",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "MondayIDRealityEdge", targets: ["MondayIDRealityEdge"])],
    targets: [
        .target(name: "MondayIDRealityEdge", path: "edge/ios/MondayIDRealityEdge"),
        .testTarget(name: "MondayIDRealityEdgeTests", dependencies: ["MondayIDRealityEdge"], path: "edge/ios/Tests")
    ]
)
