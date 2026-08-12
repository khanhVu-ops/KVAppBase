import Foundation
import KVRouterCore

/// Stands in for the real router until `KVDependencies.prepare` installs one.
///
/// KVRouterKit has an equivalent (`KVNullRouter`) but keeps it internal, so the
/// app needs its own. Everything asserts: navigation that silently does nothing
/// looks like a broken button and gets debugged from the wrong end.
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
