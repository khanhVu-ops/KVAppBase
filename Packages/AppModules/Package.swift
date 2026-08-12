// swift-tools-version: 6.2
import PackageDescription

// The dependency graph IS the architecture. Each target below lists exactly what
// it may see; anything missing from `dependencies` cannot be imported, so a
// layering mistake is a build error rather than a review comment.
//
//   Domain      → Foundation only
//   Data        → Domain + networking/logging
//   AppDI       → Domain + Data + KVDIKit          (the only place keys are declared)
//   DesignSystem→ AppFoundation + KVToastKit
//   Feature*    → Domain + DesignSystem + AppDI + KVRouterCore/Kit   (never Data)
let package = Package(
    name: "AppModules",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "AppFoundation", targets: ["AppFoundation"]),
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Data", targets: ["Data"]),
        .library(name: "AppDI", targets: ["AppDI"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "FeatureOrder", targets: ["FeatureOrder"]),
        .library(name: "FeatureAuth", targets: ["FeatureAuth"])
    ],
    dependencies: [
        .package(url: "https://github.com/khanhVu-ops/KVRouter.git", from: "3.1.0"),
        .package(url: "https://github.com/khanhVu-ops/KVDIKit.git", from: "1.0.0"),
        .package(url: "https://github.com/khanhVu-ops/KVNetworkit.git", from: "2.0.0"),
        .package(url: "https://github.com/khanhVu-ops/KVToastKit.git", from: "1.0.0"),
        .package(url: "https://github.com/khanhVu-ops/KVLoggingKit.git", from: "1.0.0")
    ],
    targets: [
        // MARK: - AppFoundation — no dependencies at all, on purpose.
        .target(
            name: "AppFoundation",
            path: "Sources/AppFoundation"
        ),

        // MARK: - Domain — pure Swift. No SwiftUI, no networking, no DI.
        .target(
            name: "Domain",
            dependencies: ["AppFoundation"],
            path: "Sources/Domain"
        ),

        // MARK: - Data — where KVNetworkit lives and where its errors die.
        .target(
            name: "Data",
            dependencies: [
                "Domain",
                .product(name: "KVNetworkit", package: "KVNetworkit"),
                .product(name: "KVLoggingKit", package: "KVLoggingKit")
            ],
            path: "Sources/Data"
        ),

        // MARK: - AppDI — the only target that declares dependency keys.
        .target(
            name: "AppDI",
            dependencies: [
                "Domain",
                "Data",
                .product(name: "KVDIKit", package: "KVDIKit"),
                .product(name: "KVNetworkit", package: "KVNetworkit"),
                .product(name: "KVLoggingKit", package: "KVLoggingKit"),
                .product(name: "KVRouterCore", package: "KVRouter")
            ],
            path: "Sources/AppDI"
        ),

        // Colours ship as an asset catalog rather than Swift literals so they
        // carry a dark variant and stay editable by whoever owns the design —
        // `figma-intake` regenerates this catalog, not the Swift file.
        .target(
            name: "DesignSystem",
            dependencies: [
                "AppFoundation",
                "Domain",
                .product(name: "KVToastKit", package: "KVToastKit")
            ],
            path: "Sources/DesignSystem",
            resources: [.process("Resources")]
        ),

        // MARK: - Features
        // KVRouterCore is what a ViewModel imports (no SwiftUI, so no `pushView`).
        // KVRouterKit is what a View imports. Both are available to the target;
        // which one a *file* imports is the rule, enforced by tools/check-arch.sh.
        .target(
            name: "FeatureOrder",
            dependencies: [
                "Domain",
                "DesignSystem",
                "AppDI",
                .product(name: "KVRouterCore", package: "KVRouter"),
                .product(name: "KVRouterKit", package: "KVRouter")
            ],
            path: "Sources/FeatureOrder"
        ),
        .target(
            name: "FeatureAuth",
            dependencies: [
                "Domain",
                "DesignSystem",
                "AppDI",
                .product(name: "KVRouterCore", package: "KVRouter"),
                .product(name: "KVRouterKit", package: "KVRouter")
            ],
            path: "Sources/FeatureAuth"
        ),

        // MARK: - Tests
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"],
            path: "Tests/DomainTests"
        ),
        .testTarget(
            name: "DataTests",
            dependencies: [
                "Data",
                .product(name: "KVNetworkit", package: "KVNetworkit")
            ],
            path: "Tests/DataTests"
        ),
        .testTarget(
            name: "FeatureOrderTests",
            dependencies: [
                "FeatureOrder",
                "Data",
                .product(name: "KVDIKit", package: "KVDIKit"),
                .product(name: "KVRouterTesting", package: "KVRouter")
            ],
            path: "Tests/FeatureOrderTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
