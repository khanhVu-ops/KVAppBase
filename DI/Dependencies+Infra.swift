import Foundation
import KVDIKit
import KVLoggingKit
import KVRouterCore

// Every dependency key in the app is declared in this module and nowhere else.
// Features read keys; only the composition root writes them. That is what keeps
// a feature from reaching into `Data` for a concrete type.
//
// This file holds what *every* app has, whatever it does: a logger, a router, a
// way to toast. Networking lives in `Dependencies+Network.swift` and sign-in in
// `Dependencies+Auth.swift` — an app with no backend deletes those two files and
// nothing here notices, which is the whole point of splitting them.

// MARK: - Logger

/// `.disabled` is a working logger that drops everything, so a bootstrap failure
/// costs logs rather than a crash. `AppBootstrap` replaces it at launch.
enum LoggerKey: KVDependencyKey {
    static let liveValue: LogClient = .disabled
    static let testValue: LogClient = .disabled
}

// MARK: - Router

/// The router is a `@MainActor` object that only exists once `App.init` has run,
/// so the key ships a placeholder and `KVDependencies.prepare` swaps in the real
/// one.
///
/// `KVUnhostedRouter` (KVRouterCore) no-ops and trips `assertionFailure` on the
/// first command, naming it. Both obvious alternatives are worse — a real
/// unhosted `KVAppRouter` swallows pushes into an invisible stack, and a silent
/// no-op reads as a broken button and gets debugged from the wrong end.
enum RouterKey: KVDependencyKey {
    static let liveValue: any KVRouting = KVUnhostedRouter()
    static let testValue: any KVRouting = KVUnhostedRouter()
}

// MARK: - Toast

enum ToastKey: KVDependencyKey {
    static let liveValue: ToastService = .noop
    static let testValue: ToastService = .noop
}

// MARK: - Values

extension KVDependencyValues {

    var logger: LogClient {
        get { self[LoggerKey.self] }
        set { self[LoggerKey.self] = newValue }
    }

    var router: any KVRouting {
        get { self[RouterKey.self] }
        set { self[RouterKey.self] = newValue }
    }

    var toast: ToastService {
        get { self[ToastKey.self] }
        set { self[ToastKey.self] = newValue }
    }
}
