import Foundation
import KVDIKit
import KVNetworkit
import KVLoggingKit
import KVRouterCore

// Every dependency key in the app is declared in this module and nowhere else.
// Features read keys; only the composition root writes them. That is what keeps
// a feature from reaching into `Data` for a concrete type.

// MARK: - Logger

/// `.disabled` is a working logger that drops everything, so a bootstrap failure
/// costs logs rather than a crash. `AppBootstrap` replaces it at launch.
enum LoggerKey: KVDependencyKey {
    static let liveValue: LogClient = .disabled
    static let testValue: LogClient = .disabled
}

// MARK: - Token store

enum TokenStoreKey: KVDependencyKey {
    static let liveValue: any TokenStoring = KeychainTokenStore.shared
    /// Tests must not touch the real keychain: it is shared per device, so one
    /// test's tokens would leak into the next and make order matter.
    static let testValue: any TokenStoring = InMemoryTokenStore()
}

// MARK: - API client

enum APIClientKey: KVDependencyKey {
    static let liveValue: any KVAPIClientProtocol = {
        @KVDependency(\.tokenStore) var tokenStore
        @KVDependency(\.logger) var logger
        return APIClientFactory.make(
            environment: .current,
            tokenStore: tokenStore,
            logger: logger
        )
    }()

    static let testValue: any KVAPIClientProtocol = KVMockAPIClient()
}

// MARK: - Router

/// The router is a `@MainActor` object that only exists once `App.init` has run,
/// so the key ships a placeholder and `KVDependencies.prepare` swaps in the real
/// one.
///
/// The placeholder no-ops and asserts on the first command. Both obvious
/// alternatives are worse — a real unhosted `KVAppRouter` swallows pushes into an
/// invisible stack, and a silent no-op reads as a broken button and gets debugged
/// from the wrong end.
///
/// KVRouterCore 3.2.0 ships `KVUnhostedRouter` for exactly this; see
/// `UnhostedRouter.swift` for why it cannot be used from a `liveValue` yet.
enum RouterKey: KVDependencyKey {
    static let liveValue: any KVRouting = UnhostedRouter()
    static let testValue: any KVRouting = UnhostedRouter()
}

// MARK: - Toast

enum ToastKey: KVDependencyKey {
    static let liveValue: ToastService = .noop
    static let testValue: ToastService = .noop
}

// MARK: - Values

extension KVDependencyValues {

    var logger: LogClient {
        get { self[LoggerKey.self] }
        set { self[LoggerKey.self] = newValue }
    }

    var tokenStore: any TokenStoring {
        get { self[TokenStoreKey.self] }
        set { self[TokenStoreKey.self] = newValue }
    }

    var apiClient: any KVAPIClientProtocol {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }

    var router: any KVRouting {
        get { self[RouterKey.self] }
        set { self[RouterKey.self] = newValue }
    }

    var toast: ToastService {
        get { self[ToastKey.self] }
        set { self[ToastKey.self] = newValue }
    }
}
