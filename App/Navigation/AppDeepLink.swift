import Foundation
import KVRouterCore
import FeatureOrder
import FeatureAuth

/// URL shapes belong to the app, so parsing lives here — as a pure function that
/// unit-tests without a router, a host or a simulator.
enum AppDeepLink {

    /// `myapp://order/42` → `OrderRoute.detail(id: "42")`
    static func route(for url: URL) -> (any KVRoute)? {
        var parts: [String] = []
        if let host = url.host, !host.isEmpty { parts.append(host) }
        parts.append(contentsOf: url.pathComponents.filter { $0 != "/" })
        return route(components: parts)
    }

    static func route(components parts: [String]) -> (any KVRoute)? {
        guard let head = parts.first else { return nil }
        let rest = Array(parts.dropFirst())

        switch (head, rest) {
        case ("order", let rest):
            return rest.first.map { OrderRoute.detail(id: $0) }
        case ("orders", []):
            return OrderRoute.history
        case ("forgot-password", _):
            return AuthRoute.forgotPassword(email: nil)
        default:
            return nil
        }
    }

    /// The full stack a link should land on, not just the leaf.
    ///
    /// Pushing only the destination leaves the user one back-swipe from falling
    /// out of the app. Giving the link a stack means Back walks them into it.
    static func stack(for route: any KVRoute) -> [any KVRoute] {
        switch route {
        case let route as OrderRoute:
            switch route {
            case .detail:  return [OrderRoute.history, route]
            case .history: return [route]
            }
        default:
            return [route]
        }
    }
}
