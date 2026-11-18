// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DavatKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "DavatKit", targets: ["DavatKit"])],
    targets: [
        .target(name: "DavatKit"),
        .testTarget(name: "DavatKitTests", dependencies: ["DavatKit"]),
    ]
)
