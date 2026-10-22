// swift-tools-version: 6.0
import PackageDescription

// Build-only tooling. DSStore is MIT licensed and is not linked into Magic Charger.
let package = Package(
    name: "MagicChargerDmgLayout",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "DmgLayout", targets: ["DmgLayout"])],
    dependencies: [.package(url: "https://github.com/sindresorhus/DSStore.git", exact: "1.0.0")],
    targets: [
        .executableTarget(name: "DmgLayout", dependencies: [
            .product(name: "DSStore", package: "DSStore")
        ])
    ]
)
