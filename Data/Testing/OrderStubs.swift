import Foundation

// Stubs live here, not in a test target, because `KVDependencyKey.testValue`
// has to name them and that declaration is in `AppDI` — which ships. They are
// small, deterministic, and never reach production code paths: a key resolves
// `testValue` only when the process is running under XCTest.

// Một file một stub, không gộp: app tạo từ template giữ feature nào thì giữ stub
// của feature đó, và một file gộp thì phải sửa tay mỗi lần.

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
