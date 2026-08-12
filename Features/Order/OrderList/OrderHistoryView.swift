import SwiftUI

/// Registered for `OrderRoute.history`. Kept minimal on purpose: the base
/// project ships one fully worked screen (the list) and one detail; this is the
/// third route so `.kvRoutes` has more than one case to switch on.
struct OrderHistoryView: View {
    init() {}

    var body: some View {
        EmptyStateView(
            icon: "clock.arrow.circlepath",
            title: "Lịch sử đơn hàng",
            message: "Thay nội dung này bằng màn hình thật của bạn."
        )
        .navigationTitle("Lịch sử")
    }
}
