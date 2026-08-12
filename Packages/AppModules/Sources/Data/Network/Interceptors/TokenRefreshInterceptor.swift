import Foundation
import KVNetworkit
import Domain
import AppFoundation

/// Refreshes an expired access token once per 401, coordinating so that ten
/// requests failing at the same moment produce one refresh rather than ten.
struct TokenRefreshInterceptor: KVTokenRefreshingInterceptorProtocol {

    let tokenStore: any TokenStoring
    let environment: AppEnvironment
    let coordinator = KVTokenRefreshCoordinator()

    func refreshAction(
        response: URLResponse?,
        data: Data?
    ) async throws -> KVInterceptorAction {
        guard (response as? HTTPURLResponse)?.statusCode == 401,
              let refreshToken = tokenStore.refreshToken
        else { return .proceed }

        try await coordinator.refresh {
            // A bare client: no auth interceptor (the token is the thing that is
            // broken) and no refresh interceptor (which would recurse).
            let client = KVAPIClient(interceptors: [], retryPolicy: .never)
            do {
                let session: AuthSessionDTO = try await client.request(
                    AuthEndpoint.refresh(token: refreshToken)
                )
                tokenStore.save(access: session.accessToken, refresh: session.refreshToken)
            } catch let error as KVAPIClientError where error.isNetworkConnectivityError {
                // A dead network is not a dead session. Rethrowing as-is keeps
                // the request failing with `.offline` instead of signing the
                // user out because they walked into a lift.
                throw error
            } catch {
                throw KVAPIClientError.refreshTokenInvalid
            }
        }

        return .retryWithUpdatedToken
    }
}
