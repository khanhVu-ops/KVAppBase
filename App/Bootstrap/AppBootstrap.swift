import Foundation
import KVLoggingKit
import KVLoggingLocal
import KVLoggingSecurity
import KVLoggingNetwork

enum AppBootstrap {

    /// Builds the logger. Falls back to `.disabled` rather than crashing: losing
    /// logs is a bad day, failing to launch is a worse one.
    @MainActor
    static func startLogging() -> LogClient {
        let logger = (try? makeLogger()) ?? .disabled

        #if DEBUG
        // Captures request and response bodies for the on-device console.
        // Debug only: it routes every request through a replay session, and it
        // is the one switch that widens what is held in memory.
        NetworkLoggingURLProtocol.settings = .init(
            recorder: NetworkLogRecorder(logger: logger),
            // Exclude the log upload endpoint once you add one, otherwise
            // shipping logs generates more logs to ship.
            shouldCapture: { _ in true }
        )
        // `URLProtocol.registerClass` only — no configuration swizzling.
        //
        // `installGlobally(swizzlingSessionConfigurations: true)` exchanges the
        // `protocolClasses` getter process-wide, and on iOS 26 that crashes on
        // the first request:
        //
        //   +[NSURLSessionConfiguration canInitWithTask:]: unrecognized selector
        //
        // CFNetwork walks the returned array calling `+canInitWithTask:` on each
        // entry, and after the exchange the array contains the configuration
        // class itself. The app's own client is covered by `install(in:)`
        // instead — see APIClientFactory. That is the route the package
        // documents as the explicit, swizzle-free one, and it is enough here.
        NetworkLoggingURLProtocol.installGlobally()
        #endif

        return logger
    }

    private static func makeLogger() throws -> LogClient {
        let service = Bundle.main.bundleIdentifier ?? "app"
        let keyProvider = KeychainLogEncryptionKeyProvider(service: service)
        let cipher = AESGCMLogCipher(keyProvider: keyProvider)

        let logsDirectory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs")

        let localFiles = try RollingFileDestination(
            directory: logsDirectory,
            policy: .init(
                maxFileSize: 2_000_000,
                maxFileCount: 5,
                retentionDays: 7,
                protection: .encrypted(cipher)
            )
        )

        return LogClient(
            configuration: .init(
                minimumLevel: AppEnvironment.current.isProduction ? .info : .debug,
                processors: [
                    DeviceContextProcessor(),
                    // Anything not on this list never leaves the process. Adding
                    // a key here is a privacy decision, so it is made in one
                    // place rather than at each call site.
                    PrivacyProcessor.strict(allowedMetadataKeys: [
                        "screen", "order_id", "request_id", "duration_ms", "session_id"
                    ])
                ]
            ),
            destinations: [
                SystemLogDestination(subsystem: service),
                localFiles
            ]
        )
    }
}
