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
    "Shared/App",
    "Shared/AppIcons",
    "Shared/Components",
    "Shared/Coordinators",
    "Shared/Errors",
    "Shared/Extensions",
    "Shared/Logging",
    "Shared/Objects",
    "Shared/Services",
    "Shared/Strings",
    "Shared/SwiftfinStore",
    "Shared/ViewModels",
    "Shared/Views",
    "Swiftfin/Components",
    "Swiftfin/Extensions",
    "Swiftfin/Objects",
    "Swiftfin/Views",
]

let swiftfinTargetResources: [Resource] = [
    .process("Shared/Resources"),
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
        .package(url: "https://github.com/apple/swift-collections.git", exact: "1.6.0"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.14.0"),
        .package(url: "https://github.com/quangDecember/CoreStore.git", branch: "xcode27"),
        .package(url: "https://github.com/JohnSundell/Files", exact: "4.3.0"),
        .package(url: "https://github.com/LePips/BlurHashKit", exact: "2.0.0"),
        .package(url: "https://github.com/LePips/CollectionHStack", branch: "main"),
        .package(url: "https://github.com/LePips/CollectionVGrid", branch: "main"),
        .package(url: "https://github.com/LePips/StatefulMacro", exact: "0.1.7"),
        .package(url: "https://github.com/LePips/VLCUI", exact: "0.8.1"),
        .package(url: "https://github.com/SVGKit/SVGKit", exact: "3.0.0"),
        .package(url: "https://github.com/evgenyneu/keychain-swift", exact: "24.0.0"),
        .package(url: "https://github.com/guoyingtao/Mantis", exact: "2.31.2"),
        .package(url: "https://github.com/hmlongco/Factory", exact: "3.3.2"),
        .package(url: "https://github.com/jellyfin/jellyfin-sdk-swift.git", exact: "2.1.0"),
        .package(url: "https://github.com/kean/Get", exact: "2.2.1"),
        .package(url: "https://github.com/kean/Nuke", exact: "13.0.6"),
        .package(url: "https://github.com/kean/Pulse", exact: "5.2.3"),
        .package(url: "https://github.com/kean/PulseLogHandler", exact: "5.1.0"),
        .package(url: "https://github.com/nathantannar4/Transmission", exact: "2.13.4"),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", exact: "1.1.1"),
        .package(url: "https://github.com/sindresorhus/Defaults", exact: "9.0.9"),
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
                .product(name: "CollectionHStack", package: "CollectionHStack"),
                .product(name: "CollectionVGrid", package: "CollectionVGrid"),
                .product(name: "CoreStore", package: "CoreStore"),
                .product(name: "Defaults", package: "Defaults"),
                .product(name: "FactoryKit", package: "Factory"),
                .product(name: "Files", package: "Files"),
                .product(name: "Get", package: "Get"),
                .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
                .product(name: "JellyfinAPI", package: "jellyfin-sdk-swift"),
                .product(name: "KeychainSwift", package: "keychain-swift"),
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
            url: "https://github.com/showbie/MobileVLCKit-SPM/releases/download/3.7.3/MobileVLCKit.xcframework.zip",
            checksum: "0346e458e119d57d4768d4096e2f7b4f77b7a0df4e21d0e728856f309cc6e8ab"
        ),
    ]
)
