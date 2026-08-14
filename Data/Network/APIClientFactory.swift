import Foundation
import KVNetworkit
import KVLoggingKit
import KVLoggingNetwork

enum APIClientFactory {

    /// Interceptor order matters and is not arbitrary:
    ///
    /// 1. connectivity first, so an offline request fails immediately instead of
    ///    waiting out a timeout with a token attached;
    /// 2. `authInterceptors` next — the header has to exist before anything
    ///    inspects the request, and a refresh has to sit right behind the header
    ///    it reacts to;
    /// 3. logging last, so what it prints is the request actually sent.
    ///
    /// Auth is a parameter rather than something built in here because an app
    /// with an API but no login is a real case, and it must not have to fork
    /// this file to say so. The slot is fixed: callers choose *what* goes in the
    /// middle, never *where*.
    static func make(
        environment: AppEnvironment,
        logger: LogClient,
        authInterceptors: [any KVNetworkInterceptorProtocol] = []
    ) -> any KVAPIClientProtocol {
        KVAPIClient(
            session: KVNetworkSession(configuration: capturingConfiguration()),
            interceptors: [KVNetworkAwareInterceptor()]
                + authInterceptors
                + [
                    KVLoggingInterceptor(
                        level: environment.isProduction ? .basic : .body,
                        // Bridges KVNetworkit's console output into KVLoggingKit,
                        // so network lines land in the same place as everything
                        // else — including the on-device console.
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
    /// swizzling of `protocolClasses` — see AppBootstrap for when that wider
    /// switch is worth throwing. Release builds get a plain configuration.
    private static func capturingConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        #if DEBUG
        NetworkLoggingURLProtocol.install(in: configuration)
        #endif
        return configuration
    }
}
