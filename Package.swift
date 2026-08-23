// swift-tools-version: 6.2

//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import PackageDescription

// MARK: - Distribution mode

/// Swiftfin ships in two forms:
///
/// - `source` (default): the library is compiled from the sources in this
///   repository. Use this when developing Swiftfin itself.
/// - `binary`: the library is consumed as a pre-built `XCFramework` downloaded
///   from a GitHub release. Use this for fast, dependency-light integration.
///
/// Select the binary form by setting `SWIFTFIN_BINARY` in the environment that
/// evaluates this manifest: `ios`, `tvos`, or `1` for both.
///
/// SwiftPM downloads every `binaryTarget` while resolving, before it knows which
/// platform you are building, so naming one platform is what keeps the other
/// platform's framework off your machine.
///
/// See `Documentation/swiftpm.md` for the full integration guide.
let binaryPlatform = Context.environment["SWIFTFIN_BINARY"]
let useBinaryDistribution = binaryPlatform != nil
let binaryIncludesIOS = binaryPlatform != "tvos"
let binaryIncludesTVOS = binaryPlatform != "ios"

/// The release tag whose `XCFramework` assets back the binary distribution.
/// Set this to the tag being cut before publishing.
let binaryRelease = "0.1.0"

/// Repository hosting the `XCFramework` release assets.
let binaryHost = "https://github.com/quangDecember/Swiftfin/releases/download"

/// When set, this manifest exposes the platform modules as dynamic library
/// products so that `xcodebuild` produces frameworks to bundle into an
/// `XCFramework`, and builds them with library evolution. Set only by
/// `Scripts/build-xcframework.sh`; consumers never see these products.
let buildingXCFramework = Context.environment["SWIFTFIN_XCFRAMEWORK"] == "1"

/// Stands in for a checksum until the matching asset has been published.
let placeholderChecksum = String(repeating: "0", count: 64)

/// Checksums of the hosted `XCFramework` zips, one per platform module.
/// Rewritten by `Scripts/build-xcframework.sh --update-manifest`.
let swiftfinIOSChecksum = placeholderChecksum
let swiftfinTVOSChecksum = placeholderChecksum

// MARK: - VLCKit

// `VLCUI` imports `MobileVLCKit`/`TVVLCKit` but does not declare them as
// dependencies. Declaring them here as binary targets puts the frameworks on the
// search path for the whole package graph, which is enough for `VLCUI` to
// resolve them too.
//
// VideoLAN ships VLCKit as `.tar.xz` archives that nest the framework under a
// `*-binary/` directory, which SwiftPM cannot consume. `Scripts/package-vlckit.sh`
// downloads those archives, repackages them as SwiftPM zips and records the
// checksums below; the zips are published once per VLCKit version.
let vlcKitVersion = "3.7.2"

/// Checksums of the repackaged VLCKit zips.
/// Rewritten by `Scripts/package-vlckit.sh --update-manifest`.
let mobileVLCKitChecksum = "4fc86288a81f126a56b672ecc6ffe9d27d8c396fbb40c89480a98d191aed8041"
let tvVLCKitChecksum = "8e91c7e9eefd769d3898dc57ee957f7cd8888cc312d6d43786fa56a03539339a"

func vlcKitTarget(name: String, checksum: String) -> Target {
    // `Scripts/package-vlckit.sh` leaves the extracted frameworks behind. Using
    // them when they are there keeps the package buildable before the zips have
    // been published, and saves re-downloading VLCKit on a machine that already
    // has it.
    let localPath = "build/vlckit/\(name).xcframework"

    if FileManager.default.fileExists(atPath: "\(Context.packageDirectory)/\(localPath)") {
        return .binaryTarget(name: name, path: localPath)
    }

    return .binaryTarget(
        name: name,
        url: "\(binaryHost)/vlckit-\(vlcKitVersion)/\(name).xcframework.zip",
        checksum: checksum
    )
}

let vlcKitTargets: [Target] = [
    vlcKitTarget(name: "MobileVLCKit", checksum: mobileVLCKitChecksum),
    vlcKitTarget(name: "TVVLCKit", checksum: tvVLCKitChecksum),
]

// MARK: - Shared settings

