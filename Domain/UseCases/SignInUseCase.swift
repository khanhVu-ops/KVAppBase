import Foundation

/// Sign-in has three steps that must happen together and in order — validate,
/// authenticate, persist — so it is a use case rather than a straight call to
/// the repository.
///
/// The rule of thumb this base project follows: write a use case when there is
/// logic to hold (validation, orchestration across repositories, a business
/// rule). A one-line forward to a repository is not a use case, it is ceremony —
/// let the ViewModel call the repository directly in that case.
struct SignInUseCase: Sendable {

    private let auth: any AuthRepositoryProtocol
    private let tokens: any TokenStoring

    init(auth: any AuthRepositoryProtocol, tokens: any TokenStoring) {
        self.auth = auth
        self.tokens = tokens
    }

    enum ValidationError: Error, Equatable, Sendable {
        case emailEmpty, emailInvalid, passwordTooShort
    }

    func callAsFunction(email: String, password: String) async throws -> AuthSession {
        try validate(email: email, password: password)
        let session = try await auth.signIn(email: email, password: password)
        // Persisting here rather than in the repository keeps the repository a
        // pure data source: it answers questions, it does not change app state.
        tokens.save(access: session.accessToken, refresh: session.refreshToken)
        return session
    }

    func validate(email: String, password: String) throws {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { throw ValidationError.emailEmpty }
        guard email.contains("@"), email.contains(".") else { throw ValidationError.emailInvalid }
        guard password.count >= 6 else { throw ValidationError.passwordTooShort }
    }
}

extension SignInUseCase.ValidationError {
    var userMessage: String {
        switch self {
        // Key là chuỗi English của catalog — xem `AppError.userMessage` và skill
        // `ios-l10n`. `String(localized:)` là Foundation, nên `Domain` vẫn sạch.
        case .emailEmpty:       return String(localized: "Please enter your email.")
        case .emailInvalid:     return String(localized: "Invalid email address.")
        case .passwordTooShort: return String(localized: "Password must be at least 6 characters.")
        }
    }
}
