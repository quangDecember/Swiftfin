#!/bin/bash
#
# Swiftfin is subject to the terms of the Mozilla Public
# License, v2.0. If a copy of the MPL was not distributed with this
# file, you can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2026 Jellyfin & Jellyfin Contributors
#

# Builds `SwiftfinIOS.xcframework` and `SwiftfinTVOS.xcframework` from the
# SwiftPM library targets, ready to publish as release assets for the binary
# distribution described in `Documentation/swiftpm.md`.
#
# Usage:
#     Scripts/build-xcframework.sh [--platform ios|tvos|all]
#                                  [--output <dir>]
#                                  [--library-evolution]
#                                  [--update-manifest]
#
#     --library-evolution  Build with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`.
#                          Off by default because swift-nio's
#                          `_NIODataStructures` does not compile with library
#                          evolution enabled, and it is a transitive dependency
#                          through Pulse. Without it the frameworks only load in
#                          apps built with the same Swift compiler version.
#     --update-manifest    Rewrite the checksums in `Package.swift` to match the
#                          zips just produced.

set -euo pipefail

cd "$(dirname "$0")/.."
repository="$(pwd)"

platform="all"
output="$repository/build/xcframework"
library_evolution="NO"
update_manifest="no"

while [ $# -gt 0 ]; do
    case "$1" in
        --platform) platform="$2"; shift 2 ;;
        --output) output="$2"; shift 2 ;;
        --library-evolution) library_evolution="YES"; shift ;;
        --update-manifest) update_manifest="yes"; shift ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
done

# `xcodebuild` resolves `Swiftfin.xcodeproj` in preference to `Package.swift`
# when both sit in the same directory, and there is no flag to override that.
# Building from a directory of links to the package's inputs is what lets the
# package's own schemes be addressed at all.
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

for entry in Package.swift Package.resolved Sources Shared Swiftfin "Swiftfin tvOS" \
             Translations PreferencesView; do
    [ -e "$repository/$entry" ] && ln -s "$repository/$entry" "$staging/$entry"
done

# `Package.swift` prefers a locally extracted VLCKit over the hosted zips, and
# looks for it relative to the manifest — which is the staging directory here.
if [ -d "$repository/build/vlckit" ]; then
    mkdir -p "$staging/build"
    ln -s "$repository/build/vlckit" "$staging/build/vlckit"
fi

# Artifacts are replaced, but DerivedData is kept so that re-running after a
# packaging change does not rebuild the whole dependency graph.

# set_manifest_value <variable> <value>
#
# Replaces `let <variable> = ...` in Package.swift. The initial value may be a
# quoted literal or the `placeholderChecksum` identifier, so match to end of
# line, and verify rather than trusting sed's exit status.
set_manifest_value() {
    local variable="$1" value="$2"

    /usr/bin/sed -i '' "s|^let $variable = .*$|let $variable = \"$value\"|" Package.swift

    if ! grep -q "^let $variable = \"$value\"$" Package.swift; then
        echo "failed to set $variable in Package.swift" >&2
        exit 1
    fi

    echo "Package.swift: $variable = $value"
}

rm -rf "$output"/*.xcframework "$output"/*.xcframework.zip "$output"/*.checksum
mkdir -p "$output"

# build_slice <module> <destination> <products-subdirectory>
#
# Emits the path of the assembled framework on stdout.
build_slice() {
    local module="$1" destination="$2" products_dir="$3"
    local derived="$output/DerivedData/$products_dir"
    local log="$output/$module-$products_dir.log"

    echo "==> building $module for $destination" >&2

    SWIFTFIN_XCFRAMEWORK=1 xcodebuild build \
        -scheme "$module" \
        -configuration Release \
        -destination "$destination" \
        -derivedDataPath "$derived" \
        BUILD_LIBRARY_FOR_DISTRIBUTION="$library_evolution" \
        > "$log" 2>&1 || {
            echo "build failed; errors from $log:" >&2
            grep -E "error:" "$log" | sort -u | head -20 >&2
            exit 1
        }

    local products="$derived/Build/Products/Release-$products_dir"
    local framework="$products/PackageFrameworks/$module.framework"

    [ -d "$framework" ] || { echo "no framework at $framework" >&2; exit 1; }

    # SwiftPM emits the `.swiftmodule` beside the framework rather than inside
    # it, and a framework without one cannot be imported.
    #
    # Only this module's own interface goes in. Swift resolves a module `X` as
    # `X.swiftmodule` on an import search path or `X.framework/Modules/X.swiftmodule`
    # on a framework search path, so dependency modules parked in here would
    # never be found — consumers get them from the package graph instead.
    mkdir -p "$framework/Modules"
    cp -R "$products/$module.swiftmodule" "$framework/Modules/"

    # `Bundle.module` looks in the enclosing framework's resource directory, so
    # every package resource bundle — Swiftfin's own and its dependencies' —
    # has to sit inside the framework for images, fonts and translations to
    # resolve at runtime.
    for bundle in "$products"/*.bundle; do
        [ -e "$bundle" ] || continue
        cp -R "$bundle" "$framework/"
    done

    echo "$framework"
}

# build_xcframework <module> <destination>:<products-subdirectory>...
build_xcframework() {
    local module="$1"; shift
    local args=()

    for slice in "$@"; do
        local destination="${slice%%|*}"
        local products_dir="${slice##*|}"
        local framework

        framework="$(build_slice "$module" "$destination" "$products_dir")"
        args+=(-framework "$framework")
    done

    # Without library evolution the slices carry no `.swiftinterface`, and
    # `-create-xcframework` refuses to package them unless the result is marked
    # as internal distribution.
    if [ "$library_evolution" = "NO" ]; then
        args+=(-allow-internal-distribution)
    fi

    rm -rf "$output/$module.xcframework" "$output/$module.xcframework.zip"
    xcodebuild -create-xcframework "${args[@]}" -output "$output/$module.xcframework" > /dev/null

    ( cd "$output" && zip -qry "$module.xcframework.zip" "$module.xcframework" )

    local checksum
    checksum="$(cd "$staging" && swift package compute-checksum "$output/$module.xcframework.zip")"
    echo "$checksum" > "$output/$module.checksum"

    echo "==> $module.xcframework.zip"
    echo "    size:     $(du -h "$output/$module.xcframework.zip" | cut -f1)"
    echo "    checksum: $checksum"
}

cd "$staging"

if [ "$platform" = "all" ] || [ "$platform" = "ios" ]; then
    build_xcframework SwiftfinIOS \
        "generic/platform=iOS|iphoneos" \
        "generic/platform=iOS Simulator|iphonesimulator"
fi

if [ "$platform" = "all" ] || [ "$platform" = "tvos" ]; then
    build_xcframework SwiftfinTVOS \
        "generic/platform=tvOS|appletvos" \
        "generic/platform=tvOS Simulator|appletvsimulator"
fi

cd "$repository"

if [ "$update_manifest" = "yes" ]; then
    for module in SwiftfinIOS SwiftfinTVOS; do
        [ -f "$output/$module.checksum" ] || continue

        case "$module" in
            SwiftfinIOS) variable="swiftfinIOSChecksum" ;;
            SwiftfinTVOS) variable="swiftfinTVOSChecksum" ;;
        esac

        set_manifest_value "$variable" "$(cat "$output/$module.checksum")"
    done
fi

echo
echo "Artifacts in $output"
