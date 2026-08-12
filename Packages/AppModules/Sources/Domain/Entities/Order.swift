import Foundation

/// What the app means by an order, independent of how any API happens to spell it.
///
/// `OrderDTO` in `Data` is what the backend sends; this is what the app reasons
/// about. Keeping them apart is what lets a backend rename a field without a
/// change reaching a ViewModel.
public struct Order: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let code: String
    public let customerName: String
    public let total: Decimal
    public let status: Status
    public let placedAt: Date

    public enum Status: String, Equatable, Hashable, Sendable, CaseIterable {
        case pending, confirmed, shipping, delivered, cancelled
    }

    public init(
        id: String,
        code: String,
        customerName: String,
        total: Decimal,
        status: Status,
        placedAt: Date
    ) {
        self.id = id
        self.code = code
        self.customerName = customerName
        self.total = total
        self.status = status
        self.placedAt = placedAt
    }
}

public extension Order {
    var isCancellable: Bool {
        status == .pending || status == .confirmed
    }
}
