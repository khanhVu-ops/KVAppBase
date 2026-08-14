import SwiftUI

/// Registered for `OrderRoute.history`. Kept minimal on purpose: the base
/// project ships one fully worked screen (the list) and one detail; this is the
/// third route so `.kvRoutes` has more than one case to switch on.
struct OrderHistoryView: View {
    init() {}

    var body: some View {
        EmptyStateView(
            icon: "clock.arrow.circlepath",
            title: "Order history",
            message: "Replace this with your real screen."
        )
        .navigationTitle("Order history")
    }
}

#Preview("Lịch sử đơn") {
    NavigationStack {
        OrderHistoryView()
    }
}
