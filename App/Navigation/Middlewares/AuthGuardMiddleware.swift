import Foundation
import KVRouterKit
import KVRouterCore
import FeatureAuth
import FeatureOrder

/// Blocks navigation into signed-in-only screens in one place, rather than with
/// an `if` at the top of every screen that would each render a different thing
/// while deciding.
///
/// It sees typed routes *and* `pushView { }` screens, because KVRouterKit hands
/// middleware `any KVRoute` either way.
struct AuthGuardMiddleware: KVRouteMiddleware {

    let isSignedIn: @MainActor () -> Bool

    func willNavigate(from: (any KVRoute)?, to: any KVRoute) async -> (any KVRoute)? {
        guard requiresAuth(to), !isSignedIn() else { return to }
        return AuthRoute.signIn
    }

    private func requiresAuth(_ route: any KVRoute) -> Bool {
        switch route {
        case is OrderRoute: return true
        case is AuthRoute:  return false
        default:            return false
        }
    }
}
