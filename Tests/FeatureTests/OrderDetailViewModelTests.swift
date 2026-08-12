import XCTest
import KVRouterTesting
import KVLoggingKit
@testable import MyApp

@MainActor
final class OrderDetailViewModelTests: XCTestCase {

    private func makeViewModel(
        orderID: String = "1",
        seed: Order? = nil,
        repository: any OrderRepositoryProtocol = StubOrderRepository(),
        toast: ToastService = .noop
    ) -> (OrderDetailViewModel, KVRouterSpy) {
        let router = KVRouterSpy()
        return (
            OrderDetailViewModel(
                orderID: orderID,
                seed: seed,
                repository: repository,
                router: router,
                toast: toast,
                logger: LogClient.disabled.scoped(category: "test")
            ),
            router
        )
    }

    func test_seededFromList_rendersImmediatelyWithoutSpinner() {
        let (viewModel, _) = makeViewModel(seed: .sample(id: "1"))

        // Arriving from `pushView { OrderDetailView(order:) }` means the object
        // is already in hand — the screen must not flash a loading state.
        XCTAssertNotNil(viewModel.state.order.value)
        XCTAssertFalse(viewModel.state.order.isLoading)
    }

    func test_openedFromDeepLink_startsIdleThenLoads() async {
        let (viewModel, _) = makeViewModel(orderID: "2")

        XCTAssertNil(viewModel.state.order.value)
        viewModel.send(.appeared)
        await viewModel.waitForLoad()
        XCTAssertEqual(viewModel.state.order.value?.id, "2")
    }

    func test_cancelTapped_asksBeforeCancelling() async {
        let (viewModel, _) = makeViewModel(seed: .sample())

        viewModel.send(.cancelTapped)

        // Confirmation is state, not an effect: it survives a rebuild and can be
        // asserted here without touching SwiftUI.
        XCTAssertNotNil(viewModel.state.alert)
        XCTAssertEqual(viewModel.state.order.value?.status, .pending)
    }

    func test_cancelConfirmed_updatesStatusAndReportsSuccess() async {
        let toast = ToastRecorder()
        let (viewModel, _) = makeViewModel(seed: .sample(), toast: toast.service)

        viewModel.send(.cancelTapped)
        viewModel.send(.cancelConfirmed)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertNil(viewModel.state.alert)
        XCTAssertEqual(viewModel.state.order.value?.status, .cancelled)
        XCTAssertEqual(toast.entries.first?.kind, .success)
    }

    func test_backTapped_popsExactlyOnce() {
        let (viewModel, router) = makeViewModel(seed: .sample())

        viewModel.send(.backTapped)

        XCTAssertEqual(router.operations, [.pop])
    }
}
