import Foundation

/// Where credentials live, as far as the app is concerned.
///
/// A protocol rather than a concrete Keychain type so `Domain` never imports
/// Security, and so a test can run without touching the real keychain (which is
/// shared per-device and would make tests order-dependent).
public protocol TokenStoring: Sendable {
    var accessToken: String? { get }
    var refreshToken: String? { get }
    func save(access: String, refresh: String)
    func clear()
}
