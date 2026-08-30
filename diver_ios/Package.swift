// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "diver-ios",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
    ],
    products: [
        // The "annotation": a marker protocol your route values conform to.
        .library(name: "DiverRoute", targets: ["DiverRoute"]),
        // The "builder": a command plugin that aggregates routes into JSON.
        .plugin(name: "DiverBuild", targets: ["DiverBuildPlugin"]),
        // The uploader.
        .executable(name: "diver-upload", targets: ["DiverUpload"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"700.0.0"),
    ],
    targets: [
        // Marker protocol — imported by the app, no dependencies.
        .target(name: "DiverRoute"),

        // Pure route-derivation + JSON logic, free of SwiftSyntax so it can be
        // unit-tested directly (mirrors the Android `internal` package).
        .target(name: "DiverKit"),

        // The scanner the plugin runs: parses Swift source with SwiftSyntax,
        // finds DiverRoute conformers, and writes diver/app_urls.json.
        .executableTarget(
            name: "DiverScanner",
            dependencies: [
                "DiverKit",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        // POSTs a generated app_urls.json to the Diver API.
        .executableTarget(name: "DiverUpload"),

        // Command plugin: `swift package diver-build`.
        .plugin(
            name: "DiverBuildPlugin",
            capability: .command(
                intent: .custom(
                    verb: "diver-build",
                    description: "Aggregate DiverRoute types into diver/app_urls.json"
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Write diver/app_urls.json")
                ]
            ),
            dependencies: ["DiverScanner"]
        ),

        // Demonstrates usage and doubles as scanner input for verification.
        .target(name: "DiverSample", dependencies: ["DiverRoute"]),

        .testTarget(name: "DiverKitTests", dependencies: ["DiverKit"]),
    ]
)