// The app targets build in Swift 5 language mode (`SWIFT_VERSION = 5.0`), and
// Xcode enables bare slash regex literals for them by default. Both have to be
// requested explicitly here to keep the package compiling the same sources.
let swiftfinSwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v5),
    .enableUpcomingFeature("BareSlashRegexLiterals"),
] + (buildingXCFramework ? [
    // Library evolution is applied to Swiftfin's own modules rather than through
    // `BUILD_LIBRARY_FOR_DISTRIBUTION`, which xcodebuild would force onto every
    // dependency — and swift-nio's `_NIODataStructures` does not compile with it.
    //
    // `-emit-module-interface` is deliberately *not* passed alongside it. The
    // textual interface Swiftfin currently generates does not round-trip:
    //
    //   - `Defaults.Key` prints module-qualified as `Defaults.Defaults.Key`,
    //     which no longer parses, because the `Defaults` module's top-level type
    //     is itself named `Defaults`.
    //   - Opaque returns in public protocol extensions (`TextTransferable`)
    //     print bodies whose branches disagree about `some View` versus `Self`.
    //
    // Nothing consumes that interface today: `-create-xcframework` runs with
    // `-allow-internal-distribution` and the shipped framework carries only a
    // `.swiftmodule`, so emitting it bought nothing while making
    // `SwiftVerifyEmittedModuleInterface` fail the build. Restore the flag once
    // the two issues above are fixed and the interface is actually shipped.
    //
    // This flag is unsafe only in the sense that SwiftPM forbids it in a package
    // resolved as a dependency. `buildingXCFramework` is set solely by
    // `Scripts/build-xcframework.sh`, so consumers never evaluate this branch.
    .unsafeFlags(["-enable-library-evolution"]),
] : [])

/// Files under `Shared/` that do not compile for tvOS.
///
/// These mirror the `PBXFileSystemSynchronizedBuildFileExceptionSet` for the
/// "Swiftfin tvOS" target in `Swiftfin.xcodeproj`. Keep the two lists in sync:
/// the app target and this target compile the same sources.
let tvOSExcludedSharedSources = [
    "Shared/Extensions/JellyfinAPI/TaskTriggerInfoType.swift",
    "Shared/ViewModels/AdminDashboard/APIKeysViewModel.swift",
    "Shared/ViewModels/AdminDashboard/DevicesViewModel.swift",
    "Shared/ViewModels/AdminDashboard/ServerActivityDetailViewModel.swift",
    "Shared/ViewModels/AdminDashboard/ServerLogs/ServerLogsViewModel.swift",
    "Shared/ViewModels/AdminDashboard/ServerTaskObserver.swift",
    "Shared/ViewModels/AdminDashboard/ServerTasksViewModel.swift",
    "Shared/ViewModels/AdminDashboard/Users/AddServerUserViewModel.swift",
    "Shared/ViewModels/AdminDashboard/Users/ServerUsersViewModel.swift",
    "Shared/ViewModels/DownloadListViewModel.swift",
    "Shared/ViewModels/ItemAdministration/IdentifyItemViewModel.swift",
    "Shared/ViewModels/ItemAdministration/RemoteImageInfoViewModel.swift",
    "Shared/ViewModels/QuickConnectAuthorizeViewModel.swift",
    "Shared/Views/VideoPlayer/Components/Toolbar/ActionButtons/GestureLockActionButton.swift",
]

let swiftfinResources: [Resource] = [
    .process("Assets.xcassets"),
    .process("Shared/Resources"),
    .process("Translations"),
]

/// Dependencies shared by both platform targets.
let commonDependencies: [Target.Dependency] = [
    .product(name: "Algorithms", package: "swift-algorithms"),
    .product(name: "BlurHashKit", package: "BlurHashKit"),
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
    .product(name: "Logging", package: "swift-log"),
    .product(name: "Nuke", package: "Nuke"),
    .product(name: "NukeUI", package: "Nuke"),
    .product(name: "OrderedCollections", package: "swift-collections"),
    .product(name: "Pulse", package: "Pulse"),
    .product(name: "PulseLogHandler", package: "PulseLogHandler"),
    .product(name: "PulseUI", package: "Pulse"),
    .product(name: "SVGKit", package: "SVGKit"),
    .product(name: "StatefulMacros", package: "StatefulMacro"),
    .product(name: "SwiftUIIntrospect", package: "SwiftUI-Introspect"),
    .product(name: "Transmission", package: "Transmission"),
    .product(name: "VLCUI", package: "VLCUI"),
    "PreferencesView",
]

