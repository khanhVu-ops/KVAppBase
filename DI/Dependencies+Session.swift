import Foundation
import KVDIKit

/// Values that only exist while somebody is signed in.
///
/// `nil` is the honest default: reading `currentUser` outside a session should
/// answer "nobody", not invent a placeholder user that code then treats as real.
enum CurrentUserKey: KVDependencyKey {
    static let liveValue: User? = nil
}

extension KVDependencyValues {
    var currentUser: User? {
        get { self[CurrentUserKey.self] }
        set { self[CurrentUserKey.self] = newValue }
    }
}
