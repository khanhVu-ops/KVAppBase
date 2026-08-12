import Foundation
import KVNetworkit
import KVLoggingKit

final class AuthRepository: AuthRepositoryProtocol {

    private let client: any KVAPIClientProtocol
    private let tokenStore: any TokenStoring
    private let logger: ScopedLogClient

    init(
        client: any KVAPIClientProtocol,
        tokenStore: any TokenStoring,
        logger: ScopedLogClient
    ) {
        self.client = client
        self.tokenStore = tokenStore
        self.logger = logger
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        do {
            let dto: AuthSessionDTO = try await client.request(
                AuthEndpoint.signIn(email: email, password: password)
            )
            // The email is metadata, and metadata declared `.private` is kept out
            // of anything that leaves the device. Never interpolate it into the
            // message string — that text is not redacted the same way.
            logger.info("Đăng nhập thành công", metadata: ["email": .private(email)])
            return dto.toDomain()
        } catch {
            let mapped = AppError(networkError: error)
            logger.error("Đăng nhập thất bại", error: mapped)
            throw mapped
        }
    }

    func signOut() async {
        tokenStore.clear()
        logger.info("Đã đăng xuất")
    }
}
