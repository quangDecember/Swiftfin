# Swiftfin as a Library

Swiftfin builds as a Swift package as well as an app. A host app can embed the
whole Swiftfin experience, or drop straight into playback for a single movie.

The package ships in two forms:

| | Source | Binary |
| --- | --- | --- |
| Swiftfin's own ~700 files | Compiled by you | Pre-built `XCFramework` |
| Dependencies | Compiled by you | Compiled by you |
| Toolchain | Any Xcode that can build Swiftfin | Same or newer compatible Swift compiler |
| Debuggable | Yes, sources are right there | Dependencies only |

Use **source** while working on Swiftfin itself, and **binary** to integrate a
release into another app.

## Products

One product, `Swiftfin`, on iOS 18.6+ and tvOS 26.1+:

```swift
import Swiftfin
```

Behind it are two platform modules, `SwiftfinIOS` and `SwiftfinTVOS`, selected by
a platform condition and re-exported by the `Swiftfin` umbrella. They exist
because Swiftfin's iOS and tvOS sources define overlapping types — `VideoPlayer`,
`GestureView`, `Stepper` and others — and cannot share a module. Only the module
matching the platform you build for is compiled; you never name them yourself.

## Source integration

`CollectionHStack` and `CollectionVGrid` publish no version tags, and SwiftPM
forbids a version-pinned package from depending on branch-pinned ones. So the
source form has to be referenced by branch or revision:

```swift
dependencies: [
    .package(url: "https://github.com/quangDecember/Swiftfin.git", branch: "main"),
]
```

Pin a `revision:` instead if you want a build that does not move.

Every other dependency is pinned to an exact version matching
`Swiftfin.xcodeproj`'s `Package.resolved`, so the library compiles the same
dependency sources the shipping apps do.

### VLCKit

Swiftfin plays media through VLCKit, which arrives as prebuilt `XCFramework`s
from this repository's `vlckit-3.7.2` release tag. Nothing else is needed — the
package does not use Carthage.

VideoLAN distributes VLCKit as `.tar.xz` archives that nest the framework under
a `*-binary/` directory, which SwiftPM cannot consume.
`Scripts/package-vlckit.sh` downloads those archives, repackages them as SwiftPM
zips and records their checksums:

```bash
Scripts/package-vlckit.sh --update-manifest --publish
```

Run that once per VLCKit version. It downloads, repackages, records the
checksums and uploads to the `vlckit-<version>` tag — targeting the repository
`binaryHost` names, since `gh` on a fork resolves to upstream unless told
otherwise.

Do all three in one run. Zipping is not reproducible: repackaging the same
VLCKit release twice produces different bytes and a different checksum, so
uploading a zip that was not the one the manifest recorded fails resolution
with a checksum mismatch. The script refuses to finish if the zips on disk and
`Package.swift` disagree, and `--reuse` lets a later run publish the same zips
rather than rebuilding them. It also leaves the extracted frameworks in
`build/vlckit`, and `Package.swift` prefers those over the hosted zips while
they are there — so the package builds before the zips have been published, and
a machine that already has VLCKit does not re-download it.

> The Xcode **app** targets still link VLCKit through Carthage; only the package
> has moved off it. `Documentation/contributing.md` still applies for app
> development.

## Binary integration

Add the package and set `SWIFTFIN_BINARY` in the environment that evaluates the
manifest — `ios`, `tvos`, or `1` for both:

```bash
SWIFTFIN_BINARY=ios xcodebuild -scheme YourApp build
```

The manifest then replaces Swiftfin's own source targets with `XCFramework`
binary targets.

The iOS and tvOS frameworks are separate release zips. Name a single platform
when you only ship one: SwiftPM downloads every `binaryTarget` while resolving,
before it knows what you are building for, so `SWIFTFIN_BINARY=1` fetches both
platforms' frameworks and both VLCKit builds.

If `build/xcframework/SwiftfinIOS.xcframework` exists locally it is used instead
of the release download, so a release can be exercised before it is published.

Every framework slice carries a verified `.swiftinterface`. A consumer can
therefore use a newer compatible Swift compiler instead of requiring the exact
compiler-specific `.swiftmodule` that produced the release.

### Dependency boundary

Swiftfin and its implementation dependencies are statically linked into each
dynamic framework. A textual interface still has to name modules used by
Swiftfin's public API, so the package keeps those products available to the
consumer. Modules that are implementation details do not need to be exposed by
the interface.

Library evolution is applied only to `SwiftfinIOS` and `SwiftfinTVOS` with
target-specific Swift flags. `BUILD_LIBRARY_FOR_DISTRIBUTION` is deliberately
left off because Xcode propagates it to the entire graph and the current
swift-nio `_NIODataStructures` target does not compile with it.

One consequence to be aware of: the dependencies end up in the app twice — once
statically linked inside `SwiftfinIOS.framework`, once compiled by you. They
link and run, and Swift resolves types by mangled name so the two agree, but
anything that relies on process-wide uniqueness (Objective-C class registration,
`static let` singletons) exists twice. Source integration has no such split.

## Using the library

### Embedding the whole app

```swift
import Swiftfin
import SwiftUI

@main
struct HostApp: App {

    var body: some Scene {
        SwiftfinScene()
    }
}
```

`SwiftfinScene` owns its window and calls `SwiftfinLibrary.configure()` for you.

To place Swiftfin inside a scene you already own, present `SwiftfinRootView` and
configure the library yourself:

```swift
@main
struct HostApp: App {

    init() {
        SwiftfinLibrary.configure()
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                MyOwnView()
                SwiftfinRootView()
            }
        }
    }
}
```

