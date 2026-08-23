//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults

@MainActor
final class DefaultsObservable<Value: StoredCodable>: ObservableObject, _StoredValueObservable {

    private var onObjectChanged: (() -> Void)?
    private var task: Task<Void, Never>?

    let key: StoredValues.Key<Value>

    init(_ key: StoredValues.Key<Value>, onObjectChanged: (() -> Void)? = nil) {
        self.key = key
        self.onObjectChanged = onObjectChanged
    }

    var value: Value {
        get {
            let defaultsKey = Defaults.Key(
                key._defaultsName,
                default: DefaultsStorable(key.defaultValue()),
                suite: key._defaultsSuite
            )
            return Defaults[defaultsKey].value
        }
        set {
            let defaultsKey = Defaults.Key(
                key._defaultsName,
                default: DefaultsStorable(key.defaultValue()),
                suite: key._defaultsSuite
            )
            Defaults[defaultsKey] = DefaultsStorable(newValue)
        }
    }

    deinit {
        task?.cancel()
    }

    func observe() {
        task?.cancel()

        task = .detached(priority: .userInitiated) { @MainActor [weak self, key] in
            let defaultsKey = Defaults.Key(
                key._defaultsName,
                default: DefaultsStorable(key.defaultValue()),
                suite: key._defaultsSuite
            )

            for await _ in Defaults.updates(defaultsKey) {
                guard let self else { return }

                self.onObjectChanged?()
            }
        }
    }
}
