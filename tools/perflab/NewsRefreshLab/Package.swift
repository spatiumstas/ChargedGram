// swift-tools-version:5.5
import PackageDescription
let package = Package(
    name: "NewsRefreshLab",
    platforms: [.macOS(.v10_15)],
    dependencies: [.package(path: "../../../packages/TGUIKit")],
    targets: [
        .target(name: "NewsRefreshViews", dependencies: ["TGUIKit"]),
        .executableTarget(name: "NewsRefreshPreview", dependencies: ["NewsRefreshViews"]),
        .testTarget(name: "NewsRefreshTests", dependencies: ["NewsRefreshViews"])
    ]
)
