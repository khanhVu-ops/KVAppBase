import Foundation
import KVNetworkit
import AppFoundation

enum OrderEndpoint: KVAPIEndpointProtocol {
    case list
    case detail(id: String)
    case cancel(id: String)

    var baseURL: String { AppEnvironment.current.apiBaseURL }
    var apiVersion: String { "/api/v1" }

    var path: String {
        switch self {
        case .list:            return "/orders"
        case .detail(let id):  return "/orders/\(id)"
        case .cancel(let id):  return "/orders/\(id)/cancel"
        }
    }

    var method: KVHTTPMethod {
        switch self {
        case .list, .detail: return .get
        case .cancel:        return .post
        }
    }

    /// Declared per endpoint rather than globally: a list the user pulls to
    /// refresh can serve a warm copy for a minute, but the result of cancelling
    /// an order must never come from a cache.
    var cachePolicy: KVCachePolicy {
        switch self {
        case .list:   return .cacheFirst(ttl: 60)
        case .detail: return .cacheFirst(ttl: 30)
        case .cancel: return .ignore
        }
    }
}
