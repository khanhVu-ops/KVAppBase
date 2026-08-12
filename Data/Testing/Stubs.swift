import Foundation

// Stubs live here, not in a test target, because `KVDependencyKey.testValue`
// has to name them and that declaration is in `AppDI` — which ships. They are
// small, deterministic, and never reach production code paths: a key resolves
// `testValue` only when the process is running under XCTest.

struct StubOrderRepository: OrderRepositoryProtocol {
    var orders: [Order]
    var error: AppError?

    init(orders: [Order] = Order.samples, error: AppError? = nil) {
        self.orders = orders
        self.error = error
    }

    func list(forceRefresh: Bool) async throws -> [Order] {
        if let error { throw error }
        return orders
    }

    func detail(id: String) async throws -> Order {
        if let error { throw error }
        guard let order = orders.first(where: { $0.id == id }) else {
            throw AppError.server(message: "Không tìm thấy đơn hàng", code: 404)
        }
        return order
    }

    func cancel(id: String) async throws -> Order {
        if let error { throw error }
        guard let order = orders.first(where: { $0.id == id }) else {
            throw AppError.server(message: "Không tìm thấy đơn hàng", code: 404)
        }
        return Order(
            id: order.id, code: order.code, customerName: order.customerName,
            total: order.total, status: .cancelled, placedAt: order.placedAt
        )
    }
}

struct StubAuthRepository: AuthRepositoryProtocol {
    var session: AuthSession
    var error: AppError?

    init(session: AuthSession = .sample, error: AppError? = nil) {
        self.session = session
        self.error = error
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        if let error { throw error }
        return session
    }

    func signOut() async {}
}

final class InMemoryTokenStore: TokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var access: String?
    private var refresh: String?

    init(access: String? = nil, refresh: String? = nil) {
        self.access = access
        self.refresh = refresh
    }

    var accessToken: String? { lock.withLock { access } }
    var refreshToken: String? { lock.withLock { refresh } }

    func save(access: String, refresh: String) {
        lock.withLock { self.access = access; self.refresh = refresh }
    }

    func clear() {
        lock.withLock { access = nil; refresh = nil }
    }
}
