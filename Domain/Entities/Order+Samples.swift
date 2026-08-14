import Foundation

// Sample values for previews and tests. They live in `Domain` because a fixture
// of a domain entity is part of that entity's vocabulary, and because features
// need them while being forbidden from importing `Data`.
//
// Not wrapped in `#if DEBUG`: SwiftUI previews compile in debug, but so do the
// test targets and the sample data in `Data`'s stubs, and the cost is a few
// bytes of literals.
//
// One file per entity, not one `Fixtures.swift` for all of them: an app built
// from this template keeps the entities it needs and deletes the rest, and a
// shared fixture file would have to be edited by hand every time.

extension Order {
    static func sample(
        id: String = "1",
        code: String = "DH-0001",
        status: Status = .pending
    ) -> Order {
        Order(
            id: id,
            code: code,
            customerName: "Nguyễn Văn A",
            total: 250_000,
            status: status,
            placedAt: Date(timeIntervalSince1970: 1_760_000_000)
        )
    }

    static let samples: [Order] = [
        .sample(id: "1", code: "DH-0001", status: .pending),
        .sample(id: "2", code: "DH-0002", status: .shipping),
        .sample(id: "3", code: "DH-0003", status: .delivered)
    ]
}
