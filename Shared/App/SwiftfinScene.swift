//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

#if os(iOS)

import Combine
import PreferencesView
import SwiftUI
import UIKit

/// The whole Swiftfin app as a scene, for hosts that give Swiftfin its own window.
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

/// The whole Swiftfin app as a view, for hosts that present Swiftfin inside a scene they own.
///
/// Swiftfin paints the accent color and appearance onto the key window while it is on screen.
/// The window's previous values are restored when this view disappears, so the host's own
/// controls don't keep Swiftfin's tint.
public struct SwiftfinView: View {

    @State
    private var windowAppearance = WindowAppearanceSnapshot()

    public init() {
        SwiftfinLibrary.configure()
    }

    public var body: some View {
        OverlayToastView {
            PreferencesView {
                WithLocalUserAuthentication {
                    RootView()
                        .supportedOrientations(UIDevice.isPad ? .allButUpsideDown : .portrait)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            windowAppearance.capture()
        }
        .onDisappear {
            windowAppearance.restore()
        }
    }
}

/// Retained for source compatibility with the `swiftpm` branch.
///
/// Accent color and appearance observation now live in `RootView`, which `SwiftfinView`
/// already contains, so this object no longer does anything.
@available(*, deprecated, message: "Appearance observation is owned by RootView; this type does nothing.")
public final class SwiftfinAppValueObservation: ObservableObject {

    public init() {}
}

@MainActor
private final class WindowAppearanceSnapshot {

    private weak var window: UIWindow?
    private var tintColor: UIColor?
    private var userInterfaceStyle: UIUserInterfaceStyle = .unspecified

    func capture() {
        guard let keyWindow = UIApplication.shared.keyWindow else { return }

        // A re-appearance while the window still carries Swiftfin's values must not
        // overwrite the host's originals.
        guard window !== keyWindow else { return }

        window = keyWindow
        tintColor = keyWindow.tintColorIfExplicitlySet
        userInterfaceStyle = keyWindow.overrideUserInterfaceStyle
    }

    func restore() {
        guard let window else { return }

        window.tintColor = tintColor
        window.overrideUserInterfaceStyle = userInterfaceStyle
        self.window = nil
    }
}

private extension UIWindow {

    /// `tintColor` never returns `nil`: unset, it reports the inherited system tint. Writing that
    /// value back would pin it, so only read it when something has actually set it.
    var tintColorIfExplicitlySet: UIColor? {
        let current = tintColor
        tintColor = nil
        let inherited = tintColor
        tintColor = current
        return current == inherited ? nil : current
    }
}

#endif
