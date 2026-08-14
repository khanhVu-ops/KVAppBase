import Foundation
import KVRouterKit
import KVRouterCore

/// A route that may only be reached by a signed-in user.
///
/// The route says so itself instead of the guard keeping a list. Adding a
/// protected screen is then one conformance next to that screen — nobody has to
/// remember to come back here, which is exactly the edit that gets forgotten and
/// ships an unguarded screen.
protocol RequiresAuthentication {}

/// Blocks navigation into signed-in-only screens in one place, rather than with
/// an `if` at the top of every screen that would each render a different thing
/// while deciding.
///
/// It sees typed routes *and* `pushView { }` screens, because KVRouterKit hands
/// middleware `any KVRoute` either way.
struct AuthGuardMiddleware: KVRouteMiddleware {

    let isSignedIn: @MainActor () -> Bool

    /// Where a blocked navigation lands. Injected rather than named here: this
    /// file knows what "protected" means, and the app knows what its login
    /// screen is called.
    let signInRoute: any KVRoute

    func willNavigate(from: (any KVRoute)?, to: any KVRoute) async -> (any KVRoute)? {
        guard to is RequiresAuthentication, !isSignedIn() else { return to }
        return signInRoute
    }
}
