import Foundation
import KVRouterKit
import KVRouterCore
import KVLoggingKit

/// Records where the app went, in the same log as everything else — so a bug
/// report reads as one timeline instead of two.
///
/// The route's description is logged, never its associated values: a route can
/// carry an id, an email or a token, and this runs on every navigation.
struct NavigationLogMiddleware: KVRouteMiddleware {

    private let logger: ScopedLogClient

    init(logger: LogClient) {
        self.logger = logger.scoped(category: "navigation")
    }

    func willNavigate(from: (any KVRoute)?, to: any KVRoute) async -> (any KVRoute)? {
        logger.debug("navigate → \(type(of: to))")
        return to
    }

    func willPop(from: (any KVRoute)?, to: (any KVRoute)?) async -> Bool {
        logger.debug("pop")
        return true
    }
}
