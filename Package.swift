// swift-tools-version: 5.9

import PackageDescription

let swiftfinTargetExcludes = [
    ".build",
    ".github",
    ".swiftpm",
    "Carthage",
    "Documentation",
    "PreferencesView",
    "Resources",
    "Scripts",
    "Swiftfin tvOS",
    "Swiftfin.xcodeproj",
    "XcodeConfig",
    "build",
    "fastlane",
    "Shared/.DS_Store",
    "Shared/Objects/.DS_Store",
    "Shared/Objects/MediaPlayerManager/.DS_Store",
    "Swiftfin/.DS_Store",
    "Swiftfin/App",
    "Swiftfin/Resources/Info.plist",
    "Swiftfin/Resources/Swiftfin.entitlements",
    "Translations/.DS_Store",
]

let swiftfinTargetSources = [
    "Shared",
    "Swiftfin/Components",
    "Swiftfin/Extensions",
    "Swiftfin/Objects",
    "Swiftfin/Views",
]

let swiftfinTargetResources: [Resource] = [
    .process("Swiftfin/Resources/Assets.xcassets"),
    .process("Translations"),
]

let package = Package(
    name: "Swiftfin",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "SwiftfinLib",
            targets: ["SwiftfinLib"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms.git", exact: "1.2.1"),
        .package(url: "https://github.com/apple/swift-collections.git", exact: "1.4.1"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.12.0"),
        .package(url: "https://github.com/quangDecember/CoreStore.git", branch: "xcode27"),
        .package(url: "https://github.com/JohnSundell/Files", exact: "4.3.0"),
        .package(url: "https://github.com/LePips/BlurHashKit", exact: "1.2.0"),
        .package(url: "https://github.com/LePips/CollectionHStack", branch: "main"),
        .package(url: "https://github.com/LePips/CollectionVGrid", branch: "main"),
        .package(url: "https://github.com/LePips/StatefulMacro", exact: "0.1.4"),
        .package(url: "https://github.com/LePips/VLCUI", exact: "0.8.1"),
        .package(url: "https://github.com/LeoNatan/LNPopupUI/", exact: "2.0.2"),
        .package(url: "https://github.com/SVGKit/SVGKit", exact: "3.0.0"),
        .package(url: "https://github.com/evgenyneu/keychain-swift", exact: "24.0.0"),
        .package(url: "https://github.com/guoyingtao/Mantis", exact: "2.31.1"),
        .package(url: "https://github.com/hmlongco/Factory", exact: "2.5.3"),
        .package(url: "https://github.com/jellyfin/jellyfin-sdk-swift.git", exact: "2.1.0"),
        .package(url: "https://github.com/kean/Get", exact: "2.2.1"),
        .package(url: "https://github.com/kean/Nuke", exact: "13.0.2"),
        .package(url: "https://github.com/kean/Pulse", exact: "5.2.0"),
        .package(url: "https://github.com/kean/PulseLogHandler", exact: "5.1.0"),
        .package(url: "https://github.com/nathantannar4/Engine", exact: "2.7.0"),
        .package(url: "https://github.com/nathantannar4/Transmission", exact: "2.8.3"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths.git", exact: "1.7.3"),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", exact: "1.1.1"),
        .package(url: "https://github.com/sindresorhus/Defaults", exact: "9.0.2"),
        .package(url: "https://github.com/siteline/SwiftUI-Introspect", exact: "26.0.1"),
    ],
    targets: [
        .target(
            name: "PreferencesView",
            path: "PreferencesView/Sources/PreferencesView"
        ),
        .target(
            name: "SwiftfinLib",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "BlurHashKit", package: "BlurHashKit"),
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "CollectionHStack", package: "CollectionHStack"),
                .product(name: "CollectionVGrid", package: "CollectionVGrid"),
                .product(name: "CoreStore", package: "CoreStore"),
                .product(name: "Defaults", package: "Defaults"),
                .product(name: "Engine", package: "Engine"),
                .product(name: "Factory", package: "Factory"),
                .product(name: "Files", package: "Files"),
                .product(name: "Get", package: "Get"),
                .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
                .product(name: "JellyfinAPI", package: "jellyfin-sdk-swift"),
                .product(name: "KeychainSwift", package: "keychain-swift"),
                .product(name: "LNPopupUI-Static", package: "LNPopupUI"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Mantis", package: "Mantis"),
                "MobileVLCKit",
                .product(name: "Nuke", package: "Nuke"),
                .product(name: "NukeUI", package: "Nuke"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                "PreferencesView",
                .product(name: "Pulse", package: "Pulse"),
                .product(name: "PulseLogHandler", package: "PulseLogHandler"),
                .product(name: "PulseUI", package: "Pulse"),
                .product(name: "SVGKit", package: "SVGKit"),
                .product(name: "StatefulMacros", package: "StatefulMacro"),
                .product(name: "SwiftUIIntrospect", package: "SwiftUI-Introspect"),
                .product(name: "Transmission", package: "Transmission"),
                .product(name: "VLCUI", package: "VLCUI"),
            ],
            path: ".",
            exclude: swiftfinTargetExcludes,
            sources: swiftfinTargetSources,
            resources: swiftfinTargetResources
        ),
        .binaryTarget(
            name: "MobileVLCKit",
            path: "Carthage/Build/MobileVLCKit.xcframework"
        ),
    ]
)
