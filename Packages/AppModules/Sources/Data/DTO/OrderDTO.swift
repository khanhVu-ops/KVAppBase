import Foundation
import Domain

/// The wire shape. Field names, optionality and date format belong to the
/// backend; `Order` belongs to the app. `toDomain()` is where one becomes the
/// other, and where a missing optional turns into a sensible default instead of
/// leaking `nil` upward.
struct OrderDTO: Decodable {
    let id: String
    let code: String?
    let customerName: String?
    let total: Decimal?
    let status: String?
    let placedAt: Date?

    func toDomain() -> Order {
        Order(
            id: id,
            code: code ?? id,
            customerName: customerName ?? "—",
            total: total ?? 0,
            status: Order.Status(rawValue: status ?? "") ?? .pending,
            placedAt: placedAt ?? .distantPast
        )
    }
}
