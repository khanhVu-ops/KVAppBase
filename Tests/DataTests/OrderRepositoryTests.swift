import XCTest
import KVNetworkit
import KVLoggingKit
@testable import MyApp

/// Stubbed at the *transport* level rather than with a mock client, so these
/// exercise the real pipeline: interceptors, retry, decoding, error mapping.
/// A mock client would prove the repository calls something, not that the app
/// survives what the server actually sends.
final class OrderRepositoryTests: XCTestCase {

    private let url = URL(string: "https://api.test.local/api/v1/orders")!

    private func makeRepository(
        session: KVMockNetworkSession
    ) -> OrderRepository {
        OrderRepository(
            client: KVAPIClient(session: session, interceptors: [], retryPolicy: .never),
            logger: LogClient.disabled.scoped(category: "test")
        )
    }

    func test_list_decodesAndMapsToDomain() async throws {
        let json = """
        [{"id":"1","code":"DH-0001","customerName":"A","total":250000,"status":"shipping"}]
        """.data(using: .utf8)!

        let session = KVMockNetworkSession()
        session.enqueue(.success((json, KVMockNetworkSession.httpResponse(url: url, statusCode: 200))))

        let orders = try await makeRepository(session: session).list(forceRefresh: true)

        XCTAssertEqual(orders.count, 1)
        XCTAssertEqual(orders[0].code, "DH-0001")
        XCTAssertEqual(orders[0].status, .shipping)
    }

    func test_missingOptionalFields_fallBackInsteadOfThrowing() async throws {
        // Backends omit fields. A DTO that made everything non-optional would
        // turn a cosmetic omission into an empty screen.
        let json = #"[{"id":"7"}]"#.data(using: .utf8)!
        let session = KVMockNetworkSession()
        session.enqueue(.success((json, KVMockNetworkSession.httpResponse(url: url, statusCode: 200))))

        let orders = try await makeRepository(session: session).list(forceRefresh: true)

        XCTAssertEqual(orders[0].id, "7")
        XCTAssertEqual(orders[0].code, "7")
        XCTAssertEqual(orders[0].status, .pending)
    }

    func test_serverError_becomesAppErrorNotKVAPIClientError() async {
        let json = #"{"message":"Đơn hàng không tồn tại"}"#.data(using: .utf8)!
        let session = KVMockNetworkSession()
        session.enqueue(.success((json, KVMockNetworkSession.httpResponse(url: url, statusCode: 404))))

        do {
            _ = try await makeRepository(session: session).list(forceRefresh: true)
            XCTFail("Expected a failure")
        } catch let error as AppError {
            XCTAssertEqual(error, .server(message: "Đơn hàng không tồn tại", code: 404))
        } catch {
            XCTFail("A transport error escaped Data: \(error)")
        }
    }

    func test_malformedPayload_becomesDecodingError() async {
        let session = KVMockNetworkSession()
        session.enqueue(.success((Data("not json".utf8), KVMockNetworkSession.httpResponse(url: url, statusCode: 200))))

        do {
            _ = try await makeRepository(session: session).list(forceRefresh: true)
            XCTFail("Expected a failure")
        } catch let error as AppError {
            XCTAssertEqual(error, .decoding)
        } catch {
            XCTFail("A transport error escaped Data: \(error)")
        }
    }
}
