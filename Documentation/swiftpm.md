# Swiftfin as a Swift Package

`Package.swift` builds the iOS app's `Shared` and `Swiftfin` sources (everything except
`Swiftfin/App`) as the `SwiftfinLib` library, so another app can embed Swiftfin.

- iOS 18.0+ (the app itself targets 18.6). Five dependencies — SwiftVLC, MPVUI, MediaAccessibilityKit, CollectionHStack and CollectionVGrid — require iOS 18, so consumers must target at least 18.0.
- Verified with Xcode 27 (Swift 6.4).
- Dependency versions mirror `Swiftfin.xcodeproj`'s `Package.resolved`.

```swift
.package(url: "https://github.com/quangDecember/Swiftfin", branch: "swiftpm-test-4"),
// target:
.product(name: "SwiftfinLib", package: "Swiftfin"),
```

`CollectionHStack` and `CollectionVGrid` are pinned by revision, so SwiftPM only accepts
this package by `branch:` or `revision:`, not by version.

To build the package itself from the command line (a plain `xcodebuild` in the repository
root picks `Swiftfin.xcodeproj` instead):

```bash
xcodebuild -workspace .swiftpm/xcode/package.xcworkspace -scheme Swiftfin -destination 'generic/platform=iOS' build
```

## Public API

| API | Purpose |
| --- | --- |
| `SwiftfinScene()` | The whole app as a `Scene`. Calls `configure()`. |
| `SwiftfinView()` | The whole app as a `View`, for presenting inside your own scene. Restores the key window's tint and appearance when it disappears. |
| `RootView()` | Swiftfin's root without the toast/preferences/local-authentication wrappers. |
| `SwiftfinLibrary.configure()` | Logging, Core Data, image pipeline, fonts. Idempotent. |
| `SwiftfinLibrary.movieExists(matching:)` / `firstMovie(matching:)` | Search the signed-in user's library by `.tmdbID` or `.keyword`. Restores the stored session if needed; throws `SwiftfinMoviePlaybackError.noCurrentUserSession` when nobody is signed in. Overloads taking a `JellyfinClient` skip the session. |
| `SwiftfinLibrary.moviePlayer(for:)` / `moviePlayer(matching:)` | `SwiftfinMoviePlayerView` that plays a movie full screen. |
| `SwiftfinAppValueObservation` | Deprecated no-op, kept for source compatibility with the `swiftpm` branch. |

## Differences from the app target

- `SWIFT_ENABLE_BARE_SLASH_REGEX` is on by default in Xcode; the package enables the
  `BareSlashRegexLiterals` feature instead.
- `PreferencesView` is inlined as a target, because SwiftPM rejects local path
  dependencies inside a remotely resolved package.
- The app's `UIAppFonts` entry is replaced by registering the bundled font in `configure()`.
- `CoreStore` points at a fork of 9.3.0 that fixes an ambiguous `cs_sync` overload
  rejected by the Swift 6.4 compiler. The app project uses the same revision.
