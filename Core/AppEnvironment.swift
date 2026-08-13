import Foundation

/// Build-time configuration, read from the Info.plist keys that `project.yml`
/// fills in from an xcconfig.
///
/// Reading it here rather than at each call site means a missing key fails once,
/// loudly, at launch — instead of producing a request to `https://` at runtime.
struct AppEnvironment: Sendable {
    let apiBaseURL: String
    let name: String

    /// Serve the app from in-memory fixtures instead of the network.
    ///
    /// A base project nobody can run is a base project nobody reads. Without
    /// this the sign-in screen is a dead end — there is no backend behind
    /// `api-dev.example.com` — and every screen after it is unreachable.
    /// Switch it off in `project.yml` the moment a real API exists.
    let usesStubBackend: Bool

    static let current: AppEnvironment = {
        let bundle = Bundle.main
        let baseURL = bundle.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        let name = bundle.object(forInfoDictionaryKey: "ENVIRONMENT_NAME") as? String

        // A missing key is a broken build configuration and should stop the app
        // at launch. But a unit-test bundle has no app Info.plist by design, and
        // asserting there turns every test that touches an endpoint into a crash
        // — which is exactly what happened the first time this ran.
        #if DEBUG
        assert(
            baseURL?.isEmpty == false || isRunningTests,
            "API_BASE_URL missing from Info.plist — check the xcconfig for this configuration"
        )
        #endif

        return AppEnvironment(
            apiBaseURL: baseURL ?? "https://api.test.local",
            name: name ?? (isRunningTests ? "test" : "debug"),
            usesStubBackend: bundle.object(forInfoDictionaryKey: "USES_STUB_BACKEND") as? String == "YES"
        )
    }()

    /// Tests run in a host-less bundle, so `Bundle.main` is the test runner.
    static let isRunningTests = NSClassFromString("XCTestCase") != nil

    var isProduction: Bool { name == "production" }
}
