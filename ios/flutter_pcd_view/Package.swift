// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_pcd_view",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "flutter-pcd-view", targets: ["flutter_pcd_view"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_pcd_view",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            path: "Sources/flutter_pcd_view",
            linkerSettings: [
                .linkedFramework("CoreVideo"),
                .linkedFramework("Metal"),
                .linkedFramework("UIKit")
            ]
        )
    ]
)
