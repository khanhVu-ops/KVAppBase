import Foundation
import KVRouterCore

/// This feature's addressable screens, declared here rather than in a central
/// `AppRoute` enum. That is what lets `FeatureOrder` stay unaware that
/// `FeatureAuth` exists, and removes the one file every feature would otherwise
/// have to edit.
///
/// `KVRestorableRoute` (= `KVRoute` + `Codable`) opts the route into state
/// restoration and deep links. A screen that is only ever reached from inside
/// this feature does not need a route at all — push it with `pushView { }`.
enum OrderRoute: KVRestorableRoute {
    case detail(id: String)
    case history
}

/// Orders belong to a user, so every screen in this flow needs a session.
/// `AuthGuardMiddleware` reads this and nothing else — the guard never learns
/// the names of the features it protects.
extension OrderRoute: RequiresAuthentication {}
