import SwiftUI

/// Every colour in the app, named for what it *means* rather than what it *is*.
///
/// `Semantic.error` survives a designer changing red to orange; `red500` becomes
/// a lie the moment they do. A screen that writes `Color(red:green:blue:)` or a
/// hex literal is a screen that cannot be restyled — `tools/check-arch.sh` fails
/// the build on those.
enum AppColor {

    enum Brand {
        static let primary = Color("BrandPrimary")
        static let onPrimary = Color("BrandOnPrimary")
    }

    enum Semantic {
        static let success = Color("SemanticSuccess")
        static let warning = Color("SemanticWarning")
        static let error = Color("SemanticError")
        static let info = Color("SemanticInfo")
    }

    enum Surface {
        static let background = Color("SurfaceBackground")
        static let card = Color("SurfaceCard")
        static let separator = Color("SurfaceSeparator")
    }

    enum Text {
        static let primary = Color("TextPrimary")
        static let secondary = Color("TextSecondary")
        static let disabled = Color("TextDisabled")
    }
}
