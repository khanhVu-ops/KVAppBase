import Foundation
import KVNetworkit

// The boundary. Every `throw` that leaves this module goes through here, so
// `KVAPIClientError` — and with it every assumption about HTTP — stops at the
// edge of Data. A ViewModel that had to switch on a status code would be a
// ViewModel that breaks when the transport changes.
extension AppError {

    init(networkError error: any Error) {
        guard let error = error as? KVAPIClientError else {
            self = .unknown(error.localizedDescription)
            return
        }

        switch error {
        case .taskCanceled:
            self = .cancelled

        case .unauthorized, .refreshTokenInvalid:
            self = .unauthorized

        case .serverMessage(let message, let statusCode):
            self = .server(message: message, code: statusCode)

        case .decodingFailed, .invalidResponse:
            // The backend changed shape. Users cannot act on it, so they get a
            // generic line while the real detail goes to the log.
            self = .decoding

        case .statusCode(let code):
            self = .server(message: nil, code: code)

        case .networkUnavailable, .timeout:
            self = .offline

        case .networkError, .requestFailed, .invalidURL, .taskInProgress:
            // `isNetworkConnectivityError` covers the URLError codes that mean
            // "the device cannot reach anything" — treating those as offline is
            // what keeps a flaky lift from looking like a broken app.
            self = error.isNetworkConnectivityError ? .offline : .unknown(error.localizedDescription)
        }
    }
}
