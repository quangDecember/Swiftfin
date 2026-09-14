// swift-tools-version: 6.0

import PackageDescription

// Swiftfin as a Swift package.
//
// The `SwiftfinLib` product exposes the iOS app as a library so another app can embed
// the whole Swiftfin experience (`SwiftfinScene`, `SwiftfinView`) or drop straight into
// movie playback (`SwiftfinLibrary.moviePlayer(...)`).
//
// The Xcode project remains the source of truth for the shipping apps; this manifest
// compiles the same `Shared` + `Swiftfin` sources, minus the `@main` app entry point.

// `Shared/Resources` is left out so its fonts can be declared as a resource.
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

// The target is rooted at the repository so it can reach both `Shared` and `Swiftfin`.
// SwiftPM still scans the whole root for resources, so everything that is neither a
// source nor a declared resource has to be excluded.
let swiftfinTargetExcludes = [
    ".github",
    "AGENTS.md",
    "Brewfile",
    "ChromeCastFramework.json",
    "Documentation",
    "Gemfile",
    "LICENSE.md",
    "PreferencesView",
    "README.md",
    "Resources",
    "Scripts",
    "Swiftfin tvOS",
    "Swiftfin.xcodeproj",
    "Swiftfin/App",
    "Swiftfin/Resources/Info.plist",
    "Swiftfin/Resources/Swiftfin.entitlements",
    "XcodeConfig",
    "fastlane",
    "swiftgen.yml",
]

let swiftfinTargetResources: [Resource] = [
    .copy("Shared/Resources/Fonts"),
    .process("Swiftfin/Resources/Assets.xcassets"),
    .process("Translations"),
]

let package = Package(
    name: "Swiftfin",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "SwiftfinLib",
            targets: ["SwiftfinLib"]
        ),
    ],
    dependencies: [
        // Versions mirror Swiftfin.xcodeproj's Package.resolved.
        // CoreStore 9.3.0 plus the `cs_sync` ambiguity fix needed by the Swift 6.4 (Xcode 27) toolchain.
        .package(url: "https://github.com/quangDecember/CoreStore.git", revision: "003b6faa6f80e057aec036eb19674396e8340fcf"),
        .package(url: "https://github.com/JohnSundell/Files", exact: "4.3.0"),
        .package(url: "https://github.com/LePips/BlurHashKit", exact: "2.0.0"),
        .package(url: "https://github.com/LePips/CollectionHStack", revision: "15baaaa759a0e252addae08431c79a49a25e4afc"),
        .package(url: "https://github.com/LePips/CollectionVGrid", revision: "7188ac9c8f57ada38dd1000e12b51e25d8bd29ba"),
        .package(url: "https://github.com/LePips/MPVUI", exact: "0.1.1"),
        .package(url: "https://github.com/LePips/MediaAccessibilityKit", exact: "0.1.0"),
        .package(url: "https://github.com/LePips/StatefulMacro", exact: "0.1.7"),
        .package(url: "https://github.com/LeoNatan/LNPopupUI/", exact: "2.0.2"),
        .package(url: "https://github.com/SVGKit/SVGKit", exact: "3.0.0"),
        .package(url: "https://github.com/apple/swift-algorithms.git", exact: "1.2.1"),
        .package(url: "https://github.com/apple/swift-collections.git", exact: "1.6.0"),
        .package(url: "https://github.com/evgenyneu/keychain-swift", exact: "24.0.0"),
        .package(url: "https://github.com/guoyingtao/Mantis", exact: "2.31.2"),
        .package(url: "https://github.com/harflabs/SwiftVLC", exact: "1.0.0"),
        .package(url: "https://github.com/hmlongco/Factory", exact: "3.3.2"),
        .package(url: "https://github.com/jellyfin/jellyfin-sdk-swift.git", exact: "3.1.0"),
        .package(url: "https://github.com/kean/Get", exact: "2.2.1"),
        .package(url: "https://github.com/kean/Nuke", exact: "13.0.6"),
        .package(url: "https://github.com/kean/Pulse", exact: "5.2.3"),
        .package(url: "https://github.com/kean/PulseLogHandler", exact: "5.1.0"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.14.0"),
        .package(url: "https://github.com/nathantannar4/Engine", exact: "2.12.4"),
        .package(url: "https://github.com/nathantannar4/Transmission", exact: "2.13.4"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths.git", exact: "1.9.0"),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", exact: "1.1.1"),
        .package(url: "https://github.com/sindresorhus/Defaults", exact: "9.0.9"),
        .package(url: "https://github.com/siteline/SwiftUI-Introspect", exact: "26.0.1"),
    ],
    targets: [
        // Inlined rather than referenced as `.package(path: "PreferencesView")`:
        // SwiftPM rejects local path dependencies inside a remotely resolved package.
        .target(
            name: "PreferencesView",
            path: "PreferencesView/Sources/PreferencesView",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
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
                .product(name: "FactoryKit", package: "Factory"),
                .product(name: "Files", package: "Files"),
                .product(name: "Get", package: "Get"),
                .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
                .product(name: "JellyfinAPI", package: "jellyfin-sdk-swift"),
                .product(name: "KeychainSwift", package: "keychain-swift"),
                .product(name: "LNPopupUI-Static", package: "LNPopupUI"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "MPVUI", package: "MPVUI"),
                .product(name: "Mantis", package: "Mantis"),
                .product(name: "MediaAccessibilityKit", package: "MediaAccessibilityKit"),
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
                .product(name: "SwiftVLC", package: "SwiftVLC"),
                .product(name: "Transmission", package: "Transmission"),
            ],
            path: ".",
            exclude: swiftfinTargetExcludes,
            sources: swiftfinTargetSources,
            resources: swiftfinTargetResources,
            swiftSettings: [
                .swiftLanguageMode(.v5),
                // Xcode enables `/regex/` literals by default (SWIFT_ENABLE_BARE_SLASH_REGEX); SwiftPM doesn't.
                .enableUpcomingFeature("BareSlashRegexLiterals"),
            ]
        ),
    ]
)
