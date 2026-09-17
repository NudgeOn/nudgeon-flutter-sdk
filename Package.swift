// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "NudgeOnBridgeContract",
    platforms: [.macOS(.v12), .iOS(.v15)],
    dependencies: [.package(url: "https://github.com/NudgeOn/nudgeon-ios-sdk.git", exact: "0.2.2")],
    targets: [
        .target(name: "BridgeValues", dependencies: [.product(name: "NudgeOnSDK", package: "nudgeon-ios-sdk")], path: "ios/Classes", exclude: ["NudgeOnFlutterPlugin.swift"], sources: ["NudgeOnFlutterValues.swift"]),
        .testTarget(name: "BridgeValuesTests", dependencies: ["BridgeValues", .product(name: "NudgeOnSDK", package: "nudgeon-ios-sdk")], path: "tests/ios")
    ]
)
