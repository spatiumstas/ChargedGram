// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "ChargedGramSettings",
    defaultLocalization: "en",
    platforms: [.macOS(.v10_13)],
    products: [.library(name: "ChargedGramSettings", targets: ["ChargedGramSettings"])],
    targets: [
        .target(name: "ChargedGramSettings", resources: [.process("Resources")]),
        .testTarget(name: "ChargedGramSettingsTests", dependencies: ["ChargedGramSettings"])
    ]
)
