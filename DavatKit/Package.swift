// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DavatKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "DavatKit", targets: ["DavatKit"])],
    dependencies: [.package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")],
    targets: [
        .target(name: "DavatKit", dependencies: [.product(name: "Supabase", package: "supabase-swift")]),
        .testTarget(name: "DavatKitTests", dependencies: ["DavatKit"]),
    ]
)
