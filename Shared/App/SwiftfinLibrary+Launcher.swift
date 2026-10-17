//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

#if os(iOS)

import JellyfinAPI
import PreferencesView
import SwiftUI

/// Display information for Swiftfin's restored Jellyfin session. Contains no credentials.
public struct SwiftfinLibraryConnection: Hashable, Sendable {

    public let serverName: String
    public let username: String

    public init(serverName: String, username: String) {
        self.serverName = serverName
        self.username = username
    }
}

public extension SwiftfinLibrary {

    /// Restores the session saved by Swiftfin and returns its server and user names.
    /// Returns nil when nobody is signed in; storage setup failures are propagated.
    @MainActor
    static func currentConnection() async throws -> SwiftfinLibraryConnection? {
        do {
            let session = try await restoreCurrentUserSession()
            try Task.checkCancellation()
            return SwiftfinLibraryConnection(
                serverName: session.server.name,
                username: session.user.username
            )
        } catch SwiftfinMoviePlaybackError.noCurrentUserSession {
            return nil
        }
    }

    /// Presents the native item page. Playback starts only when its Play button is selected.
    @MainActor
    static func movieDetails(for item: BaseItemDto) -> SwiftfinMovieDetailView {
        SwiftfinMovieDetailView(item: item)
    }

    /// Finds a movie in the restored user's library and presents its native item page.
    @MainActor
    static func movieDetails(matching lookup: SwiftfinMovieLookup) -> SwiftfinMovieDetailView {
        SwiftfinMovieDetailView(lookup: lookup)
    }
}

/// A native Swiftfin movie page with its navigation, menus and playback actions.
@MainActor
public struct SwiftfinMovieDetailView: View {

    private enum Source: Hashable {
        case item(BaseItemDto)
        case lookup(SwiftfinMovieLookup)
    }

    private enum Phase {
        case loading
        case ready(BaseItemDto)
        case notFound
        case failed(String)
    }

    private let source: Source

    @State
    private var phase: Phase = .loading

    public init(item: BaseItemDto) {
        source = .item(item)
    }

    public init(lookup: SwiftfinMovieLookup) {
        source = .lookup(lookup)
    }

    public var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView()
            case let .ready(item):
                SwiftfinMovieItemDetailView(item: item)
                    .id(item.id)
            case .notFound:
                Text(L10n.noResults)
            case let .failed(message):
                Text(verbatim: message)
            }
        }
        .task(id: source) {
            await load()
        }
    }

    private func load() async {
        phase = .loading

        do {
            let item: BaseItemDto?
            switch source {
            case let .item(value):
                _ = try await SwiftfinLibrary.restoreCurrentUserSession()
                item = value
            case let .lookup(lookup):
                item = try await SwiftfinLibrary.firstMovie(matching: lookup)
            }
            try Task.checkCancellation()

            if let item {
                phase = .ready(item)
            } else {
                phase = .notFound
            }
        } catch is CancellationError {
            // Dismissed or replaced views must not publish stale results.
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(error.localizedDescription)
        }
    }
}

@MainActor
private struct SwiftfinMovieItemDetailView: View {

    @StateObject
    private var provider: ItemContentGroupProvider

    init(item: BaseItemDto) {
        _provider = StateObject(wrappedValue: ItemContentGroupProvider(item: item))
    }

    var body: some View {
        PreferencesView {
            NavigationInjectionView(coordinator: .init()) {
                ItemView(provider: provider)
            }
        }
    }
}

#if DEBUG
#Preview("Movie details") {
    SwiftfinMovieDetailView(item: BaseItemDto(id: "preview-movie", name: "Movie", type: .movie))
}

#Preview("Native movie page") {
    SwiftfinMovieItemDetailView(item: BaseItemDto(id: "preview-movie", name: "Movie", type: .movie))
}
#endif

#endif
