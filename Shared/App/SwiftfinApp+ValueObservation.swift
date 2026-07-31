//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine

/// Compatibility object for clients built against the original SwiftfinLib API.
///
/// `RootView` now owns preference observation through its coordinator, so retaining
/// an instance is no longer required for appearance and accent-color updates.
@available(*, deprecated, message: "Preference observation is managed by RootView.")
public final class SwiftfinAppValueObservation: ObservableObject {

    public init() {}
}
