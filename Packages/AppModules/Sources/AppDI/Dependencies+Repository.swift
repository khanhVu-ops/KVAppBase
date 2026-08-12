import Foundation
import KVDIKit
import KVLoggingKit
import Domain
import Data

// Repository keys resolve their own collaborators through `@KVDependency`, which
// KVDIKit evaluates on read. That means the order of `prepare` calls at launch
// cannot matter: a repository built here still sees the real API client even
// though the client was configured after this key was declared.

public enum OrderRepositoryKey: KVDependencyKey {
    public static let liveValue: any OrderRepositoryProtocol = {
        @KVDependency(\.apiClient) var client
        @KVDependency(\.logger) var logger
        return OrderRepository(client: client, logger: logger.scoped(category: "order"))
    }()

    public static let testValue: any OrderRepositoryProtocol = StubOrderRepository()
}

public enum AuthRepositoryKey: KVDependencyKey {
    public static let liveValue: any AuthRepositoryProtocol = {
        @KVDependency(\.apiClient) var client
        @KVDependency(\.tokenStore) var tokenStore
        @KVDependency(\.logger) var logger
        return AuthRepository(
            client: client,
            tokenStore: tokenStore,
            logger: logger.scoped(category: "auth")
        )
    }()

    public static let testValue: any AuthRepositoryProtocol = StubAuthRepository()
}

public enum SignInUseCaseKey: KVDependencyKey {
    public static let liveValue: SignInUseCase = {
        @KVDependency(\.authRepository) var auth
        @KVDependency(\.tokenStore) var tokens
        return SignInUseCase(auth: auth, tokens: tokens)
    }()
}

public extension KVDependencyValues {

    var orderRepository: any OrderRepositoryProtocol {
        get { self[OrderRepositoryKey.self] }
        set { self[OrderRepositoryKey.self] = newValue }
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
