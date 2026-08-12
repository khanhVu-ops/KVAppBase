import Foundation

/// What the app needs from order storage, stated without saying where it comes
/// from. `Data` supplies an implementation that talks HTTP; a test supplies one
/// that returns fixtures. Neither is visible from here.
public protocol OrderRepositoryProtocol: Sendable {

    /// - Parameter forceRefresh: Skip any cached copy. Pull-to-refresh passes
    ///   `true`; a first appearance passes `false` so a warm cache can answer.
    func list(forceRefresh: Bool) async throws -> [Order]

    func detail(id: String) async throws -> Order

    func cancel(id: String) async throws -> Order
}
