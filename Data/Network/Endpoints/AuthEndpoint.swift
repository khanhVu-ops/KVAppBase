import Foundation
import KVNetworkit

enum AuthEndpoint: KVAPIEndpointProtocol {
    case signIn(email: String, password: String)
    case refresh(token: String)

    var baseURL: String { AppEnvironment.current.apiBaseURL }
    var apiVersion: String { "/api/v1" }

    var path: String {
        switch self {
        case .signIn:  return "/auth/sign-in"
        case .refresh: return "/auth/refresh"
        }
    }

    var method: KVHTTPMethod { .post }

    var body: KVHTTPBody? {
        switch self {
        case .signIn(let email, let password):
            return try? .jsonEncoded(SignInRequest(email: email, password: password))
        case .refresh(let token):
            return try? .jsonEncoded(RefreshRequest(refreshToken: token))
        }
    }

    /// Never cached, and never logged with a body — see `APIClientFactory`.
    var cachePolicy: KVCachePolicy { .ignore }
}

private struct SignInRequest: Encodable {
    let email: String
    let password: String
}

private struct RefreshRequest: Encodable {
    let refreshToken: String
}
