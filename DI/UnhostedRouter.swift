import Foundation
import KVRouterCore

/// Stands in for the real router until `KVDependencies.prepare` installs one.
///
/// KVRouterCore 3.2.0 added `KVUnhostedRouter`, which does exactly this and
/// reports better (it names the route type). It cannot be used here yet: its
/// `init()` inherits the class's `@MainActor` isolation, and a
/// `KVDependencyKey.liveValue` is a nonisolated static, so calling it there is
/// "main actor-isolated default value in a nonisolated context". The package's
/// own documented example — assigning it to a static in a plain enum — hits the
/// same wall.
///
/// The fix upstream is one word: `nonisolated public init() {}`. The initialiser
/// only sets a `Bool`, so there is nothing for the isolation to protect.
/// Delete this file and switch `RouterKey` to `KVUnhostedRouter` once that ships.
///
/// Everything asserts: navigation that silently does nothing looks like a broken
/// button and gets debugged from the wrong end.
@MainActor
final class UnhostedRouter: KVRouting {

    private var hasReported = false

    nonisolated init() {}

    var stackDepth: Int { 0 }
    var topRoute: (any KVRoute)? { nil }
    var routes: [any KVRoute] { [] }

    func push(_ route: any KVRoute) { report(#function) }
    func replaceTop(with route: any KVRoute) { report(#function) }
    func setPath(_ routes: [any KVRoute]) { report(#function) }
    func pop() { report(#function) }
    func pop(count: Int) { report(#function) }
    func popToRoot() { report(#function) }
    func popTo(_ route: any KVRoute) { report(#function) }
    func popTo(where predicate: @escaping (any KVRoute) -> Bool) { report(#function) }

    private func report(_ function: String) {
        guard !hasReported else { return }
        hasReported = true
        assertionFailure(
            """
            \(function) reached UnhostedRouter: no router was installed. \
            Call KVDependencies.prepare { $0.router = router } in App.init.
            """
        )
    }
}
