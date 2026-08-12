import SwiftUI

/// Typography as a closed set.
///
/// Every style goes through `.relativeTo:` so Dynamic Type still scales it — a
/// fixed `.system(size:)` ignores the accessibility setting and is the single
/// most common reason an app is unusable at large text sizes.
public enum AppFont {
    public static let titleL = Font.system(.largeTitle, design: .rounded).weight(.bold)
    public static let titleM = Font.system(.title2, design: .rounded).weight(.semibold)
    public static let body = Font.system(.body)
    public static let bodyStrong = Font.system(.body).weight(.semibold)
    public static let caption = Font.system(.caption)
    public static let mono = Font.system(.footnote, design: .monospaced)
}

public enum Spacing {
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 16
    public static let l: CGFloat = 24
    public static let xl: CGFloat = 32
}

public enum Radius {
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 20
}
