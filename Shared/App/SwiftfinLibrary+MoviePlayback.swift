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

public enum SwiftfinMovieLookup: Hashable, Sendable {
    case tmdbID(String)
    case keyword(String)
}

public enum SwiftfinMoviePlaybackError: LocalizedError, Equatable {
    case emptyKeyword
    case emptyTMDBID
    case noCurrentUserSession

    public var errorDescription: String? {
        switch self {
        case .emptyKeyword:
            "Movie keyword cannot be empty."
        case .emptyTMDBID:
            "TMDB id cannot be empty."
        case .noCurrentUserSession:
            "No current Jellyfin user session is available."
        }
    }
}

public extension SwiftfinLibrary {

    static func movieExists(
        matching lookup: SwiftfinMovieLookup,
        client: JellyfinClient
    ) async throws -> Bool {
        try await firstMovie(matching: lookup, client: client) != nil
    }

    static func movieExists(
        matching lookup: SwiftfinMovieLookup
    ) async throws -> Bool {
        try await firstMovie(matching: lookup) != nil
    }

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

    static func firstMovie(
        matching lookup: SwiftfinMovieLookup
    ) async throws -> BaseItemDto? {
        guard let userSession = Container.shared.currentUserSession() else {
            throw SwiftfinMoviePlaybackError.noCurrentUserSession
        }

        return try await firstMovie(matching: lookup, client: userSession.client)
    }

    @MainActor
    static func moviePlayer(
        for item: BaseItemDto
    ) -> SwiftfinMoviePlayerView {
        SwiftfinMoviePlayerView(item: item)
    }

    @MainActor
    static func moviePlayer(
        matching lookup: SwiftfinMovieLookup
    ) -> SwiftfinMoviePlayerView {
        SwiftfinMoviePlayerView(lookup: lookup)
    }
}

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
                SwiftfinMovieItemPlayerView(item: item)
            case .notFound:
                Text(L10n.noResults)
            case let .failed(message):
                Text(message)
            }
        }
        .task(id: source) {
            await loadIfNeeded()
        }
    }

    private func loadIfNeeded() async {
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

private extension SwiftfinLibrary {

    static func firstMovie(
        matchingKeyword keyword: String,
        client: JellyfinClient
    ) async throws -> BaseItemDto? {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard keyword.isNotEmpty else {
            throw SwiftfinMoviePlaybackError.emptyKeyword
        }

        var parameters = movieSearchParameters()
        parameters.limit = 1
        parameters.searchTerm = keyword

        let request = Paths.getItems(parameters: parameters)
        let response = try await client.send(request)

        return response.value.items?.first
    }

    static func firstMovie(
        matchingTMDBID tmdbID: String,
        client: JellyfinClient
    ) async throws -> BaseItemDto? {
        let tmdbID = tmdbID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard tmdbID.isNotEmpty else {
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

            let request = Paths.getItems(parameters: parameters)
            let response = try await client.send(request)
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
        parameters.fields = Array(Set(ItemFields.MinimumFields).union([.providerIDs]))
        parameters.includeItemTypes = [.movie]
        parameters.isRecursive = true

        return parameters
    }
}

private struct SwiftfinMovieItemPlayerView: View {

    @StateObject
    private var manager: MediaPlayerManager

    init(item: BaseItemDto) {
        let provider = MediaPlayerItemProvider(item: item) { item, modifyItem in
            try await MediaPlayerItem.build(
                for: item,
                modifyItem: modifyItem
            )
        }

        self._manager = StateObject(
            wrappedValue: MediaPlayerManager(provider: provider)
        )
    }

    var body: some View {
        VideoPlayerViewShim(manager: manager)
            .onAppear {
                Container.shared.mediaPlayerManager.register { @MainActor in
                    manager
                }

                Container.shared.mediaPlayerManagerPublisher()
                    .send(manager)
            }
            .onDisappear {
                manager.stop()
            }
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
