// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "Magic Charger", platforms: [.macOS(.v14)], products: [.executable(name: "MagicCharger", targets: ["MagicCharger"])], targets: [.executableTarget(name: "MagicCharger"), .testTarget(name: "MagicChargerTests", dependencies: ["MagicCharger"])], swiftLanguageModes: [.v5])
