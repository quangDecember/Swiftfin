//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import CoreStore
import CoreText
import FactoryKit
import Foundation
import Logging
import Nuke
import PulseLogHandler
import UIKit

/// Entry point for embedding Swiftfin.
///
/// The Swiftfin apps and any host app that integrates the Swiftfin package go
/// through the same door: call ``configure()`` once at launch, then present
/// ``SwiftfinScene`` or ``SwiftfinRootView``.
public enum SwiftfinLibrary {

    @MainActor
    private static var isConfigured = false

    /// Prepares logging, persistence, image loading and UIKit appearance.
    ///
    /// Safe to call more than once; work after the first call is skipped. Must
    /// be called before any Swiftfin view is presented.
    @MainActor
    public static func configure() {
        guard !isConfigured else { return }
        isConfigured = true

        registerBundledFonts()

        // Logging

        LoggingSystem.bootstrap { label in

            // TODO: have setting for log level
            //       - default info, boolean to go down to trace
            let handlers: [any LogHandler] = [PersistentLogHandler(label: label)]
            #if DEBUG
                .appending(SwiftfinConsoleHandler())
            #endif

            var multiplexHandler = MultiplexLogHandler(handlers)
            multiplexHandler.logLevel = .trace
            return multiplexHandler
        }

        // CoreStore

        CoreStoreDefaults.dataStack = SwiftfinStore.dataStack
        CoreStoreDefaults.logger = SwiftfinCorestoreLogger()

        // Nuke

        ImageCache.shared.costLimit = 1024 * 1024 * 200 // 200 MB
        ImageCache.shared.ttl = 300 // 5 min

        ImageDecoderRegistry.shared.register { context in
            guard let mimeType = context.urlResponse?.mimeType else { return nil }
            return mimeType.contains("svg") ? ImageDecoders.Empty() : nil
        }

        ImagePipeline.shared = .Swiftfin.posters

        configureAppearance()

        #if os(iOS)
        SwiftfinSpotlight().addSwiftfinToSpotlight()
        #endif
    }

    /// UIKit appearance that the SwiftUI hierarchy relies on.
    @MainActor
    private static func configureAppearance() {
        #if os(iOS)
        UIScrollView.appearance().keyboardDismissMode = .onDrag

        // Sometimes the tab bar won't appear properly on push, always have material background.
        UITabBar.appearance().scrollEdgeAppearance = UITabBarAppearance(idiom: .unspecified)
        #else
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.label]
        #endif
    }

    /// Registers fonts that ship inside the package.
    ///
    /// The apps declare `NotoSansCJK-Regular.ttc` under `UIAppFonts`, which only
    /// works for fonts in the main bundle. A host app embedding Swiftfin has no
    /// such entry, so the font is registered from `Bundle.module` instead.
    private static func registerBundledFonts() {
        #if SWIFT_PACKAGE
        guard let fontURL = Bundle.module.url(
            forResource: "NotoSansCJK-Regular",
            withExtension: "ttc"
        ) else { return }

        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        #endif
    }
}
