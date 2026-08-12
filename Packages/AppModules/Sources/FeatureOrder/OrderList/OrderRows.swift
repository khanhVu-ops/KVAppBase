import SwiftUI
import Domain
import DesignSystem

/// A child view that takes values and a closure — never the ViewModel.
///
/// Two reasons, and on iOS 16 the second is the one that bites:
/// 1. it previews and tests without a ViewModel;
/// 2. `Equatable` lets SwiftUI skip this whole subtree when `orders` has not
///    changed, which is the only mechanism available before `@Observable`.
///
/// `==` compares the data only: a closure is not comparable, and comparing
/// identity would defeat the purpose since the parent makes a new one each body.
struct OrderRows: View, Equatable {

    let orders: [Order]
    let onTap: (String) -> Void

    var body: some View {
        List(orders) { order in
            Button { onTap(order.id) } label: {
                OrderRow(order: order)
            }
            .buttonStyle(.plain)
            .listRowBackground(AppColor.Surface.card)
        }
        .listStyle(.plain)
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.orders == rhs.orders
    }
}

struct OrderRow: View, Equatable {

    let order: Order

    var body: some View {
        HStack(spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(order.code)
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(AppColor.Text.primary)
                Text(order.customerName)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }

            Spacer(minLength: Spacing.s)

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                Text(order.total, format: .currency(code: "VND"))
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(AppColor.Text.primary)
                OrderStatusBadge(status: order.status)
            }
        }
        .padding(.vertical, Spacing.s)
        // One element for VoiceOver: reading six fragments separately makes a
        // list unusable with the screen reader.
        .accessibilityElement(children: .combine)
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool { lhs.order == rhs.order }
}

struct OrderStatusBadge: View, Equatable {

    let status: Order.Status

    var body: some View {
        Text(label)
            .font(AppFont.caption)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool { lhs.status == rhs.status }

    private var label: String {
        switch status {
        case .pending:   return "Chờ xác nhận"
        case .confirmed: return "Đã xác nhận"
        case .shipping:  return "Đang giao"
        case .delivered: return "Đã giao"
        case .cancelled: return "Đã huỷ"
        }
    }

    private var tint: Color {
        switch status {
        case .pending, .confirmed: return AppColor.Semantic.warning
        case .shipping:            return AppColor.Semantic.info
        case .delivered:           return AppColor.Semantic.success
        case .cancelled:           return AppColor.Semantic.error
        }
    }
}

#Preview {
    NavigationStack {
        OrderRows(orders: Order.samples, onTap: { _ in })
    }
}
