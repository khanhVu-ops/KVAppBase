import Foundation
import KVNetworkit
import KVLoggingKit

final class OrderRepository: OrderRepositoryProtocol {

    private let client: any KVAPIClientProtocol
    private let logger: ScopedLogClient

    init(client: any KVAPIClientProtocol, logger: ScopedLogClient) {
        self.client = client
        self.logger = logger
    }

    func list(forceRefresh: Bool) async throws -> [Order] {
        try await perform("list orders") {
            let dto: [OrderDTO] = try await client.request(OrderEndpoint.list)
            return dto.map { $0.toDomain() }
        }
    }

    func detail(id: String) async throws -> Order {
        try await perform("load order \(id)") {
            let dto: OrderDTO = try await client.request(OrderEndpoint.detail(id: id))
            return dto.toDomain()
        }
    }

    func cancel(id: String) async throws -> Order {
        try await perform("cancel order \(id)") {
            let dto: OrderDTO = try await client.request(OrderEndpoint.cancel(id: id))
            return dto.toDomain()
        }
    }

    /// One place that maps and logs, so no call site can forget to do either —
    /// forgetting is how a raw `KVAPIClientError` ends up in a ViewModel.
    private func perform<T>(
        _ description: String,
        _ work: () async throws -> T
    ) async throws -> T {
        do {
            return try await work()
        } catch {
            let mapped = AppError(networkError: error)
            if mapped != .cancelled {
                logger.error("Không thể \(description)", error: mapped)
            }
            throw mapped
        }
    }
}
