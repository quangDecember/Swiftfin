#!/bin/bash
#
# Swiftfin is subject to the terms of the Mozilla Public
# License, v2.0. If a copy of the MPL was not distributed with this
# file, you can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2026 Jellyfin & Jellyfin Contributors
#

# Rebuilds the symlink trees under `Sources/` that let the SwiftPM library
# targets compile the same sources as the Xcode app targets.
#
# Two targets need `Shared/`, and SwiftPM rejects targets with overlapping
# source paths, so each target gets its own directory of links instead of a
# shared path.
#
# Run this after adding, removing or renaming a top-level source directory or an
# asset, then commit the result. Every link is relative, so the tree survives
# cloning; nothing is duplicated.
#
# Usage:
#     Scripts/sync-package-sources.sh

set -euo pipefail

cd "$(dirname "$0")/.."

# Source directories are linked wholesale: SwiftPM walks directory symlinks when
# collecting sources.
#
# Asset catalogs are not, because `actool` does not follow directory symlinks —
# a linked `.xcassets` compiles to nothing at all, silently, and every image
# comes up empty at runtime. Catalogs are therefore mirrored as real directories
# holding links to the individual files.

# repeat_parent <count> — emits "../" <count> times.
repeat_parent() {
    local count="$1" out=""
    while [ "$count" -gt 0 ]; do
        out="../$out"
        count=$((count - 1))
    done
    printf '%s' "$out"
}

# link_tree <source-dir> <destination-dir>
#
# Both paths are relative to the repository root. Mirrors the source's directory
# structure and links each file with a relative path.
link_tree() {
    local src="$1" dst="$2"
    local dst_depth
    dst_depth=$(printf '%s' "$dst" | tr -cd '/' | wc -c)
    dst_depth=$((dst_depth + 1))

    rm -rf "$dst"
    mkdir -p "$dst"

    ( cd "$src" && find . -mindepth 1 -type d -print0 ) |
        while IFS= read -r -d '' dir; do
            mkdir -p "$dst/${dir#./}"
        done

    ( cd "$src" && find . -type f -print0 ) |
        while IFS= read -r -d '' file; do
            local rel="${file#./}"
            local nested
            nested=$(printf '%s' "$rel" | tr -cd '/' | wc -c)
            ln -s "$(repeat_parent $((dst_depth + nested)))$src/$rel" "$dst/$rel"
        done
}

# sync_target <target-name> <platform-source-directory>
sync_target() {
    local target="$1" platform="$2"
    local dir="Sources/$target"

    rm -rf "$dir"
    mkdir -p "$dir"

    ln -s ../../Shared "$dir/Shared"
    ln -s ../../Translations "$dir/Translations"

    for source in Components Extensions Objects Views; do
        ln -s "../../$platform/$source" "$dir/$source"
    done

    link_tree "$platform/Resources/Assets.xcassets" "$dir/Assets.xcassets"

    echo "$target: linked $platform"
}

sync_target SwiftfinIOS "Swiftfin"
sync_target SwiftfinTVOS "Swiftfin tvOS"

# The "Swiftfin tvOS" app target compiles both asset catalogs — its own and the
# iOS one — which is how `Shared` code such as `DeviceType.image` resolves device
# icons that only the iOS catalog defines. SwiftPM gives a target one catalog, so
# the iOS entries are merged in here.
#
# Where both catalogs define an asset, the tvOS one wins, matching actool's
# treatment of the catalogs in the order the app target lists them.
merged="Sources/SwiftfinTVOS/Assets.xcassets"
borrowed=0

for entry in Swiftfin/Resources/Assets.xcassets/*/; do
    name="$(basename "$entry")"

    [ "$name" = "Contents.json" ] && continue
    [ -e "$merged/$name" ] && continue

    link_tree "Swiftfin/Resources/Assets.xcassets/$name" "$merged/$name"
    borrowed=$((borrowed + 1))
done

echo "SwiftfinTVOS: merged $borrowed asset(s) from the iOS catalog"
