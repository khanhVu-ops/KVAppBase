import SwiftUI

/// Every colour in the app, named for what it *means* rather than what it *is*.
///
/// `Semantic.error` survives a designer changing red to orange; `red500` becomes
/// a lie the moment they do. A screen that writes `Color(red:green:blue:)` or a
/// hex literal is a screen that cannot be restyled — `tools/check-arch.sh` fails
/// the build on those.
public enum AppColor {

    public enum Brand {
        public static let primary = Color("BrandPrimary", bundle: .module)
        public static let onPrimary = Color("BrandOnPrimary", bundle: .module)
    }

    public enum Semantic {
        public static let success = Color("SemanticSuccess", bundle: .module)
        public static let warning = Color("SemanticWarning", bundle: .module)
        public static let error = Color("SemanticError", bundle: .module)
        public static let info = Color("SemanticInfo", bundle: .module)
    }

    public enum Surface {
        public static let background = Color("SurfaceBackground", bundle: .module)
        public static let card = Color("SurfaceCard", bundle: .module)
        public static let separator = Color("SurfaceSeparator", bundle: .module)
    }

    public enum Text {
        public static let primary = Color("TextPrimary", bundle: .module)
        public static let secondary = Color("TextSecondary", bundle: .module)
        public static let disabled = Color("TextDisabled", bundle: .module)
    }
}
