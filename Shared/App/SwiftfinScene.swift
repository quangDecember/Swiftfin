//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

public import SwiftUI

#if os(iOS)
import PreferencesView
#endif

/// The whole Swiftfin app as a single `Scene`.
///
/// ```swift
/// @main
/// struct HostApp: App {
///     var body: some Scene {
///         SwiftfinScene()
///     }
/// }
/// ```
///
/// Use ``SwiftfinRootView`` instead when Swiftfin should occupy part of an
/// existing scene rather than own its own window.
public struct SwiftfinScene: Scene {

    public init() {
        SwiftfinLibrary.configure()
    }

    public var body: some Scene {
        WindowGroup {
            SwiftfinRootView()
        }
    }
}

/// The root of Swiftfin's view hierarchy: server selection, sign in, and the
/// full browsing and playback experience.
///
/// ``SwiftfinLibrary/configure()`` must have run before this view is presented.
/// ``SwiftfinScene`` does that for you; presenting this view directly does not.
public struct SwiftfinRootView: View {

    public init() {}

    public var body: some View {
        #if os(tvOS)
        OverlayToastView {
            WithUserAuthentication {
                RootView()
            }
        }
        #else
        OverlayToastView {
            PreferencesView {
                WithUserAuthentication {
                    RootView()
                        .supportedOrientations(UIDevice.isPad ? .allButUpsideDown : .portrait)
                }
            }
        }
        .ignoresSafeArea()
        #endif
    }
}
