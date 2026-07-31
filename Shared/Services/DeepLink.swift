//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation

struct DeepLink: Equatable {

    enum Destination: Equatable {
        case item(id: String)

        // TODO: able to launch library by ID without item pre-retrieval?
//        case library(id: String)
    }

    let serverID: String
    let userID: String
    let destination: Destination

    init?(_ url: URL) {
        let value = url.absoluteString
        let pattern = #"^swiftfin://([A-Za-z0-9]+)/([A-Za-z0-9]+)/(item|library)/([A-Za-z0-9]+)/?$"#

        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                  in: value,
                  range: NSRange(value.startIndex..., in: value)
              ),
              let serverIDRange = Range(match.range(at: 1), in: value),
              let userIDRange = Range(match.range(at: 2), in: value),
              let destinationIDRange = Range(match.range(at: 4), in: value)
        else {
            return nil
        }

        self.serverID = String(value[serverIDRange])
        self.userID = String(value[userIDRange])

        self.destination = .item(id: String(value[destinationIDRange]))
    }

    @MainActor
    func route() -> NavigationRoute {
        switch destination {
        case let .item(id):
            .item(id: id)
//        case let .library(id):
//            let library = try await getItem(id: id, userSession: session)
//            return .library(viewModel: ItemLibraryViewModel(parent: library))
        }
    }
}

enum DeepLinkError: Error {
    case missingServer(String)
    case missingUser(String)
}
