import Foundation
import KVDIKit
import KVLoggingKit
import KVNetworkit

// The API client and nothing else. An app with no backend — a tool that never
// leaves the device — deletes this file and stops linking KVNetworkit.

// MARK: - Auth interceptors

/// What the client puts between connectivity and logging.
///
/// Empty by default because "has an API, has no login" is an ordinary app, not
/// a degraded one. The composition root fills this in when there is a session to
/// carry; see `Dependencies+Auth.swift` for the pieces it fills it with.
enum AuthInterceptorsKey: KVDependencyKey {
    static let liveValue: [any KVNetworkInterceptorProtocol] = []
    static let testValue: [any KVNetworkInterceptorProtocol] = []
}

// MARK: - API client

/// Resolved on first read, not at launch — so it sees whatever the composition
/// root has already written, and the order of `prepare` calls cannot matter.
enum APIClientKey: KVDependencyKey {
    static let liveValue: any KVAPIClientProtocol = {
        @KVDependency(\.logger) var logger
        @KVDependency(\.authInterceptors) var authInterceptors
        return APIClientFactory.make(
            environment: .current,
            logger: logger,
            authInterceptors: authInterceptors
        )
    }()

    static let testValue: any KVAPIClientProtocol = KVMockAPIClient()
}

// MARK: - Values

extension KVDependencyValues {

    var authInterceptors: [any KVNetworkInterceptorProtocol] {
        get { self[AuthInterceptorsKey.self] }
        set { self[AuthInterceptorsKey.self] = newValue }
    }

    var apiClient: any KVAPIClientProtocol {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}
