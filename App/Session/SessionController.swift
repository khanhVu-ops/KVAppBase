import Foundation
import SwiftUI
import KVDIKit
import KVRouterKit
import KVLoggingKit

/// Owns the signed-in/signed-out boundary.
///
/// One object decides it, so a 401 does not produce a logout race between five
/// screens, and per-user objects are released exactly once.
@MainActor
final class SessionController: ObservableObject {

    @Published private(set) var isSignedIn: Bool

    /// Set after the router is built. `AuthGuardMiddleware` needs this object to
    /// answer "is anyone signed in", and the router needs the middleware, so one
    /// of the two has to be wired second.
    var router: KVAppRouter?

    private let logger: ScopedLogClient

    init(logger: LogClient) {
        self.logger = logger.scoped(category: "session")
        // Seeded from storage, then owned in memory. Anything asking whether a
        // user is signed in asks *this* — see AuthGuardMiddleware. Two places
        // reading the keychain independently is how the app ends up showing the
        // signed-in root while the guard redirects every push to sign-in, which
        // is exactly what happened before this was centralised.
        self.isSignedIn = KeychainTokenStore.shared.accessToken != nil
    }

    func didSignIn(_ session: AuthSession) {
        // Anything scoped to one user goes in the session layer, so signing out
        // releases it instead of leaving the previous user's objects alive.
        KVDependencies.startSession { values in
            values.currentUser = session.user
        }
        logger.info("Signed in", metadata: ["user_id": .public(session.user.id)])
        isSignedIn = true
        router?.popToRoot()
    }

    func signOut() {
        KeychainTokenStore.shared.clear()
        KVDependencies.endSession()
        isSignedIn = false
        router?.popToRoot()
        logger.info("Signed out")
    }

    /// Anything can end a session — a failed token refresh, an account switch.
    /// Watching the boundary itself means the stack is reset once, wherever it
    /// came from.
    func observeSessionChanges() async {
        for await session in KVDependencies.sessionChanges where session == nil {
            router?.popToRoot()
        }
    }
}
