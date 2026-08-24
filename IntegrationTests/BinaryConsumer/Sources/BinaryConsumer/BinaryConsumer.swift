import Swiftfin

/// Compiling this target verifies that a separate package can load Swiftfin's
/// textual interface with only the dependencies declared by binary mode.
@MainActor
public func makeSwiftfinRootView() -> SwiftfinRootView {
    SwiftfinRootView()
}

@MainActor
public func makeSwiftfinMoviePlayer() -> SwiftfinMoviePlayerView {
    SwiftfinLibrary.moviePlayer(matching: .keyword("interface verification"))
}
