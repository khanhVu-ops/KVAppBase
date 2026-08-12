import SwiftUI
import KVRouterKit

// The only place in the app where a route meets a view.
//
// Each feature registers its own route type, so `FeatureOrder` never has to know
// `FeatureAuth` exists and no single enum has to be edited by everyone. A route
// type that is never registered trips an assertion in debug rather than
// rendering a blank screen.
extension View {

    func appRoutes() -> some View {
        kvRoutes { routes in

            routes.register(OrderRoute.self) { route in
                switch route {
                case .detail(let id): OrderDetailView(orderID: id)
                case .history:        OrderHistoryView()
                }
            }

            routes.register(AuthRoute.self) { route in
                switch route {
                case .signIn:                    SignInView(onSignedIn: { _ in })
                case .forgotPassword(let email): ForgotPasswordView(email: email)
                }
            }
        }
    }
}
