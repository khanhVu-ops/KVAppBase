import Foundation

// Stub cho luồng đăng nhập. Xem OrderStubs.swift để biết vì sao chúng không nằm
// trong test target.

struct StubAuthRepository: AuthRepositoryProtocol {
    var session: AuthSession
    var error: AppError?

    init(session: AuthSession = .sample, error: AppError? = nil) {
        self.session = session
        self.error = error
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        if let error { throw error }
        return session
    }

    func signOut() async {}
}
