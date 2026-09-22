// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FamilyHubCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FamilyHubCore", targets: ["FamilyHubCore"])
    ],
    targets: [
        .target(name: "FamilyHubCore"),
        .testTarget(name: "FamilyHubCoreTests", dependencies: ["FamilyHubCore"])
    ]
)
