import Foundation
import SwiftUI
import KVDIKit
import KVRouterKit
import KVLoggingKit
import Domain
import Data
import AppDI

/// Owns the signed-in/signed-out boundary.
///
/// One object decides it, so a 401 does not produce a logout race between five
/// screens, and per-user objects are released exactly once.
@MainActor
final class SessionController: ObservableObject {

    @Published private(set) var isSignedIn: Bool

    private let router: KVAppRouter
    private let logger: ScopedLogClient

    init(router: KVAppRouter, logger: LogClient) {
        self.router = router
        self.logger = logger.scoped(category: "session")
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
        router.popToRoot()
    }

    func signOut() {
        KeychainTokenStore.shared.clear()
        KVDependencies.endSession()
        isSignedIn = false
        router.popToRoot()
        logger.info("Signed out")
    }

    /// Anything can end a session — a failed token refresh, an account switch.
    /// Watching the boundary itself means the stack is reset once, wherever it
    /// came from.
    func observeSessionChanges() async {
        for await session in KVDependencies.sessionChanges where session == nil {
            router.popToRoot()
        }
    }
}
