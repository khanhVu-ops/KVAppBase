import Foundation

public struct User: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let email: String

    public init(id: String, name: String, email: String) {
        self.id = id
        self.name = name
        self.email = email
    }
}

/// The pair of tokens a sign-in produces. Deliberately not `Codable` here — the
/// wire format belongs to `Data`, and making this decodable would invite someone
/// to decode a response straight into it.
public struct AuthSession: Equatable, Sendable {
    public let user: User
    public let accessToken: String
    public let refreshToken: String

    public init(user: User, accessToken: String, refreshToken: String) {
        self.user = user
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}
