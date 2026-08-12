import Foundation

protocol AuthRepositoryProtocol: Sendable {
    func signIn(email: String, password: String) async throws -> AuthSession
    func signOut() async
}
