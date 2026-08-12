import XCTest
import KVRouterTesting
import KVRouterCore
import KVLoggingKit
@testable import MyApp

/// ViewModel tests: send an action, assert the state and the navigation.
/// No SwiftUI, no host, no `settle()`, no sleeping — `KVRouterSpy` records
/// synchronously, which is what makes a *negative* assertion ("did not
/// navigate") provable instead of a race with a timeout.
@MainActor
final class OrderListViewModelTests: XCTestCase {

    private func makeViewModel(
        repository: any OrderRepositoryProtocol = StubOrderRepository(),
        router: KVRouterSpy = KVRouterSpy(),
        toast: ToastService = .noop
    ) -> (OrderListViewModel, KVRouterSpy) {
        let viewModel = OrderListViewModel(
            repository: repository,
            router: router,
            toast: toast,
            logger: LogClient.disabled.scoped(category: "test")
        )
        return (viewModel, router)
    }

    // MARK: - Loading

    func test_appeared_loadsOrders() async {
        let (viewModel, _) = makeViewModel()

        viewModel.send(.appeared)
        await viewModel.waitForLoad()

        XCTAssertEqual(viewModel.state.orders.value?.count, 3)
    }

    func test_appearedTwice_doesNotRefetch() async {
        // `.task` re-fires after a background round trip; without the idle guard
        // every return to the app would refetch and flash a spinner.
        let counting = CountingRepository()
        let (viewModel, _) = makeViewModel(repository: counting)

        viewModel.send(.appeared)
        await viewModel.waitForLoad()
        viewModel.send(.appeared)
        await viewModel.waitForLoad()

        XCTAssertEqual(counting.listCallCount, 1)
    }

    func test_pullToRefresh_keepsExistingContentOnScreen() async {
        let (viewModel, _) = makeViewModel()
        viewModel.send(.appeared)
        await viewModel.waitForLoad()

        viewModel.send(.pulledToRefresh)

        // Still `.loaded` while the refresh is in flight: dropping to `.loading`
        // would replace the list with a spinner on every pull.
        XCTAssertNotNil(viewModel.state.orders.value)
        await viewModel.waitForLoad()
    }

    // MARK: - Failure

    func test_offline_showsToastAndFailedState() async {
        let toast = ToastRecorder()
        let (viewModel, _) = makeViewModel(
            repository: StubOrderRepository(error: .offline),
            toast: toast.service
        )

        viewModel.send(.appeared)
        await viewModel.waitForLoad()

        XCTAssertEqual(viewModel.state.orders.error, .offline)
        XCTAssertEqual(toast.entries.map(\.kind), [.error])
    }

    func test_unauthorized_isLeftToTheSessionController() async {
        // Every screen showing its own "session expired" message produces a
        // stack of alerts on the way out. One place handles it.
        let toast = ToastRecorder()
        let (viewModel, _) = makeViewModel(
            repository: StubOrderRepository(error: .unauthorized),
            toast: toast.service
        )

        viewModel.send(.appeared)
        await viewModel.waitForLoad()

        XCTAssertTrue(toast.isEmpty)
        XCTAssertNil(viewModel.state.alert)
    }

    // MARK: - Navigation

    func test_orderTapped_pushesDetailRoute() async {
        let (viewModel, router) = makeViewModel()

        viewModel.send(.orderTapped(id: "42"))

        XCTAssertEqual(router.operations, [.push(AnyKVRoute(OrderRoute.detail(id: "42")))])
    }

    func test_queryChanged_filtersLocallyWithoutNavigating() async {
        let (viewModel, router) = makeViewModel()
        viewModel.send(.appeared)
        await viewModel.waitForLoad()

        viewModel.send(.queryChanged("DH-0002"))

        XCTAssertEqual(viewModel.state.visibleOrders.map(\.code), ["DH-0002"])
        XCTAssertTrue(router.operations.isEmpty)
    }
}

// MARK: - Doubles

private final class CountingRepository: OrderRepositoryProtocol, @unchecked Sendable {
    private(set) var listCallCount = 0

    func list(forceRefresh: Bool) async throws -> [Order] {
        listCallCount += 1
        return Order.samples
    }

    func detail(id: String) async throws -> Order { .sample(id: id) }
    func cancel(id: String) async throws -> Order { .sample(id: id, status: .cancelled) }
}
