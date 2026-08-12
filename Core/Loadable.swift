import Foundation

/// The state of one asynchronous value.
///
/// Modelled as an enum rather than `(value, isLoading, error)` because those
/// three fields can express states that cannot happen — loading *and* failed,
/// or a value alongside an error — and every screen then has to decide what to
/// render for them. Here the illegal states are unrepresentable.
enum Loadable<Value: Equatable>: Equatable, Sendable where Value: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(AppError)

    /// The transition to use when refreshing content that is already on screen.
    ///
    /// Going back to `.loading` would replace the list with a spinner on every
    /// pull-to-refresh, which reads as the app losing what the user was looking
    /// at. Keeping `.loaded` lets the refresh happen underneath.
    func reloading() -> Self {
        if case .loaded = self { return self }
        return .loading
    }

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var error: AppError? {
        if case .failed(let error) = self { return error }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
