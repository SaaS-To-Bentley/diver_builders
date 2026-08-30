import Foundation

/// A single stored property of a route type.
public struct ParamInfo: Equatable {
    public let name: String
    /// Diver query type (`string` / `boolean` / `list`), or nil when the type
    /// is not URL-serializable (a closure or tuple) — such routes are skipped.
    public let type: String?
    /// Optional properties (a default value or an optional type) become query
    /// parameters; required properties become path segments.
    public let optional: Bool

    public init(name: String, type: String?, optional: Bool) {
        self.name = name
        self.type = type
        self.optional = optional
    }
}

public struct QueryParam: Equatable {
    public let name: String
    public let type: String

    public init(name: String, type: String) {
        self.name = name
        self.type = type
    }
}

public struct RouteModel: Equatable {
    public let name: String
    public let description: String
    public let host: String
    public let path: String
    public let query: [QueryParam]

    public init(name: String, description: String, host: String, path: String, query: [QueryParam]) {
        self.name = name
        self.description = description
        self.host = host
        self.path = path
        self.query = query
    }
}

/// A property's type, reduced from Swift syntax to what Diver cares about.
/// Because the scanner is syntax-only (no type resolution), an unknown nominal
/// type is assumed to be a URL-serializable scalar (e.g. an enum) and mapped to
/// `string`; only closures/tuples are treated as unsupported.
public enum SwiftTypeKind: Equatable {
    case nominal(String)
    case array
    case unsupported
}

public enum RouteBuilder {
    private static let booleanTypes: Set<String> = ["Bool"]

    public static func diverType(_ kind: SwiftTypeKind) -> String? {
        switch kind {
        case .array:
            return "list"
        case .unsupported:
            return nil
        case .nominal(let name):
            return booleanTypes.contains(name) ? "boolean" : "string"
        }
    }

    /// CamelCase / camelCase → kebab-case, e.g. `ProductDetails` → `product-details`.
    public static func kebabCase(_ input: String) -> String {
        var result = replace(input, pattern: "([A-Z]+)([A-Z][a-z])")
        result = replace(result, pattern: "([a-z0-9])([A-Z])")
        return result.lowercased()
    }

    private static func replace(_ value: String, pattern: String) -> String {
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(value.startIndex..., in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: "$1-$2")
    }

    /// Builds the route description for a type, or nil when a property is not
    /// deeplink-safe (so the route is skipped). [simpleName] is the type name;
    /// [params] are its stored properties in declaration order.
    public static func build(
        simpleName: String,
        name: String,
        description: String,
        params: [ParamInfo]
    ) -> RouteModel? {
        if params.contains(where: { $0.type == nil }) { return nil }

        let host = kebabCase(simpleName)
        let pathParams = params.filter { !$0.optional }
        let queryParams = params.filter { $0.optional }

        let path = pathParams.map { ":" + kebabCase($0.name) }.joined(separator: "/")
        let query = queryParams.map { QueryParam(name: kebabCase($0.name), type: $0.type!) }

        let fallback = path.isEmpty ? host : "\(host)/\(path)"
        return RouteModel(
            name: name.isEmpty ? fallback : name,
            description: description,
            host: host,
            path: path,
            query: query
        )
    }
}
