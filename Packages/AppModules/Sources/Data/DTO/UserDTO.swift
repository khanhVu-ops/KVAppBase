import Foundation
import Domain

struct UserDTO: Decodable {
    let id: String
    let name: String?
    let email: String?

    func toDomain() -> User {
        User(id: id, name: name ?? "", email: email ?? "")
    }
}

struct AuthSessionDTO: Decodable {
    let user: UserDTO
    let accessToken: String
    let refreshToken: String

    func toDomain() -> AuthSession {
        AuthSession(
            user: user.toDomain(),
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }
}
