import Foundation
import KVLoggingKit
import KVLoggingLocal
import KVLoggingSecurity
import KVLoggingNetwork

// What every app boots, whatever it does. The keychain half lives in
// `AppBootstrap+Tokens.swift`, so an app with no sign-in deletes that file and
// this one still compiles.
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
        // Not a workaround any more: the iOS 26 crash behind
        // `installGlobally(swizzlingSessionConfigurations: true)` was fixed in
        // KVLoggingKit 1.1.0, and the flag is verified working on iOS 26.2. It
        // stays off because this app's own traffic is already covered
        // explicitly by `install(in:)` — see APIClientFactory — and that route
        // is scoped to one configuration instead of exchanging a getter
        // process-wide. Turn the flag on when you want the console to see
        // sessions the app does not build itself (Kingfisher, third-party SDKs);
        // that is the only thing it buys.
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
