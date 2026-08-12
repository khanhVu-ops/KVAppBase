import Foundation
import AppFoundation

public enum ToastKind: Equatable, Sendable {
    case info, success, warning, error
}

/// Raising a toast, expressed as a value so a ViewModel never imports KVToastKit.
///
/// A struct of closures rather than a protocol because it is `Sendable` without
/// being a class, and because a test double is one line:
/// `ToastService { message, _ in posted.append(message) }`.
public struct ToastService: Sendable {

    public var post: @Sendable (_ message: String, _ kind: ToastKind) -> Void

    public init(post: @escaping @Sendable (String, ToastKind) -> Void) {
        self.post = post
    }

    /// Used as the dependency's default value: a missing toast center should
    /// never be the reason a screen crashes.
    public static let noop = ToastService { _, _ in }

    public func info(_ message: String) { post(message, .info) }
    public func success(_ message: String) { post(message, .success) }
    public func warning(_ message: String) { post(message, .warning) }
    public func error(_ message: String) { post(message, .error) }

    /// Skips empty messages, so `toast.error(AppError.cancelled)` — whose
    /// `userMessage` is empty on purpose — shows nothing instead of a blank pill.
    public func error(_ error: AppError) {
        guard !error.userMessage.isEmpty else { return }
        post(error.userMessage, .error)
    }
}

// MARK: - Testing

/// Records what a ViewModel raised, so a test can assert on it.
///
/// A class with a lock rather than a captured `var`: `ToastService.post` is
/// `@Sendable`, so a local variable cannot be mutated from inside it under
/// Swift 6 — and the compiler is right, the call can arrive from any isolation.
public final class ToastRecorder: @unchecked Sendable {

    public struct Entry: Equatable, Sendable {
        public let message: String
        public let kind: ToastKind
    }

    private let lock = NSLock()
    private var storage: [Entry] = []

    public init() {}

    /// Hand this to the code under test.
    public var service: ToastService {
        ToastService { [weak self] message, kind in
            self?.append(Entry(message: message, kind: kind))
        }
    }

    public var entries: [Entry] { lock.withLock { storage } }
    public var messages: [String] { lock.withLock { storage.map(\.message) } }
    public var isEmpty: Bool { lock.withLock { storage.isEmpty } }

    private func append(_ entry: Entry) {
        lock.withLock { storage.append(entry) }
    }
}
