import Foundation

// Fixtures for the signed-in user. See `Order+Samples.swift` for why these are
// not wrapped in `#if DEBUG`.

extension User {
    static let sample = User(id: "u1", name: "Nguyễn Văn A", email: "a@example.com")
}

extension AuthSession {
    static let sample = AuthSession(user: .sample, accessToken: "access", refreshToken: "refresh")
}
