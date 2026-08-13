import Foundation
import KVNetworkit
import KVLoggingKit
import KVLoggingNetwork

enum APIClientFactory {

    /// Interceptor order matters and is not arbitrary:
    ///
    /// 1. connectivity first, so an offline request fails immediately instead of
    ///    waiting out a timeout with a token attached;
    /// 2. auth next, so the header exists before anything inspects the request;
    /// 3. refresh after auth, because it reacts to the 401 the header produced;
    /// 4. logging last, so what it prints is the request actually sent.
    static func make(
        environment: AppEnvironment,
        tokenStore: any TokenStoring,
        logger: LogClient
    ) -> any KVAPIClientProtocol {
        KVAPIClient(
            session: KVNetworkSession(configuration: capturingConfiguration()),
            interceptors: [
                KVNetworkAwareInterceptor(),
                KVAuthInterceptor(tokenProvider: { tokenStore.accessToken }),
                TokenRefreshInterceptor(tokenStore: tokenStore, environment: environment),
                KVLoggingInterceptor(
                    level: environment.isProduction ? .basic : .body,
                    // Bridges KVNetworkit's console output into KVLoggingKit, so
                    // network lines land in the same place as everything else —
                    // including the on-device console.
                    output: { line in logger.debug(line, category: "network") }
                )
            ],
            retryPolicy: .default,
            cache: KVHybridCache()
        )
    }

    /// A configuration the on-device console can see into.
    ///
    /// `install(in:)` adds the capture protocol to this one configuration:
    /// explicit, scoped to the app's own client, and with no process-wide
    /// swizzling of `protocolClasses` — which crashes on iOS 26, see
    /// AppBootstrap. Release builds get a plain configuration.
    private static func capturingConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        #if DEBUG
        NetworkLoggingURLProtocol.install(in: configuration)
        #endif
        return configuration
    }
}
