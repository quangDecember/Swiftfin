//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import FactoryKit
import Foundation
import JellyfinAPI
import SwiftUI

/// How to find a movie on the connected Jellyfin server.
public enum SwiftfinMovieLookup: Hashable, Sendable {

    /// Match against the movie's TMDB provider id.
    case tmdbID(String)

    /// Match against the server's own search, which covers title and other
    /// indexed metadata.
    case keyword(String)
}

public enum SwiftfinMoviePlaybackError: LocalizedError, Equatable {

    case emptyKeyword
    case emptyTMDBID
    case noCurrentUserSession
    case notPlayable

    public var errorDescription: String? {
        switch self {
        case .emptyKeyword:
            "Movie keyword cannot be empty."
        case .emptyTMDBID:
            "TMDB id cannot be empty."
        case .noCurrentUserSession:
            "No current Jellyfin user session is available."
        case .notPlayable:
            "The movie has no playable media source."
        }
    }
}

// MARK: - Lookup

public extension SwiftfinLibrary {

    /// Whether a movie matching `lookup` exists, using the signed-in session.
    static func movieExists(matching lookup: SwiftfinMovieLookup) async throws -> Bool {
        try await firstMovie(matching: lookup) != nil
    }

    /// Whether a movie matching `lookup` exists on the server `client` points at.
    static func movieExists(
        matching lookup: SwiftfinMovieLookup,
        client: JellyfinClient
    ) async throws -> Bool {
        try await firstMovie(matching: lookup, client: client) != nil
    }

    /// The first movie matching `lookup`, using the signed-in session.
    ///
    /// - Throws: ``SwiftfinMoviePlaybackError/noCurrentUserSession`` when no user
    ///   is signed in.
    static func firstMovie(matching lookup: SwiftfinMovieLookup) async throws -> BaseItemDto? {
        guard let userSession = Container.shared.currentUserSession() else {
            throw SwiftfinMoviePlaybackError.noCurrentUserSession
        }

        return try await firstMovie(matching: lookup, client: userSession.client)
    }

    /// The first movie matching `lookup` on the server `client` points at.
    static func firstMovie(
        matching lookup: SwiftfinMovieLookup,
        client: JellyfinClient
    ) async throws -> BaseItemDto? {
        switch lookup {
        case let .keyword(keyword):
            try await firstMovie(matchingKeyword: keyword, client: client)
        case let .tmdbID(tmdbID):
            try await firstMovie(matchingTMDBID: tmdbID, client: client)
        }
    }
}

// MARK: - Playback

public extension SwiftfinLibrary {

    /// A full-screen player for an already-resolved movie.
    @MainActor
    static func moviePlayer(for item: BaseItemDto) -> SwiftfinMoviePlayerView {
        SwiftfinMoviePlayerView(item: item)
    }

    /// A full-screen player that resolves `lookup` before playing.
    ///
    /// The view shows a progress indicator while resolving, and a message if
    /// nothing matches.
    @MainActor
    static func moviePlayer(matching lookup: SwiftfinMovieLookup) -> SwiftfinMoviePlayerView {
        SwiftfinMoviePlayerView(lookup: lookup)
    }
}

/// Plays a single movie, bypassing Swiftfin's browsing UI.
///
/// ``SwiftfinLibrary/configure()`` must have run, and a user must be signed in,
/// before this view is presented.
public struct SwiftfinMoviePlayerView: View {

    private enum Source: Hashable {
        case item(BaseItemDto)
        case lookup(SwiftfinMovieLookup)
    }

    private enum Phase {
        case loading
        case playing(BaseItemDto)
        case notFound
        case failed(String)
    }

    private let source: Source

    @State
    private var phase: Phase

    public init(item: BaseItemDto) {
        self.source = .item(item)
        self._phase = State(initialValue: .playing(item))
    }

    public init(lookup: SwiftfinMovieLookup) {
        self.source = .lookup(lookup)
        self._phase = State(initialValue: .loading)
    }

