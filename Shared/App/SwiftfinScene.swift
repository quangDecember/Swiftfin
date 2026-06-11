//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import Factory
import PreferencesView
import SwiftUI

public struct SwiftfinScene: Scene {

    public init() {
        SwiftfinLibrary.configure()
    }

    public var body: some Scene {
        WindowGroup {
            SwiftfinView()
        }
    }
}

public struct SwiftfinView: View {

    @StateObject
    private var valueObservation = SwiftfinAppValueObservation()

    public init() {}

    public var body: some View {
        OverlayToastView {
            PreferencesView {
                RootView()
            }
        }
        .ignoresSafeArea()
        .onAppDidEnterBackground {
            Defaults[.backgroundTimeStamp] = Date.now
        }
        .onAppWillEnterForeground {
            let backgroundedInterval = Date.now.timeIntervalSince(Defaults[.backgroundTimeStamp])

            if Defaults[.signOutOnBackground], backgroundedInterval > Defaults[.backgroundSignOutInterval] {
                Defaults[.lastSignedInUserID] = .signedOut
                Container.shared.currentUserSession.reset()
                Notifications[.didSignOut].post()
            }
        }
    }
}
