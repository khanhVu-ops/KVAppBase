import Foundation

/// What the app means by an order, independent of how any API happens to spell it.
///
/// `OrderDTO` in `Data` is what the backend sends; this is what the app reasons
/// about. Keeping them apart is what lets a backend rename a field without a
/// change reaching a ViewModel.
struct Order: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let code: String
    let customerName: String
    let total: Decimal
    let status: Status
    let placedAt: Date

    enum Status: String, Equatable, Hashable, Sendable, CaseIterable {
        case pending, confirmed, shipping, delivered, cancelled
    }

    init(
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

extension Order {
    var isCancellable: Bool {
        status == .pending || status == .confirmed
    }
}