    public var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView()
            case let .playing(item):
                MoviePlayerContainerView(item: item)
            case .notFound:
                Text(L10n.noResults)
            case let .failed(message):
                Text(message)
            }
        }
        .task(id: source) {
            await resolveIfNeeded()
        }
    }

    private func resolveIfNeeded() async {
        guard case let .lookup(lookup) = source else { return }

        do {
            if let item = try await SwiftfinLibrary.firstMovie(matching: lookup) {
                phase = .playing(item)
            } else {
                phase = .notFound
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Player container

/// Builds a `MediaPlayerManager` for a movie and registers it the same way
/// `NavigationRoute.videoPlayer(manager:)` does, so that everything reading the
/// manager out of the container — playback controls, now-playing info, socket
/// commands — sees this playback session.
private struct MoviePlayerContainerView: View {

    private let item: BaseItemDto

    @State
    private var manager: MediaPlayerManager?
    @State
    private var error: String?

    init(item: BaseItemDto) {
        self.item = item
    }

    var body: some View {
        Group {
            if let manager {
                VideoPlayerViewShim(manager: manager)
            } else if let error {
                Text(error)
            } else {
                ProgressView()
            }
        }
        .onAppear(perform: start)
        .onDisappear {
            manager?.stop()
        }
    }

    @MainActor
    private func start() {
        guard manager == nil else { return }

        guard let provider = item.getPlaybackItemProvider(
            userSession: Container.shared.currentUserSession()
        ) else {
            error = SwiftfinMoviePlaybackError.notPlayable.localizedDescription
            return
        }

        let manager = MediaPlayerManager(provider: provider)

        Container.shared.mediaPlayerManager.register { manager }
        Container.shared.mediaPlayerManagerPublisher()
            .send(manager)

        self.manager = manager
    }
}

// MARK: - Queries

private extension SwiftfinLibrary {

    static func firstMovie(
        matchingKeyword keyword: String,
        client: JellyfinClient
    ) async throws -> BaseItemDto? {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !keyword.isEmpty else {
            throw SwiftfinMoviePlaybackError.emptyKeyword
        }

        var parameters = movieSearchParameters()
        parameters.limit = 1
        parameters.searchTerm = keyword

        let response = try await client.send(Paths.getItems(parameters: parameters))

        return response.value.items?.first
    }

    /// Jellyfin has no "find by provider id" query, so this pages through movies
    /// that carry a TMDB id and matches locally.
    static func firstMovie(
        matchingTMDBID tmdbID: String,
        client: JellyfinClient
    ) async throws -> BaseItemDto? {
        let tmdbID = tmdbID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !tmdbID.isEmpty else {
            throw SwiftfinMoviePlaybackError.emptyTMDBID
        }

        let pageSize = 100
        var startIndex = 0

        while true {
            var parameters = movieSearchParameters()
            parameters.hasTmdbID = true
            parameters.limit = pageSize
            parameters.sortBy = [.sortName]
            parameters.startIndex = startIndex

            let response = try await client.send(Paths.getItems(parameters: parameters))
            let items = response.value.items ?? []

            if let match = items.first(where: { $0.matchesTMDBID(tmdbID) }) {
                return match
            }

            guard items.count == pageSize else { return nil }

            startIndex += items.count
        }
    }

    static func movieSearchParameters() -> Paths.GetItemsParameters {
        var parameters = Paths.GetItemsParameters()
        parameters.enableUserData = true
        parameters.fields = ItemFields.MinimumFields.appending(.providerIDs)
        parameters.includeItemTypes = [.movie]
        parameters.isRecursive = true

        return parameters
    }
}

private extension BaseItemDto {

    func matchesTMDBID(_ tmdbID: String) -> Bool {
        providerIDs?.contains { key, value in
            ["themoviedb", "tmdb"].contains(key.normalizedTMDBProviderKey) && value == tmdbID
        } ?? false
    }
}

private extension String {

    var normalizedTMDBProviderKey: String {
        lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }
}
