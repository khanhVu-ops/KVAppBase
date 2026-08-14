import XCTest
import KVNetworkit
import KVLoggingKit
@testable import MyApp

/// Auth is injected into the client rather than built inside it, so that an app
/// with an API and no login does not have to fork `APIClientFactory`. That makes
/// the *slot* the contract: callers choose what goes in the middle, never where.
/// Nothing else checks the order, and getting it wrong is quiet — a token
/// attached after the logging interceptor has already printed the request looks
/// fine in the console and fails on the server.
final class APIClientFactoryTests: XCTestCase {

    private struct MarkerInterceptor: KVNetworkInterceptorProtocol {}

    private func interceptors(
        authInterceptors: [any KVNetworkInterceptorProtocol]
    ) throws -> [any KVNetworkInterceptorProtocol] {
        let client = APIClientFactory.make(
            environment: .current,
            logger: .disabled,
            authInterceptors: authInterceptors
        )
        return try XCTUnwrap(client as? KVAPIClient).interceptors
    }

    func test_withoutAuth_isConnectivityThenLogging() throws {
        let chain = try interceptors(authInterceptors: [])
        XCTAssertEqual(chain.count, 2)
        XCTAssertTrue(chain[0] is KVNetworkAwareInterceptor)
        XCTAssertTrue(chain[1] is KVLoggingInterceptor)
    }

    func test_authGoesBetweenConnectivityAndLogging_inTheOrderGiven() throws {
        let first = MarkerInterceptor()
        let second = MarkerInterceptor()
        let chain = try interceptors(authInterceptors: [first, second])

        XCTAssertEqual(chain.count, 4)
        XCTAssertTrue(chain[0] is KVNetworkAwareInterceptor)
        XCTAssertTrue(chain[1] is MarkerInterceptor)
        XCTAssertTrue(chain[2] is MarkerInterceptor)
        XCTAssertTrue(chain[3] is KVLoggingInterceptor)
    }
}
