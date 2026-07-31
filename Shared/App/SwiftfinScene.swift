//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import PreferencesView
import SwiftUI
import UIKit

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

    public init() {}

    public var body: some View {
        OverlayToastView {
            PreferencesView {
                WithUserAuthentication {
                    RootView()
                        .supportedOrientations(UIDevice.isPad ? .allButUpsideDown : .portrait)
                }
            }
        }
        .ignoresSafeArea()
    }
}
