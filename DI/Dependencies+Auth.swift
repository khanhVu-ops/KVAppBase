import Foundation
import KVDIKit
import KVLoggingKit

// Everything that only exists because the app has a signed-in user. Deleting
// this file is how an app says it has none.

// MARK: - Token store

enum TokenStoreKey: KVDependencyKey {
    static let liveValue: any TokenStoring = KeychainTokenStore.shared
    /// Tests must not touch the real keychain: it is shared per device, so one
    /// test's tokens would leak into the next and make order matter.
    static let testValue: any TokenStoring = InMemoryTokenStore()
}

// MARK: - Sign-in

enum AuthRepositoryKey: KVDependencyKey {
    static let liveValue: any AuthRepositoryProtocol = {
        guard !AppEnvironment.current.usesStubBackend else { return StubAuthRepository() }
        @KVDependency(\.apiClient) var client
        @KVDependency(\.tokenStore) var tokenStore
        @KVDependency(\.logger) var logger
        return AuthRepository(
            client: client,
            tokenStore: tokenStore,
            logger: logger.scoped(category: "auth")
        )
    }()

    static let testValue: any AuthRepositoryProtocol = StubAuthRepository()
}

enum SignInUseCaseKey: KVDependencyKey {
    static let liveValue: SignInUseCase = {
        @KVDependency(\.authRepository) var auth
        @KVDependency(\.tokenStore) var tokens
        return SignInUseCase(auth: auth, tokens: tokens)
    }()
}

// MARK: - Values

extension KVDependencyValues {

    var tokenStore: any TokenStoring {
        get { self[TokenStoreKey.self] }
        set { self[TokenStoreKey.self] = newValue }
    }

    var authRepository: any AuthRepositoryProtocol {
        get { self[AuthRepositoryKey.self] }
        set { self[AuthRepositoryKey.self] = newValue }
    }

    var signInUseCase: SignInUseCase {
        get { self[SignInUseCaseKey.self] }
        set { self[SignInUseCaseKey.self] = newValue }
    }
}
