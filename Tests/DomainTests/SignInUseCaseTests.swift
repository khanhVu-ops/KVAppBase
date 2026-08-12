import XCTest
@testable import MyApp

/// Domain tests need no host, no network and no DI container — that is the
/// point of keeping the layer pure. They run in milliseconds.
final class SignInUseCaseTests: XCTestCase {

    private func makeUseCase(
        session: AuthSession = .sample,
        error: Error? = nil
    ) -> (SignInUseCase, SpyTokenStore) {
        let tokens = SpyTokenStore()
        let auth = FakeAuthRepository(session: session, error: error)
        return (SignInUseCase(auth: auth, tokens: tokens), tokens)
    }

    func test_emptyEmail_isRejectedBeforeAnyRequest() async {
        let (useCase, tokens) = makeUseCase()
        do {
            _ = try await useCase(email: "  ", password: "secret")
            XCTFail("Expected validation to fail")
        } catch let error as SignInUseCase.ValidationError {
            XCTAssertEqual(error, .emailEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        // The important half: a rejected form must not have hit the network or
        // written anything.
        XCTAssertNil(tokens.accessToken)
    }

    func test_shortPassword_isRejected() async {
        let (useCase, _) = makeUseCase()
        do {
            _ = try await useCase(email: "a@b.com", password: "123")
            XCTFail("Expected validation to fail")
        } catch let error as SignInUseCase.ValidationError {
            XCTAssertEqual(error, .passwordTooShort)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_success_persistsBothTokens() async throws {
        let (useCase, tokens) = makeUseCase()
        let session = try await useCase(email: "a@b.com", password: "secret")

        XCTAssertEqual(session.user.id, User.sample.id)
        XCTAssertEqual(tokens.accessToken, "access")
        XCTAssertEqual(tokens.refreshToken, "refresh")
    }
}

// MARK: - Doubles

private struct FakeAuthRepository: AuthRepositoryProtocol {
    let session: AuthSession
    let error: Error?

    func signIn(email: String, password: String) async throws -> AuthSession {
        if let error { throw error }
        return session
    }

    func signOut() async {}
}

private final class SpyTokenStore: TokenStoring, @unchecked Sendable {
    private(set) var accessToken: String?
    private(set) var refreshToken: String?

    func save(access: String, refresh: String) {
        accessToken = access
        refreshToken = refresh
    }

    func clear() {
        accessToken = nil
        refreshToken = nil
    }
}
