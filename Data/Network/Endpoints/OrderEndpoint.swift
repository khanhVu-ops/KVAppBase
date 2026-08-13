import Foundation
import KVNetworkit

enum OrderEndpoint: KVAPIEndpointProtocol {
    /// `forceRefresh` không đổi URL — nó đổi `cachePolicy`. KVNetworkit lấy policy
    /// **chỉ** từ endpoint (`request` không có tham số override), nên "bỏ qua cache"
    /// phải là một case của endpoint, không thì `forceRefresh` của repository là một
    /// lời hứa không ai thực hiện.
    case list(forceRefresh: Bool)
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
        case .list(let forceRefresh): return forceRefresh ? .ignore : .cacheFirst(ttl: 60)
        case .detail:                 return .cacheFirst(ttl: 30)
        case .cancel:                 return .ignore
        }
    }
}
