import DiverRoute

// In a real app these are the Hashable/Codable values you pass to
// `navigationDestination(for:)`; conforming to DiverRoute opts them into the
// generated app_urls.json.

struct Home: DiverRoute, Codable, Hashable {
    static let diverName = "Home"
    static let diverDescription = "Landing screen"
}

struct Profile: DiverRoute, Codable, Hashable {
    static let diverName = "Profile"
    static let diverDescription = "User profile"
    let userId: String
}

struct Settings: DiverRoute, Codable, Hashable {
    static let diverName = "Settings"
    static let diverDescription = "App settings"
    var tab: String?
    var verbose: Bool = false
    var filters: [String] = []
}

// No metadata -> name falls back to the derived URL (host/path).
struct ProductDetails: DiverRoute, Codable, Hashable {
    let id: String
    var ref: String?
}

// A closure isn't reachable by URL, so this route is skipped (the iOS analog
// of Flutter's `$extra`).
struct Detail: DiverRoute {
    let present: () -> Void
}
