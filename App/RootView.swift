import SwiftUI

/// Chooses the root screen from session state. Sign-in is not pushed onto the
/// stack: swapping the root means there is no back gesture out of the login
/// screen and nothing of the signed-in session left underneath it.
struct RootView: View {

    @ObservedObject var session: SessionController

    var body: some View {
        Group {
            if session.isSignedIn {
                OrderListView()
            } else {
                SignInView(onSignedIn: session.didSignIn)
            }
        }
        .background(AppColor.Surface.background)
    }
}
