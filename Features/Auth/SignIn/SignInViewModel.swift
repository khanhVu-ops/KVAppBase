import Foundation
import KVDIKit
import KVLoggingKit
import KVRouterCore

@MainActor
final class SignInViewModel: ObservableObject {

    struct State: Equatable {
        var email = ""
        var password = ""
        var isSubmitting = false
        var fieldError: String?

        var canSubmit: Bool {
            !email.isEmpty && !password.isEmpty && !isSubmitting
        }
    }

    enum Action: Equatable {
        case emailChanged(String)
        case passwordChanged(String)
        case submitTapped
        case forgotPasswordTapped
    }

    @Published public private(set) var state = State()

    private let signIn: SignInUseCase
    private let router: any KVRouting
    private let toast: ToastService
    private let logger: ScopedLogClient

    /// Called after a successful sign-in so the composition root can open a
    /// session — the ViewModel does not know KVDIKit's session layer exists.
    private let onSignedIn: @MainActor (AuthSession) -> Void

    init(
        signIn: SignInUseCase,
        router: any KVRouting,
        toast: ToastService,
        logger: ScopedLogClient,
        onSignedIn: @escaping @MainActor (AuthSession) -> Void
    ) {
        self.signIn = signIn
        self.router = router
        self.toast = toast
        self.logger = logger
        self.onSignedIn = onSignedIn
    }

    convenience init(onSignedIn: @escaping @MainActor (AuthSession) -> Void) {
        @KVDependency(\.signInUseCase) var signIn
        @KVDependency(\.router) var router
        @KVDependency(\.toast) var toast
        @KVDependency(\.logger) var logger
        self.init(
            signIn: signIn,
            router: router,
            toast: toast,
            logger: logger.scoped(category: "auth.signin"),
            onSignedIn: onSignedIn
        )
    }

    func send(_ action: Action) {
        switch action {
        case .emailChanged(let email):
            state.email = email
            state.fieldError = nil

        case .passwordChanged(let password):
            state.password = password
            state.fieldError = nil

        case .submitTapped:
            submit()

        case .forgotPasswordTapped:
            router.push(AuthRoute.forgotPassword(email: state.email.isEmpty ? nil : state.email))
        }
    }

    private func submit() {
        guard state.canSubmit else { return }
        state.isSubmitting = true

        Task { [weak self] in
            guard let self else { return }
            defer { self.state.isSubmitting = false }
            do {
                let session = try await self.signIn(email: self.state.email, password: self.state.password)
                self.onSignedIn(session)
            } catch let error as SignInUseCase.ValidationError {
                // Validation belongs next to the field that failed, not in a
                // toast that disappears before the user can act on it.
                self.state.fieldError = error.userMessage
            } catch let error as AppError {
                self.toast.error(error)
                self.logger.warning("Đăng nhập thất bại")
            } catch {
                self.toast.error(.unknown(error.localizedDescription))
            }
        }
    }
}
