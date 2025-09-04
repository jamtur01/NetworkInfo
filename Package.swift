// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NetworkInfo",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "NetworkInfo", targets: ["NetworkInfo"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "NetworkInfo",
            dependencies: [],
            exclude: ["Info.plist", "NetworkInfo.entitlements", "Assets.xcassets"],
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "NetworkInfoTests",
            dependencies: ["NetworkInfo"])
    ]
)