// MARK: - Targets

/// Source-built platform targets.
///
/// `Shared/` is symlinked into both, because SwiftPM refuses to let two targets
/// declare overlapping source paths. `Shared/` cannot be lifted into a target of
/// its own: it references platform-specific types such as `AdminDashboardView`,
/// so it has to compile alongside exactly one platform's sources.
let sourceTargets: [Target] = [
    // Inlined rather than referenced as a path dependency, so that both
    // distribution modes have one self-contained target graph.
    // `PreferencesView/Package.swift` declares tools version 5.9, so the
    // language mode has to be restated here.
    .target(
        name: "PreferencesView",
        path: "PreferencesView/Sources/PreferencesView",
        swiftSettings: [.swiftLanguageMode(.v5)]
    ),
    .target(
        name: "SwiftfinIOS",
        dependencies: commonDependencies + [
            // Conditioned as well as being on an iOS-only target: an external
            // product without a condition still gets built for every platform
            // the package supports, and Mantis does not compile for tvOS.
            .product(name: "Mantis", package: "Mantis", condition: .when(platforms: [.iOS])),
            .target(name: "MobileVLCKit", condition: .when(platforms: [.iOS])),
        ],
        resources: swiftfinResources,
        swiftSettings: swiftfinSwiftSettings
    ),
    .target(
        name: "SwiftfinTVOS",
        dependencies: commonDependencies + [
            .product(name: "TVOSPicker", package: "TVOSPicker", condition: .when(platforms: [.tvOS])),
            .target(name: "TVVLCKit", condition: .when(platforms: [.tvOS])),
        ],
        exclude: tvOSExcludedSharedSources,
        resources: swiftfinResources,
        swiftSettings: swiftfinSwiftSettings
    ),
    .target(
        name: "Swiftfin",
        dependencies: [
            .target(name: "SwiftfinIOS", condition: .when(platforms: [.iOS])),
            .target(name: "SwiftfinTVOS", condition: .when(platforms: [.tvOS])),
        ],
        swiftSettings: [.swiftLanguageMode(.v5)]
    ),
] + vlcKitTargets

/// Prefers an `XCFramework` built locally by `Scripts/build-xcframework.sh`, so
/// a release can be exercised end to end before it is published.
func swiftfinBinaryTarget(name: String, checksum: String) -> Target {
    let localPath = "build/xcframework/\(name).xcframework"

    if FileManager.default.fileExists(atPath: "\(Context.packageDirectory)/\(localPath)") {
        return .binaryTarget(name: name, path: localPath)
    }

    return .binaryTarget(
        name: name,
        url: "\(binaryHost)/\(binaryRelease)/\(name).xcframework.zip",
        checksum: checksum
    )
}

