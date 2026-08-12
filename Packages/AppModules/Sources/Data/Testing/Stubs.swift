import Foundation
import Domain
import AppFoundation

// Stubs live here, not in a test target, because `KVDependencyKey.testValue`
// has to name them and that declaration is in `AppDI` — which ships. They are
// small, deterministic, and never reach production code paths: a key resolves
// `testValue` only when the process is running under XCTest.

public struct StubOrderRepository: OrderRepositoryProtocol {
    public var orders: [Order]
    public var error: AppError?

    public init(orders: [Order] = Order.samples, error: AppError? = nil) {
        self.orders = orders
        self.error = error
    }

    public func list(forceRefresh: Bool) async throws -> [Order] {
        if let error { throw error }
        return orders
    }

    public func detail(id: String) async throws -> Order {
        if let error { throw error }
        guard let order = orders.first(where: { $0.id == id }) else {
            throw AppError.server(message: "Không tìm thấy đơn hàng", code: 404)
        }
        return order
    }

    public func cancel(id: String) async throws -> Order {
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

public struct StubAuthRepository: AuthRepositoryProtocol {
    public var session: AuthSession
    public var error: AppError?

    public init(session: AuthSession = .sample, error: AppError? = nil) {
        self.session = session
        self.error = error
    }

    public func signIn(email: String, password: String) async throws -> AuthSession {
        if let error { throw error }
        return session
    }

    public func signOut() async {}
}

public final class InMemoryTokenStore: TokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var access: String?
    private var refresh: String?

    public init(access: String? = nil, refresh: String? = nil) {
        self.access = access
        self.refresh = refresh
    }

    public var accessToken: String? { lock.withLock { access } }
    public var refreshToken: String? { lock.withLock { refresh } }

    public func save(access: String, refresh: String) {
        lock.withLock { self.access = access; self.refresh = refresh }
    }

    public func clear() {
        lock.withLock { access = nil; refresh = nil }
    }
}
