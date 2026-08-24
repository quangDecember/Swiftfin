// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "BinaryConsumer",
    platforms: [
        .iOS("18.6"),
        .tvOS("26.1"),
    ],
    products: [
        .library(name: "BinaryConsumer", targets: ["BinaryConsumer"]),
    ],
    dependencies: [
        .package(name: "Swiftfin", path: "../.."),
    ],
    targets: [
        .target(
            name: "BinaryConsumer",
            dependencies: [
                .product(name: "Swiftfin", package: "Swiftfin"),
            ]
        ),
    ]
)
