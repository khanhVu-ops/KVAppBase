import Foundation

final class InMemoryTokenStore: TokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var access: String?
    private var refresh: String?

    init(access: String? = nil, refresh: String? = nil) {
        self.access = access
        self.refresh = refresh
    }

    var accessToken: String? { lock.withLock { access } }
    var refreshToken: String? { lock.withLock { refresh } }

    func save(access: String, refresh: String) {
        lock.withLock { self.access = access; self.refresh = refresh }
    }

    func clear() {
        lock.withLock { access = nil; refresh = nil }
    }
}
