import Foundation
import KVDIKit
import KVLoggingKit

// Repository keys resolve their own collaborators through `@KVDependency`, which
// KVDIKit evaluates on read. That means the order of `prepare` calls at launch
// cannot matter: a repository built here still sees the real API client even
// though the client was configured after this key was declared.
//
// One file per feature: deleting a feature is then deleting files, never editing
// a shared file down to the parts you kept.

enum OrderRepositoryKey: KVDependencyKey {
    static let liveValue: any OrderRepositoryProtocol = {
        guard !AppEnvironment.current.usesStubBackend else { return StubOrderRepository() }
        @KVDependency(\.apiClient) var client
        @KVDependency(\.logger) var logger
        return OrderRepository(client: client, logger: logger.scoped(category: "order"))
    }()

    static let testValue: any OrderRepositoryProtocol = StubOrderRepository()
}

extension KVDependencyValues {

    var orderRepository: any OrderRepositoryProtocol {
        get { self[OrderRepositoryKey.self] }
        set { self[OrderRepositoryKey.self] = newValue }
    }
}
