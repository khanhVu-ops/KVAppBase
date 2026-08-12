import Foundation
import AppFoundation
import Domain
import AppDI
import KVDIKit
import KVLoggingKit
import KVRouterCore   // Core only — no SwiftUI here, so `pushView` is unreachable

/// State and Action are nested rather than living in a separate `Contract` file:
/// Swift can nest types, so the Android habit of a third file buys nothing here.
@MainActor
public final class OrderListViewModel: ObservableObject {

    // MARK: - State

    public struct State: Equatable {
        public var orders: Loadable<[Order]> = .idle
        public var query: String = ""
        public var alert: AlertState?

        /// Derived, not stored. A stored copy is a second source of truth that
        /// drifts the first time someone forgets to update it.
        public var visibleOrders: [Order] {
            guard let all = orders.value else { return [] }
            guard !query.isEmpty else { return all }
            return all.filter { $0.code.localizedCaseInsensitiveContains(query) }
        }

        public var showsEmptyState: Bool {
            if case .loaded(let orders) = orders { return orders.isEmpty }
            return false
        }
    }

    // MARK: - Action

    public enum Action: Equatable {
        case appeared
        case pulledToRefresh
        case queryChanged(String)
        case orderTapped(id: String)
        case retryTapped
        case alertDismissed
    }

    @Published public private(set) var state = State()

    private let repository: any OrderRepositoryProtocol
    private let router: any KVRouting
    private let toast: ToastService
    private let logger: ScopedLogClient

    /// Loading is a single in-flight task so a fast double pull-to-refresh
    /// cannot land two responses out of order.
    private var loadTask: Task<Void, Never>?

    // MARK: - Init

    /// Designated: tests pass fakes here, which is why nothing is resolved
    /// implicitly.
    public init(
        repository: any OrderRepositoryProtocol,
        router: any KVRouting,
        toast: ToastService,
        logger: ScopedLogClient
    ) {
        self.repository = repository
        self.router = router
        self.toast = toast
        self.logger = logger
    }

    /// Convenience: what a View calls. Keeping the designated init explicit
    /// means the dependencies are still readable at a glance, while the View
    /// gets to write `@StateObject private var viewModel = OrderListViewModel()`.
    public convenience init() {
        @KVDependency(\.orderRepository) var repository
        @KVDependency(\.router) var router
        @KVDependency(\.toast) var toast
        @KVDependency(\.logger) var logger
        self.init(
            repository: repository,
            router: router,
            toast: toast,
            logger: logger.scoped(category: "order.list")
        )
    }

    // MARK: - Action handling

    /// The only way `state` changes. Every mutation being reachable from one
    /// switch is what makes the screen's behaviour readable in one sitting, and
    /// what makes a test a list of `send(_:)` calls.
    public func send(_ action: Action) {
        switch action {
        case .appeared:
            // `.task` fires again after a background/foreground round trip, so
            // guard on idle or every return to the app refetches.
            guard case .idle = state.orders else { return }
            load(force: false)

        case .pulledToRefresh, .retryTapped:
            load(force: true)

        case .queryChanged(let query):
            // Filtering is local: the list is already in memory and a request
            // per keystroke would be slower and wrong offline.
            state.query = query

        case .orderTapped(let id):
            logger.info("Mở chi tiết đơn", metadata: ["order_id": .public(id)])
            router.push(OrderRoute.detail(id: id))

        case .alertDismissed:
            state.alert = nil
        }
    }

    // MARK: - Work

    private func load(force: Bool) {
        loadTask?.cancel()
        state.orders = state.orders.reloading()

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let orders = try await self.repository.list(forceRefresh: force)
                guard !Task.isCancelled else { return }
                self.state.orders = .loaded(orders)
            } catch let error as AppError {
                guard !Task.isCancelled else { return }
                self.handle(error)
            } catch {
                self.handle(.unknown(error.localizedDescription))
            }
        }
    }

    private func handle(_ error: AppError) {
        switch error {
        case .cancelled:
            // The user moved on. Not a failure; showing anything would be noise.
            break

        case .unauthorized:
            // Session expiry is handled once, centrally, by SessionController.
            // Every screen showing its own message would produce a pile of
            // alerts on the way out.
            break

        case .offline:
            // Content already on screen stays; the toast explains why it is stale.
            if state.orders.value == nil { state.orders = .failed(error) }
            toast.error(error)

        default:
            if state.orders.value == nil {
                state.orders = .failed(error)
            } else {
                state.alert = AlertState(error: error)
            }
        }
    }

    /// Test hook: lets a test await the in-flight load instead of sleeping.
    public func waitForLoad() async {
        await loadTask?.value
    }
}
