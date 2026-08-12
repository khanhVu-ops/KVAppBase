import Foundation
import KVDIKit
import KVLoggingKit
import KVRouterCore

@MainActor
final class OrderDetailViewModel: ObservableObject {

    struct State: Equatable {
        var order: Loadable<Order>
        var isCancelling = false
        var alert: AlertState?
    }

    enum Action: Equatable {
        case appeared
        case cancelTapped
        case cancelConfirmed
        case alertDismissed
        case backTapped
    }

    @Published public private(set) var state: State

    private let orderID: String
    private let repository: any OrderRepositoryProtocol
    private let router: any KVRouting
    private let toast: ToastService
    private let logger: ScopedLogClient
    private var loadTask: Task<Void, Never>?

    init(
        orderID: String,
        seed: Order? = nil,
        repository: any OrderRepositoryProtocol,
        router: any KVRouting,
        toast: ToastService,
        logger: ScopedLogClient
    ) {
        self.orderID = orderID
        self.repository = repository
        self.router = router
        self.toast = toast
        self.logger = logger
        // A `seed` is the object the previous screen already had. Starting from
        // `.loaded` means arriving from the list renders instantly, while
        // arriving from a deep link (no seed) shows a spinner. Same screen,
        // honest about what it knows.
        self.state = State(order: seed.map { .loaded($0) } ?? .idle)
    }

    convenience init(orderID: String, seed: Order? = nil) {
        @KVDependency(\.orderRepository) var repository
        @KVDependency(\.router) var router
        @KVDependency(\.toast) var toast
        @KVDependency(\.logger) var logger
        self.init(
            orderID: orderID,
            seed: seed,
            repository: repository,
            router: router,
            toast: toast,
            logger: logger.scoped(category: "order.detail")
        )
    }

    func send(_ action: Action) {
        switch action {
        case .appeared:
            // Refresh even when seeded: the list's copy may be minutes old.
            load()

        case .cancelTapped:
            state.alert = AlertState(
                title: "Huỷ đơn hàng",
                message: "Bạn có chắc muốn huỷ đơn này? Thao tác không thể hoàn tác."
            )

        case .cancelConfirmed:
            state.alert = nil
            cancel()

        case .alertDismissed:
            state.alert = nil

        case .backTapped:
            router.pop()
        }
    }

    private func load() {
        loadTask?.cancel()
        state.order = state.order.reloading()
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let order = try await self.repository.detail(id: self.orderID)
                guard !Task.isCancelled else { return }
                self.state.order = .loaded(order)
            } catch let error as AppError {
                guard !Task.isCancelled, error != .cancelled, error != .unauthorized else { return }
                if self.state.order.value == nil {
                    self.state.order = .failed(error)
                } else {
                    self.toast.error(error)
                }
            } catch {}
        }
    }

    private func cancel() {
        guard !state.isCancelling else { return }
        state.isCancelling = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.state.isCancelling = false }
            do {
                let order = try await self.repository.cancel(id: self.orderID)
                self.state.order = .loaded(order)
                self.toast.success("Đã huỷ đơn hàng")
                self.logger.info("Huỷ đơn thành công", metadata: ["order_id": .public(self.orderID)])
            } catch let error as AppError {
                self.toast.error(error)
            } catch {}
        }
    }

    func waitForLoad() async { await loadTask?.value }
}
