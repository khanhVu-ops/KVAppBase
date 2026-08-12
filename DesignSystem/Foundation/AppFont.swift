import SwiftUI

/// Typography as a closed set.
///
/// Every style goes through `.relativeTo:` so Dynamic Type still scales it — a
/// fixed `.system(size:)` ignores the accessibility setting and is the single
/// most common reason an app is unusable at large text sizes.
enum AppFont {
    static let titleL = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let titleM = Font.system(.title2, design: .rounded).weight(.semibold)
    static let body = Font.system(.body)
    static let bodyStrong = Font.system(.body).weight(.semibold)
    static let caption = Font.system(.caption)
    static let mono = Font.system(.footnote, design: .monospaced)
}

enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
}

enum Radius {
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 20
}
