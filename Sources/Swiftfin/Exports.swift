//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

// Swiftfin's iOS and tvOS sources define overlapping types — `VideoPlayer`,
// `GestureView`, `Stepper` and others exist in both — so they cannot share a
// module. They are built as two targets, selected by a platform condition in
// `Package.swift`, and re-exported here so that consumers only ever write
// `import Swiftfin`.

#if os(tvOS)
@_exported import SwiftfinTVOS
#else
@_exported import SwiftfinIOS
#endif
