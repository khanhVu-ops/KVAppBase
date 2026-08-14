import Foundation

enum ToastKind: Equatable, Sendable {
    case info, success, warning, error
}

/// Raising a toast, expressed as a value so a ViewModel never imports KVToastKit.
///
/// A struct of closures rather than a protocol because it is `Sendable` without
/// being a class, and because a test double is one line:
/// `ToastService { message, _ in posted.append(message) }`.
struct ToastService: Sendable {

    var post: @Sendable (_ message: LocalizedStringResource, _ kind: ToastKind) -> Void

    init(post: @escaping @Sendable (LocalizedStringResource, ToastKind) -> Void) {
        self.post = post
    }

    /// Used as the dependency's default value: a missing toast center should
    /// never be the reason a screen crashes.
    static let noop = ToastService { _, _ in }

    func info(_ message: LocalizedStringResource) { post(message, .info) }
    func success(_ message: LocalizedStringResource) { post(message, .success) }
    func warning(_ message: LocalizedStringResource) { post(message, .warning) }
    func error(_ message: LocalizedStringResource) { post(message, .error) }

    /// `.cancelled` có `userMessage` là `nil` nên nó không hiện gì, thay vì hiện một
    /// viên toast rỗng.
    func error(_ error: AppError) {
        guard let message = error.userMessage else { return }
        post(message, .error)
    }
}

// MARK: - Testing

/// Records what a ViewModel raised, so a test can assert on it.
///
/// A class with a lock rather than a captured `var`: `ToastService.post` is
/// `@Sendable`, so a local variable cannot be mutated from inside it under
/// Swift 6 — and the compiler is right, the call can arrive from any isolation.
final class ToastRecorder: @unchecked Sendable {

    struct Entry: Equatable, Sendable {
        let message: LocalizedStringResource
        let kind: ToastKind
    }

    private let lock = NSLock()
    private var storage: [Entry] = []

    init() {}

    /// Hand this to the code under test.
    var service: ToastService {
        ToastService { [weak self] message, kind in
            self?.append(Entry(message: message, kind: kind))
        }
    }

    var entries: [Entry] { lock.withLock { storage } }
    var messages: [LocalizedStringResource] { lock.withLock { storage.map(\.message) } }
    var isEmpty: Bool { lock.withLock { storage.isEmpty } }

    private func append(_ entry: Entry) {
        lock.withLock { storage.append(entry) }
    }
}
