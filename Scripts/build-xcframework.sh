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
#                                  [--update-manifest]
#
#     --update-manifest    Rewrite the checksums in `Package.swift` to match the
#                          zips just produced.
#     --ignore-local-vlckit
#                          Resolve VLCKit from its published zips even when
#                          `build/vlckit` exists locally. This is what CI does,
#                          so use it to reproduce a CI failure on your machine.

set -euo pipefail

cd "$(dirname "$0")/.."
repository="$(pwd)"

platform="all"
output="$repository/build/xcframework"
update_manifest="no"
ignore_local_vlckit="no"

while [ $# -gt 0 ]; do
    case "$1" in
        --platform) platform="$2"; shift 2 ;;
        --output) output="$2"; shift 2 ;;
        --update-manifest) update_manifest="yes"; shift ;;
        --ignore-local-vlckit) ignore_local_vlckit="yes"; shift ;;
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
if [ -d "$repository/build/vlckit" ] && [ "$ignore_local_vlckit" = "no" ]; then
    mkdir -p "$staging/build"
    ln -s "$repository/build/vlckit" "$staging/build/vlckit"
    using_local_vlckit="yes"
else
    using_local_vlckit="no"
fi

# Without a local copy, resolution downloads VLCKit from the release named in
# `Package.swift`. That release is published separately and is easy to forget,
# and xcodebuild reports its absence only as "Could not resolve package
# dependencies" — so check it up front and say what to do about it.
if [ "$using_local_vlckit" = "no" ]; then
    vlckit_version="$(grep '^let vlcKitVersion = ' Package.swift | /usr/bin/sed -E 's|.*"(.*)".*|\1|')"
    vlckit_base="$(
        grep '^let binaryHost = ' Package.swift | /usr/bin/sed -E 's|.*"(.*)".*|\1|'
    )/vlckit-$vlckit_version"

    for framework in MobileVLCKit TVVLCKit; do
        status="$(curl -sIL -o /dev/null -w '%{http_code}' "$vlckit_base/$framework.xcframework.zip" || echo 000)"

        if [ "$status" != "200" ]; then
            cat >&2 <<EOF
$framework.xcframework.zip is not published ($vlckit_base returned $status).

VLCKit is hosted separately from Swiftfin's own frameworks and has to be
published once per VLCKit version:

    Scripts/package-vlckit.sh --update-manifest

then upload the two zips it produces to the vlckit-$vlckit_version release tag.
The script prints the exact command.
EOF
            exit 1
        fi
    done
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

# Turns xcodebuild's firehose into a readable progress stream on stderr.
#
# A release build takes about twenty minutes per slice and its full output runs
# to ~11MB, so the log goes to a file and only milestones reach the terminal.
# Printing nothing at all, which is what this used to do, is indistinguishable
# from a hang — especially on CI, where there is no local activity to watch.
#
# Every xcodebuild task line ends in `(in target 'X' from project 'Y')`, so the
# target name is the one progress signal that is always present. An iOS slice
# touches 89 of them, which is about the right number of lines for a
# twenty-minute build.
#
# Each target is announced once, the first time it is seen. Reporting whenever
# the name *changes* looks like the obvious thing to do and is much worse:
# xcodebuild runs targets in parallel and interleaves their task lines, so the
# name flaps back and forth and the same log yields 629 lines instead of 89.
#
# Written to a file rather than held in a variable: bash misparses a quoted
# heredoc nested inside a command substitution inside double quotes.
progress_filter="$staging/progress.py"

cat > "$progress_filter" <<'PYTHON'
import sys
import threading
import time

start = time.time()
lock = threading.Lock()
state = {"target": None, "last": start}
seen = set()


def report(text):
    with lock:
        state["last"] = time.time()
        seconds = int(time.time() - start)
        sys.stderr.write("    [%d:%02d] %s\n" % (seconds // 60, seconds % 60, text))
        sys.stderr.flush()


def heartbeat():
    # Swiftfin's own ~700 files compile as a single whole-module task, which can
    # run for minutes without emitting a line. Say something anyway.
    while True:
        time.sleep(30)

        with lock:
            quiet = time.time() - state["last"]
            target = state["target"]

        if quiet >= 60:
            report("still compiling %s (%d targets done)" % (target or "dependencies", len(seen)))


threading.Thread(target=heartbeat, daemon=True).start()

MARKER = "(in target "

for line in sys.stdin:
    at = line.find(MARKER)

    if at < 0:
        continue

    rest = line[at + len(MARKER):]
    end = rest.find(" from project")

    if end < 0:
        continue

    target = rest[:end].strip().strip("'")

    if target in seen:
        continue

    seen.add(target)
    state["target"] = target
    report("%3d  %s" % (len(seen), target))
PYTHON

# build_slice <module> <destination> <products-subdirectory>
#
# Emits the path of the assembled framework on stdout.
build_slice() {
    local module="$1" destination="$2" products_dir="$3"
    local derived="$output/DerivedData/$products_dir"
    local log="$output/$module-$products_dir.log"

    echo "==> building $module for $destination" >&2
    echo "    full output: $log" >&2

    local started
    started="$(date +%s)"

    # `-skipMacroValidation`: Swiftfin depends on macros (StatefulMacro,
    # swift-case-paths through Defaults), and xcodebuild refuses to run a macro
    # plugin whose fingerprint has not been approved. Approval is a per-machine
    # Xcode trust record, so a developer who has opened the project once never
    # sees this, while a fresh runner fails every build with "Macro ... must be
    # enabled before it can be used".
    #
    # Library distribution is deliberately not enabled as a build setting: that
    # setting propagates to the whole dependency graph, where swift-nio's
    # `_NIODataStructures` does not compile with library evolution. Package.swift
    # applies the evolution and interface-emission flags only to Swiftfin's own
    # modules, and interface verification stays enabled here as the release gate.
    SWIFTFIN_XCFRAMEWORK=1 xcodebuild build \
        -scheme "$module" \
        -configuration Release \
        -destination "$destination" \
        -derivedDataPath "$derived" \
        -skipMacroValidation \
        SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=YES \
        BUILD_LIBRARY_FOR_DISTRIBUTION=NO \
        2>&1 | tee "$log" | /usr/bin/python3 -u "$progress_filter" || {
            echo "build failed; from $log:" >&2

            # Resolution failures put the reason on the lines *after* the
            # "Could not resolve" header, so grepping for `error:` alone drops
            # the only part that says what went wrong.
            grep -E "error:" "$log" | sort -u | head -20 >&2
            /usr/bin/sed -n '/Could not resolve/,/^$/p' "$log" | head -20 >&2

            echo "--- last 20 lines ---" >&2
            tail -20 "$log" >&2

            exit 1
        }

    echo "    built in $(( $(date +%s) - started ))s" >&2

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

    local module_dir="$framework/Modules/$module.swiftmodule"
    if ! find "$module_dir" -maxdepth 1 -type f -name '*.swiftinterface' -print -quit | grep -q .; then
        echo "$module $destination produced no .swiftinterface" >&2
        exit 1
    fi

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
