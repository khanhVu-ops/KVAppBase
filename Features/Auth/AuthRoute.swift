import Foundation
import KVRouterCore

enum AuthRoute: KVRestorableRoute {
    case signIn
    case forgotPassword(email: String?)
}
