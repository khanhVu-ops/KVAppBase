import Foundation
import KVRouterCore

/// Stands in for the real router until `KVDependencies.prepare` installs one.
///
/// KVRouterKit has an equivalent (`KVNullRouter`) but keeps it internal, so the
/// app needs its own. Everything asserts: navigation that silently does nothing
/// looks like a broken button and gets debugged from the wrong end.
@MainActor
public final class UnhostedRouter: KVRouting {

    private var hasReported = false

    public nonisolated init() {}

    public var stackDepth: Int { 0 }
    public var topRoute: (any KVRoute)? { nil }
    public var routes: [any KVRoute] { [] }

    public func push(_ route: any KVRoute) { report(#function) }
    public func replaceTop(with route: any KVRoute) { report(#function) }
    public func setPath(_ routes: [any KVRoute]) { report(#function) }
    public func pop() { report(#function) }
    public func pop(count: Int) { report(#function) }
    public func popToRoot() { report(#function) }
    public func popTo(_ route: any KVRoute) { report(#function) }
    public func popTo(where predicate: @escaping (any KVRoute) -> Bool) { report(#function) }

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
