import XCTest
@testable import MyApp

/// `Core` is the one layer every app built from this template keeps, whatever it
/// does — a tool app with no backend still has these. So this file is also the
/// floor: it is what stops `verify.sh` from going green over a test suite that
/// has nothing left in it.
final class LoadableTests: XCTestCase {

    // The rule worth pinning: a refresh of content already on screen must not
    // drop back to `.loading`, or every pull-to-refresh replaces what the user
    // was reading with a spinner.
    func test_reloading_keepsContentOnScreen() {
        let loaded = Loadable<[Int]>.loaded([1, 2, 3])
        XCTAssertEqual(loaded.reloading(), loaded)
    }

    func test_reloading_fromAnyOtherState_showsSpinner() {
        XCTAssertEqual(Loadable<[Int]>.idle.reloading(), .loading)
        XCTAssertEqual(Loadable<[Int]>.loading.reloading(), .loading)
        XCTAssertEqual(
            Loadable<[Int]>.failed(.offline).reloading(),
            .loading
        )
    }

    func test_accessors_readOnlyTheirOwnCase() {
        XCTAssertEqual(Loadable<[Int]>.loaded([7]).value, [7])
        XCTAssertNil(Loadable<[Int]>.loading.value)
        XCTAssertEqual(Loadable<[Int]>.failed(.offline).error, .offline)
        XCTAssertNil(Loadable<[Int]>.loaded([7]).error)
        XCTAssertTrue(Loadable<[Int]>.loading.isLoading)
        XCTAssertFalse(Loadable<[Int]>.loaded([7]).isLoading)
    }
}

final class AppLanguageTests: XCTestCase {

    /// `.system` is not a language code — resolving it has to fall through to the
    /// device, and a `Locale` built from the raw value "system" would silently be
    /// a locale nobody has.
    func test_systemLanguage_resolvesToTheDevice() {
        XCTAssertNotEqual(AppLanguage.system.code, "system")
        XCTAssertEqual(
            AppLanguage.system.code,
            Locale.preferredLanguages.first ?? "en"
        )
    }

    func test_explicitLanguage_resolvesToItsOwnCode() {
        XCTAssertEqual(AppLanguage.vietnamese.code, "vi")
        XCTAssertEqual(AppLanguage.chineseHans.locale.identifier, "zh-Hans")
    }

    /// Duplicated raw values would give two picker rows the same `id`, and
    /// SwiftUI answers that with a list that will not update.
    func test_everyLanguageHasADistinctIdentifier() {
        let ids = AppLanguage.allCases.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}
