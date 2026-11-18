// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GeoBridge",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "GeoBridge", targets: ["GeoBridge"])
    ],
    targets: [
        .executableTarget(
            name: "GeoBridge",
            path: "GeoBridge",
            swiftSettings: [.define("XCODE_BUILD", .when(configuration: .release))]
        ),
        .testTarget(
            name: "GeoBridgeTests",
            path: "GeoBridgeTests",
            resources: [.process("Fixtures")],
            swiftSettings: [.define("TESTING")]
        )
    ]
)
