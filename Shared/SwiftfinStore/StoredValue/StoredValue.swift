//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import CoreStore
import Defaults
import FactoryKit
import Foundation
import Logging
import SwiftUI

// TODO: typealias to `Setting`?
//       - introduce `UserSetting` and `ServerSetting`
//         that automatically namespace

/// Adapts any `Storable` value to Defaults without making the value's type
/// publicly conform to `Defaults.Serializable`.
///
/// Its bridge accepts both the native property-list representation and the JSON
/// string representation used by Defaults' built-in bridges, so existing
/// values remain readable.
struct DefaultsStorable<Value: StoredCodable>: Codable, Defaults.Serializable {

    static var bridge: DefaultsStorableBridge<Value> {
        DefaultsStorableBridge()
    }

    let value: Value

    init(_ value: Value) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        value = try Value(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

struct DefaultsStorableBridge<Value: StoredCodable>: Defaults.Bridge {

    typealias Value = DefaultsStorable<Value>
    typealias Serializable = Any

    func serialize(_ value: DefaultsStorable<Value>?) -> Any? {
        guard
            let value,
            let data = try? JSONEncoder().encode(value.value)
        else {
            return nil
        }

        return try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
    }

    func deserialize(_ object: Any?) -> DefaultsStorable<Value>? {
        guard let object else { return nil }

        // Defaults' top-level Codable bridge stores a JSON string. Try that
        // form first before interpreting a native String as a JSON fragment.
        if
            let string = object as? String,
            let value = try? JSONDecoder().decode(Value.self, from: Data(string.utf8))
        {
            return DefaultsStorable(value)
        }

        guard
            JSONSerialization.isValidJSONObject(object) || object is NSString || object is NSNumber,
            let data = try? JSONSerialization.data(withJSONObject: object, options: .fragmentsAllowed),
            let value = try? JSONDecoder().decode(Value.self, from: data)
        else {
            return nil
        }

        return DefaultsStorable(value)
    }
}

/// A property wrapper for a stored `AnyData` object.
@propertyWrapper
struct StoredValue<Value: StoredCodable>: DynamicProperty {

    @ObservedObject
    private var observable: _GenericStoredValueObservation<Value>

    let key: StoredValues.Key<Value>

    var projectedValue: Binding<Value> {
        $observable.value
    }

    var wrappedValue: Value {
        get {
            observable.value
        }
        nonmutating set {
            observable.value = newValue
        }
    }

    init(_ key: StoredValues.Key<Value>) {
        self.key = key
        self.observable = .init(key)
    }

    mutating func update() {
        _observable.update()
    }
}

enum StoredValues {

    typealias Keys = _AnyKey

    // swiftformat:disable enumnamespaces
    class _AnyKey {
        typealias Key = StoredValues.Key
    }

    /// A key to an `AnyData` object.
    ///
    /// - Important: if `name` or `ownerID` are empty, the default value
    ///              will always be retrieved and nothing will be set.
    final class Key<Value: StoredCodable>: _AnyKey {

        enum StorageDestination {
            case defaults
            case sql
        }

        let defaultValue: () -> Value
        let field: String?
        let name: String
        let ownerID: String
        let storage: StorageDestination

        var _defaultsName: String {
            if field == name || field == nil {
                name
            } else {
                "\(field!)-\(name)"
            }
        }

        var _defaultsSuite: UserDefaults {
            UserDefaults(suiteName: ownerID)!
        }

        init(
            _ name: String,
            ownerID: String,
            field: String?,
            storage: StorageDestination = .sql,
            default defaultValue: @autoclosure @escaping () -> Value
        ) {
            self.defaultValue = defaultValue
            self.field = field
            self.name = name
            self.ownerID = ownerID

            // tvOS only supports user defaults storage
            #if os(tvOS)
            self.storage = .defaults
            #else
            self.storage = storage
            #endif
        }

        /// Always returns the given value and does not
        /// set anything to storage.
        init(always: @autoclosure @escaping () -> Value) {
            defaultValue = always
            field = nil
            name = "always"
            ownerID = ""
            storage = .defaults
        }
    }

    static subscript<Value: StoredCodable>(key: Key<Value>) -> Value {
        get {
            guard key.name.isNotEmpty, key.ownerID.isNotEmpty else { return key.defaultValue() }

            switch key.storage {
            case .defaults:
                let defaultsKey = Defaults.Key(
                    key._defaultsName,
                    default: DefaultsStorable(key.defaultValue()),
                    suite: key._defaultsSuite
                )
                return Defaults[defaultsKey].value
            case .sql:
                let fetchedValue: Value? = try? AnyStoredData.fetch(
                    ownerID: key.ownerID,
                    field: key.field ?? key.name,
                    key: key.name
                )

                return fetchedValue ?? key.defaultValue()
            }
        }
        set {
            guard key.name.isNotEmpty, key.ownerID.isNotEmpty else { return }

            switch key.storage {
            case .defaults:
                let defaultsKey = Defaults.Key(
                    key._defaultsName,
                    default: DefaultsStorable(key.defaultValue()),
                    suite: key._defaultsSuite
                )
                Defaults[defaultsKey] = DefaultsStorable(newValue)
            case .sql:
                try? AnyStoredData.store(
                    value: newValue,
                    ownerID: key.ownerID,
                    field: key.field ?? key.name,
                    key: key.name
                )
            }
        }
    }
}
