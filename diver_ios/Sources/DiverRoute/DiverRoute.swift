/// Marks a SwiftUI type-safe navigation route as a Diver deeplink template.
///
/// Conform the value types you use as `NavigationStack` destinations (the same
/// `Hashable`/`Codable` route values you pass to `navigationDestination(for:)`)
/// to `DiverRoute`. The Diver build plugin scans the source for conformers and
/// derives a deeplink from each: the type name becomes the host, stored
/// properties without a default become path segments, and properties with a
/// default (or an optional type) become query parameters.
///
/// ```swift
/// struct Settings: DiverRoute, Codable, Hashable {
///     static let diverName = "Settings"
///     static let diverDescription = "App settings screen"
///     var tab: String?
/// }
/// ```
///
/// This is the iOS / Swift counterpart of the Dart `@DiverRoute` annotation,
/// the `defineDiverRoute` helper, and the Kotlin `@DiverRoute` annotation.
/// Metadata is optional: provide `diverName` / `diverDescription` as static
/// string-literal constants to get friendlier labels in Diver, or omit them to
/// fall back to the derived URL.
public protocol DiverRoute {
    /// Human-readable route name. Defaults to empty (the builder then uses the
    /// derived `host/path`).
    static var diverName: String { get }
    /// Human-readable route description. Defaults to empty.
    static var diverDescription: String { get }
}

public extension DiverRoute {
    static var diverName: String { "" }
    static var diverDescription: String { "" }
}
