import Foundation

struct User: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let name: String
    let email: String

    init(id: String, name: String, email: String) {
        self.id = id
        self.name = name
        self.email = email
    }
}

/// The pair of tokens a sign-in produces. Deliberately not `Codable` here — the
/// wire format belongs to `Data`, and making this decodable would invite someone
/// to decode a response straight into it.
struct AuthSession: Equatable, Sendable {
    let user: User
    let accessToken: String
    let refreshToken: String

    init(user: User, accessToken: String, refreshToken: String) {
        self.user = user
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}
