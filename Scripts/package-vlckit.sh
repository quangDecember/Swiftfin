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
# Zipping is not reproducible: repackaging the same VLCKit release twice yields
# different bytes and so a different checksum. Whatever zips get uploaded must
# be the ones whose checksums are in `Package.swift`, so prefer doing both in
# one run rather than as separate steps.
#
# Usage:
#     Scripts/package-vlckit.sh [--version <x.y.z>] [--output <dir>]
#                               [--reuse] [--update-manifest] [--publish]
#
#     --reuse            Keep zips already in the output directory instead of
#                        re-downloading. Their checksums are what
#                        `--update-manifest` and `--publish` then use.
#     --update-manifest  Write the checksums into `Package.swift`.
#     --publish          Upload the zips to the `vlckit-<version>` release,
#                        creating it if needed.

set -euo pipefail

cd "$(dirname "$0")/.."
repository="$(pwd)"

version="3.7.2"
output="$repository/build/vlckit"
reuse="no"
update_manifest="no"
publish="no"

while [ $# -gt 0 ]; do
    case "$1" in
        --version) version="$2"; shift 2 ;;
        --output) output="$2"; shift 2 ;;
        --reuse) reuse="yes"; shift ;;
        --update-manifest) update_manifest="yes"; shift ;;
        --publish) publish="yes"; shift ;;
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

# checksum_variable <framework>
checksum_variable() {
    case "$1" in
        MobileVLCKit) echo "mobileVLCKitChecksum" ;;
        TVVLCKit) echo "tvVLCKitChecksum" ;;
    esac
}

# The host repository is whatever `binaryHost` in Package.swift points at, so
# uploads land where the manifest will download from. `gh` on its own would
# resolve to `origin`, which for a fork is upstream.
host_repo="$(
    grep '^let binaryHost = ' Package.swift |
        /usr/bin/sed -E 's|.*github\.com/([^/]+/[^/]+)/releases.*|\1|'
)"

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
    zip_path="$output/$framework.xcframework.zip"

    if [ "$reuse" = "yes" ] && [ -f "$zip_path" ]; then
        echo "==> $framework $version (reusing existing zip)"
    else
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

        rm -rf "$output/$framework.xcframework" "$zip_path"
        mv "$extracted" "$output/$framework.xcframework"
        rm -rf "$work"

        ( cd "$output" && zip -qry "$framework.xcframework.zip" "$framework.xcframework" )
    fi

    checksum="$(swift package compute-checksum "$zip_path")"
    echo "$checksum" > "$output/$framework.checksum"

    echo "    size:     $(du -h "$zip_path" | cut -f1)"
    echo "    checksum: $checksum"
done

if [ "$update_manifest" = "yes" ]; then
    echo

    for framework in MobileVLCKit TVVLCKit; do
        set_manifest_value "$(checksum_variable "$framework")" "$(cat "$output/$framework.checksum")"
    done

    set_manifest_value vlcKitVersion "$version"
fi

if [ "$publish" = "yes" ]; then
    echo
    echo "==> publishing vlckit-$version to $host_repo"

    gh release view "vlckit-$version" --repo "$host_repo" >/dev/null 2>&1 ||
        gh release create "vlckit-$version" \
            --repo "$host_repo" \
            --title "VLCKit $version" \
            --notes "SwiftPM-packaged VLCKit $version, repackaged from VideoLAN's official archives by Scripts/package-vlckit.sh."

    gh release upload "vlckit-$version" \
        --repo "$host_repo" \
        --clobber \
        "$output/MobileVLCKit.xcframework.zip" \
        "$output/TVVLCKit.xcframework.zip"

    echo "    uploaded"
fi

# The zips on disk, the checksums in the manifest and the assets on the release
# all have to agree. Say so plainly when they do not — otherwise the mismatch
# surfaces much later as an opaque resolution failure.
echo

mismatch="no"

for framework in MobileVLCKit TVVLCKit; do
    variable="$(checksum_variable "$framework")"

    if ! grep -q "^let $variable = \"$(cat "$output/$framework.checksum")\"$" Package.swift; then
        mismatch="yes"
    fi
done

if [ "$mismatch" = "yes" ]; then
    cat >&2 <<EOF
Package.swift does not match the zips in
$output

Zipping is not reproducible, so these zips differ from whichever ones the
manifest was last updated from. Record these checksums and upload these exact
files in one go:

    Scripts/package-vlckit.sh --reuse --update-manifest --publish
EOF
    exit 1
fi

if [ "$publish" = "no" ]; then
    cat <<EOF
Package.swift matches these zips. Nothing has been uploaded — this run only
prepared the files. To upload them:

    Scripts/package-vlckit.sh --reuse --publish
EOF
else
    echo "Package.swift, the zips and the vlckit-$version release all agree."
fi

cat <<EOF

The extracted frameworks stay in
$output
Package.swift uses them in place of the hosted zips while they are there, so the
package builds locally before the release exists.
EOF