/// Pre-built distribution.
///
/// The platform modules arrive as `XCFramework`s; the `Swiftfin` umbrella stays
/// a source target so that `import Swiftfin` keeps working and consumers do not
/// have to branch on the platform themselves. It is a handful of
/// `@_exported import` lines, so there is nothing to gain from shipping it as a
/// binary too.
let binaryTargets: [Target] = [
    // Compiled from source even in binary mode: it is a handful of files, and
    // the umbrella's `@_exported import` needs the module on the search path.
    .target(
        name: "PreferencesView",
        path: "PreferencesView/Sources/PreferencesView",
        swiftSettings: [.swiftLanguageMode(.v5)]
    ),
] +
    (binaryIncludesIOS ? [
        swiftfinBinaryTarget(name: "SwiftfinIOS", checksum: swiftfinIOSChecksum),
        vlcKitTarget(name: "MobileVLCKit", checksum: mobileVLCKitChecksum),
    ] : []) +
    (binaryIncludesTVOS ? [
        swiftfinBinaryTarget(name: "SwiftfinTVOS", checksum: swiftfinTVOSChecksum),
        vlcKitTarget(name: "TVVLCKit", checksum: tvVLCKitChecksum),
    ] : []) + [
        .target(
            name: "Swiftfin",
            dependencies: commonDependencies +
                (binaryIncludesIOS ? [
                    Target.Dependency.target(name: "SwiftfinIOS", condition: .when(platforms: [.iOS])),
                    .target(name: "MobileVLCKit", condition: .when(platforms: [.iOS])),
                    .product(name: "Mantis", package: "Mantis", condition: .when(platforms: [.iOS])),
                ] : []) +
                (binaryIncludesTVOS ? [
                    Target.Dependency.target(name: "SwiftfinTVOS", condition: .when(platforms: [.tvOS])),
                    .target(name: "TVVLCKit", condition: .when(platforms: [.tvOS])),
                    .product(name: "TVOSPicker", package: "TVOSPicker", condition: .when(platforms: [.tvOS])),
                ] : []),
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]

let package = Package(
    name: "Swiftfin",
    defaultLocalization: "en",
    platforms: [
        .iOS("18.6"),
        .tvOS("26.1"),
    ],
    products: [
        .library(
            name: "Swiftfin",
            targets: ["Swiftfin"]
        ),
    ] + (buildingXCFramework ? [
        .library(name: "SwiftfinIOS", type: .dynamic, targets: ["SwiftfinIOS"]),
        .library(name: "SwiftfinTVOS", type: .dynamic, targets: ["SwiftfinTVOS"]),
    ] : []),
    // Pinned exactly to the versions in
    // `Swiftfin.xcodeproj/.../Package.resolved`, so the library compiles the
    // same dependency sources the shipping apps do. A `Package.resolved` of a
    // *dependency* is ignored by SwiftPM — only exact pins give consumers
    // parity with the app.
    //
    // `CollectionHStack` and `CollectionVGrid` publish no tags at all, so they
    // can only be referenced by branch. That is what stops this package from
    // being consumable via a version tag; see `Documentation/swiftpm.md`.
    dependencies: [
        // CoreStore 9.3.0 does not compile under Xcode 27 ("ambiguous use of
        // 'cs_sync'"). Upstream fixed it in be977e2 but has not tagged a
        // release since, so the fix has to be pinned by revision.
        .package(
            url: "https://github.com/JohnEstropia/CoreStore.git",
            revision: "be977e255ba7e6bb089337b38b5b194f86923f40"
        ),
        .package(url: "https://github.com/JohnSundell/Files", exact: "4.3.0"),
        .package(url: "https://github.com/LePips/BlurHashKit", exact: "2.0.0"),
        .package(url: "https://github.com/LePips/CollectionHStack", branch: "main"),
        .package(url: "https://github.com/LePips/CollectionVGrid", branch: "main"),
        .package(url: "https://github.com/LePips/StatefulMacro", exact: "0.1.7"),
        .package(url: "https://github.com/LePips/VLCUI", exact: "0.8.1"),
        .package(url: "https://github.com/SVGKit/SVGKit", exact: "3.0.0"),
        .package(url: "https://github.com/ViacomInc/TVOSPicker", exact: "0.3.0"),
        .package(url: "https://github.com/apple/swift-algorithms.git", exact: "1.2.1"),
        .package(url: "https://github.com/apple/swift-collections.git", exact: "1.6.0"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.14.0"),
        .package(url: "https://github.com/evgenyneu/keychain-swift", exact: "24.0.0"),
        .package(url: "https://github.com/guoyingtao/Mantis", exact: "2.31.2"),
        .package(url: "https://github.com/hmlongco/Factory", exact: "3.3.2"),
        .package(url: "https://github.com/jellyfin/jellyfin-sdk-swift.git", exact: "3.0.0"),
        .package(url: "https://github.com/kean/Get", exact: "2.2.1"),
        .package(url: "https://github.com/kean/Nuke", exact: "13.0.6"),
        .package(url: "https://github.com/kean/Pulse", exact: "5.2.3"),
        .package(url: "https://github.com/kean/PulseLogHandler", exact: "5.1.0"),
        .package(url: "https://github.com/nathantannar4/Engine", exact: "2.12.4"),
        .package(url: "https://github.com/nathantannar4/Transmission", exact: "2.13.4"),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", exact: "1.1.1"),
        .package(url: "https://github.com/siteline/SwiftUI-Introspect", exact: "26.0.1"),
        .package(url: "https://github.com/sindresorhus/Defaults", exact: "9.0.9"),
    ],
    targets: useBinaryDistribution ? binaryTargets : sourceTargets
)
