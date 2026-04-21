// swift-tools-version: 6.1

import PackageDescription

var package = Package(
    name: "NimbusVungleKit",
    platforms: [.iOS(.v13)],
    products: [
        .library(
           name: "NimbusVungleKit",
           targets: ["NimbusVungleKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/Vungle/VungleAdsSDK-SwiftPackageManager", from: "7.6.0")
    ],
    targets: [
        .target(
            name: "NimbusVungleKit",
            dependencies: [
                .product(name: "NimbusKit", package: "nimbus-ios-sdk"),
                .product(name: "VungleAdsSDK", package: "VungleAdsSDK-SwiftPackageManager")
            ]
        ),
        .testTarget(
            name: "NimbusVungleKitTests",
            dependencies: ["NimbusVungleKit"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)

package.dependencies.append(.package(url: "https://github.com/adsbynimbus/nimbus-ios-sdk", from: "3.0.0-rc.1"))