`SwiftfinLibrary.configure()` sets up logging, the Core Data stack, the image
pipeline, UIKit appearance and Spotlight indexing. It is safe to call more than
once, and must run before any Swiftfin view is presented. It touches UIKit
appearance proxies, so it is `@MainActor`; `App.init()` already satisfies that.

### Playing a single movie

Look a movie up by TMDB id or by keyword, then present a player. Both require a
signed-in user session, which the Swiftfin UI establishes.

```swift
import JellyfinAPI
import Swiftfin

if try await SwiftfinLibrary.movieExists(matching: .tmdbID("27205")) {
    // ...
}

let movie: BaseItemDto? = try await SwiftfinLibrary.firstMovie(
    matching: .keyword("Inception")
)
```

```swift
struct PlayerView: View {

    var body: some View {
        SwiftfinLibrary.moviePlayer(matching: .tmdbID("27205"))
    }
}
```

`moviePlayer(matching:)` resolves the lookup itself, showing a progress
indicator while it works and a message if nothing matches. Use
`moviePlayer(for:)` when you already hold a `BaseItemDto`.

Pass a `JellyfinClient` to the lookup calls to query a server other than the
signed-in one.

Jellyfin offers no query for provider ids, so `.tmdbID` pages through the
server's movies and matches locally. `.keyword` is a single request and is much
cheaper.

### What does not carry over

Alternate app icons are addressed through `setAlternateIconName`, which only
reads icons from the host app's own bundle. The package therefore omits the app
icon sets from its compiled resource catalog; including them added roughly 85 MB
per device framework while still being unusable by the host. The matching
top-level `AppIcon-*.imageset` previews are omitted too: preserving their vector
representations accounted for most of that compiled size. A host that offers an
icon picker must provide both the alternate icons and any preview images it uses
in its own asset catalog, plus the icon declarations in `Info.plist`.

## Working on the package

`Sources/SwiftfinIOS` and `Sources/SwiftfinTVOS` are trees of symlinks, not
copies. Two targets both need `Shared/`, and SwiftPM rejects targets whose source
paths overlap, so each gets its own directory of links.

Rebuild them after adding, removing or renaming a top-level source directory or
an asset:

```bash
Scripts/sync-package-sources.sh
```

Asset catalogs are mirrored file by file rather than linked wholesale, because
`actool` does not follow directory symlinks — a linked `.xcassets` compiles to
nothing at all, silently, and every image comes up empty at runtime. The sync
script removes `AppIcons` and the `AppIcon-*.imageset` previews from these
mirrors after linking them; it never edits the app targets' original catalogs.

Two lists have to stay in step with `Swiftfin.xcodeproj` by hand:

- `tvOSExcludedSharedSources` in `Package.swift` mirrors the tvOS target's
  `PBXFileSystemSynchronizedBuildFileExceptionSet`.
- The tvOS target merges the iOS asset catalog, because the "Swiftfin tvOS" app
  target compiles both catalogs and `Shared` code such as `DeviceType.image`
  depends on icons only the iOS catalog defines.

`xcodebuild` at the repository root resolves `Swiftfin.xcodeproj` rather than
`Package.swift`, and offers no flag to override that. To build the package
directly, use a host app or a scratch package that depends on it by path;
`Scripts/build-xcframework.sh` sidesteps it with a staging directory of links.

## Cutting a binary release

Publishing is two-phase, and it has to be. `Package.swift` must carry the
checksum of an asset that does not exist until it has been built and uploaded,
so the manifest cannot be correct at the moment the version tag is created.

Rather than tagging and then moving the tag, the frameworks live on their own
immutable `binaries-<version>` release, and the manifest at the version tag
points at it.

### With GitHub Actions

`workflow_dispatch` workflows are only dispatchable once the file exists on the
repository's **default branch** — GitHub will not offer a workflow it cannot see
there, whatever `--ref` you pass. So the branch carrying this work has to reach
your fork's default branch before the workflow can be run at all.

On a fork, also check Settings → Actions → General: Actions are disabled by
default on forks, and workflow permissions must be **Read and write** for the
release upload and pull request to succeed.

1. Run the **XCFramework 📦** workflow against the branch you are releasing:

   ```bash
   gh workflow run xcframework.yml --repo <owner>/Swiftfin \
       --ref <branch> -f version=0.2.0
   ```

   It builds both platforms, uploads two independent zips to a
   `binaries-0.2.0` prerelease, and opens a pull request against `<branch>`
   updating `binaryRelease` and both checksums.
2. Review and merge that pull request.
3. Tag the merge commit and push:

   ```bash
   git tag 0.2.0 && git push <remote> 0.2.0
   ```

Consumers resolve `0.2.0`, read the checksums from the manifest at that tag, and
download the assets from `binaries-0.2.0`. The release branch never has to be the
default branch — only the workflow file does.

### By hand

```bash
Scripts/build-xcframework.sh --update-manifest
```

Then upload `build/xcframework/*.xcframework.zip` to a `binaries-<version>`
release on the repository `binaryHost` points at — pass `--repo`, since `gh`
resolves to upstream on a fork — set `binaryRelease` in `Package.swift` to that
tag, commit, and tag the version. Note the Xcode version in the release notes.
The build fails if any device or simulator slice does not contain a verified
`.swiftinterface`.

The checksums match the exact zips the script produced. Rebuilding them
elsewhere yields different bytes, so upload those files rather than
regenerating.

VLCKit is versioned separately and only needs republishing when its version
changes; see [VLCKit](#vlckit).
