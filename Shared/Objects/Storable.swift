//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults

/// A Codable value that can be stored by `StoredValue`.
protocol StoredCodable: Codable {}

/// A Swiftfin-owned type that is able to be stored within:
///
/// - `Defaults`: UserDefaults
/// - `StoredValue`: AnyData
///
/// External Codable types use `StoredCodable` directly so Swiftfin does not
/// publish retroactive `Defaults.Serializable` conformances for them.
protocol Storable: StoredCodable, Defaults.Serializable {}
