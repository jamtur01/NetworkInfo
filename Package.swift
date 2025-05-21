// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "NetworkInfo",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "NetworkInfo", targets: ["NetworkInfo"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "NetworkInfo",
            dependencies: [],
            exclude: ["Info.plist", "NetworkInfo.entitlements"],
            resources: [
                .process("Assets.xcassets")
            ]),
        .testTarget(
            name: "NetworkInfoTests",
            dependencies: ["NetworkInfo"])
    ]
)
