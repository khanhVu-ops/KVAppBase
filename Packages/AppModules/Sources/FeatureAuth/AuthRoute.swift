import Foundation
import KVRouterCore

public enum AuthRoute: KVRestorableRoute {
    case signIn
    case forgotPassword(email: String?)
}
