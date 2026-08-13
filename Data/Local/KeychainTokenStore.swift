import Foundation
import Security

/// Tokens in the keychain, not `UserDefaults`.
///
/// `UserDefaults` is a plist in the app container: readable from a backup, and
/// readable by anything that gets file access. A token there is a token you
/// have published.
final class KeychainTokenStore: TokenStoring, @unchecked Sendable {

    static let shared = KeychainTokenStore()

    private let service: String
    private let lock = NSLock()

    init(service: String = Bundle.main.bundleIdentifier ?? "app.tokens") {
        self.service = service
    }

    var accessToken: String? { read(key: Key.access) }
    var refreshToken: String? { read(key: Key.refresh) }

    func save(access: String, refresh: String) {
        write(access, key: Key.access)
        write(refresh, key: Key.refresh)
    }

    func clear() {
        delete(key: Key.access)
        delete(key: Key.refresh)
    }

    private enum Key {
        static let access = "access_token"
        static let refresh = "refresh_token"
    }

    private func query(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }

    private func read(key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        var query = query(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ value: String, key: String) {
        lock.lock(); defer { lock.unlock() }
        let query = query(key)
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            // `AfterFirstUnlock` rather than `WhenUnlocked`: a background refresh
            // or a push-triggered fetch runs with the screen locked, and would
            // otherwise find no token and sign the user out.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        }
        // A dropped write means the user is signed out on next launch with
        // nothing on screen to explain it, so it must not pass unnoticed. But
        // the noisiest case is not a bug: an unsigned simulator build
        // (CODE_SIGNING_ALLOWED=NO) has no keychain entitlement and every write
        // returns errSecMissingEntitlement. Trapping on that turns `swift run
        // the template` into a crash on sign-in, so it is reported and
        // tolerated; anything else is a real defect and stops the debug build.
        switch status {
        case errSecSuccess:
            break
        case errSecMissingEntitlement:
            print("[Keychain] no entitlement (unsigned build): '\(key)' not persisted, session is memory-only")
        default:
            assertionFailure("Keychain write failed for '\(key)': OSStatus \(status)")
        }
    }

    private func delete(key: String) {
        lock.lock(); defer { lock.unlock() }
        SecItemDelete(query(key) as CFDictionary)
    }
}
