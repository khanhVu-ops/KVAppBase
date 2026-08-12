import Foundation

// Sample values for previews and tests. They live in `Domain` because a fixture
// of a domain entity is part of that entity's vocabulary, and because features
// need them while being forbidden from importing `Data`.
//
// Not wrapped in `#if DEBUG`: SwiftUI previews compile in debug, but so do the
// test targets and the sample data in `Data`'s stubs, and the cost is a few
// bytes of literals.

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

extension User {
    static let sample = User(id: "u1", name: "Nguyễn Văn A", email: "a@example.com")
}

extension AuthSession {
    static let sample = AuthSession(user: .sample, accessToken: "access", refreshToken: "refresh")
}
