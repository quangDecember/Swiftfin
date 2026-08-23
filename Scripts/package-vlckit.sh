#!/bin/bash
#
# Swiftfin is subject to the terms of the Mozilla Public
# License, v2.0. If a copy of the MPL was not distributed with this
# file, you can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2026 Jellyfin & Jellyfin Contributors
#

# Repackages VLCKit into the layout a SwiftPM `binaryTarget` expects: a zip with
# the `.xcframework` at its root.
#
# VideoLAN distributes VLCKit as `.tar.xz` archives that nest the framework
# under a `*-binary/` directory. CocoaPods and Carthage both know how to unwrap
# that; SwiftPM does not, so the archives are repackaged here and uploaded as
# release assets.
#
# This replaces what `carthage bootstrap` used to do for the package. The
# extracted framework is byte-for-byte the one Carthage produced — Carthage was
# only ever downloading and unpacking these same archives.
#
# Run this once per VLCKit version, then upload the zips to the release tag
# named below and commit the checksums.
#
# Usage:
#     Scripts/package-vlckit.sh [--version <x.y.z>] [--output <dir>] [--update-manifest]

set -euo pipefail

cd "$(dirname "$0")/.."
repository="$(pwd)"

version="3.7.2"
output="$repository/build/vlckit"
update_manifest="no"

while [ $# -gt 0 ]; do
    case "$1" in
        --version) version="$2"; shift 2 ;;
        --output) output="$2"; shift 2 ;;
        --update-manifest) update_manifest="yes"; shift ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
done


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

mkdir -p "$output"

manifest_base="https://code.videolan.org/videolan/VLCKit/raw/master/Packaging"

# archive_url <framework>
#
# VideoLAN's per-framework JSON maps a version to its download. It is the same
# manifest `Cartfile` used to point at. code.videolan.org throttles repeated
# requests, so this retries rather than failing the whole run.
archive_url() {
    local framework="$1" attempt=1 manifest=""

    while [ "$attempt" -le 5 ]; do
        manifest="$(curl -fsSL --retry 3 --retry-delay 2 "$manifest_base/$framework.json" || true)"

        if [ -n "$manifest" ]; then
            printf '%s' "$manifest" | /usr/bin/python3 -c "
import json, sys

versions = json.load(sys.stdin)
url = versions.get('$version')

if url is None:
    sys.exit('$framework $version not published; available: ' + ', '.join(list(versions)[:5]))

print(url)
" && return 0
        fi

        sleep $((attempt * 3))
        attempt=$((attempt + 1))
    done

    echo "could not read $manifest_base/$framework.json" >&2
    return 1
}

for framework in MobileVLCKit TVVLCKit; do
    url="$(archive_url "$framework")"

    echo "==> $framework $version"
    echo "    source: $url"

    work="$(mktemp -d)"

    curl -fL --retry 3 --retry-delay 2 -o "$work/$framework.tar.xz" "$url"

    # The framework sits one directory down, under `<name>-binary/`.
    tar -xJf "$work/$framework.tar.xz" -C "$work" "*/$framework.xcframework"

    extracted="$(find "$work" -type d -name "$framework.xcframework" -maxdepth 3 | head -1)"

    if [ -z "$extracted" ]; then
        echo "    no $framework.xcframework inside the archive" >&2
        rm -rf "$work"
        exit 1
    fi

    rm -rf "$output/$framework.xcframework" "$output/$framework.xcframework.zip"
    mv "$extracted" "$output/$framework.xcframework"
    rm -rf "$work"

    ( cd "$output" && zip -qry "$framework.xcframework.zip" "$framework.xcframework" )

    checksum="$(swift package compute-checksum "$output/$framework.xcframework.zip")"
    echo "$checksum" > "$output/$framework.checksum"

    echo "    size:     $(du -h "$output/$framework.xcframework.zip" | cut -f1)"
    echo "    checksum: $checksum"
done

if [ "$update_manifest" = "yes" ]; then
    for framework in MobileVLCKit TVVLCKit; do
        case "$framework" in
            MobileVLCKit) variable="mobileVLCKitChecksum" ;;
            TVVLCKit) variable="tvVLCKitChecksum" ;;
        esac

        set_manifest_value "$variable" "$(cat "$output/$framework.checksum")"
    done

    set_manifest_value vlcKitVersion "$version"
fi

echo
echo "Upload both zips to the 'vlckit-$version' release tag:"
echo
echo "    gh release create vlckit-$version --title 'VLCKit $version' --notes 'SwiftPM-packaged VLCKit $version.' \\"
echo "        $output/MobileVLCKit.xcframework.zip $output/TVVLCKit.xcframework.zip"
echo
echo "The checksums above match these exact files. Rebuilding the zips elsewhere"
echo "will produce different bytes, so upload these rather than regenerating."
echo
echo "The extracted frameworks stay in $output. Package.swift uses them in place"
echo "of the hosted zips while they are there, so the package builds before the"
echo "release exists."
