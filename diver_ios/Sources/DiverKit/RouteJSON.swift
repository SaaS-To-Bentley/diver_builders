/// Encodes routes into the `{ "routes": [...] }` document the Diver `/import`
/// endpoint consumes. Routes are deduplicated by host+path and sorted by host
/// then path, and the key order / 2-space indentation match the other Diver
/// builders. Hand-built (rather than via JSONSerialization) to keep that key
/// order deterministic.
public enum RouteJSON {
    public static func encode(_ routes: [RouteModel]) -> String {
        var seen = Set<String>()
        let unique = routes
            .filter { seen.insert("\($0.host) \($0.path)").inserted }
            .sorted { $0.host != $1.host ? $0.host < $1.host : $0.path < $1.path }

        if unique.isEmpty {
            return "{\n  \"routes\": []\n}\n"
        }

        var out = "{\n  \"routes\": [\n"
        for (index, route) in unique.enumerated() {
            out += "    {\n"
            out += "      \"name\": \(string(route.name)),\n"
            out += "      \"description\": \(string(route.description)),\n"
            out += "      \"host\": \(string(route.host)),\n"
            out += "      \"path\": \(string(route.path)),\n"
            if route.query.isEmpty {
                out += "      \"query\": []\n"
            } else {
                out += "      \"query\": [\n"
                for (queryIndex, param) in route.query.enumerated() {
                    out += "        {\n"
                    out += "          \"name\": \(string(param.name)),\n"
                    out += "          \"type\": \(string(param.type))\n"
                    out += "        }" + (queryIndex == route.query.count - 1 ? "\n" : ",\n")
                }
                out += "      ]\n"
            }
            out += "    }" + (index == unique.count - 1 ? "\n" : ",\n")
        }
        out += "  ]\n}\n"
        return out
    }

    private static func string(_ value: String) -> String {
        var escaped = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"": escaped += "\\\""
            case "\\": escaped += "\\\\"
            case "\n": escaped += "\\n"
            case "\r": escaped += "\\r"
            case "\t": escaped += "\\t"
            default:
                if scalar.value < 0x20 {
                    escaped += String(format: "\\u%04x", scalar.value)
                } else {
                    escaped.unicodeScalars.append(scalar)
                }
            }
        }
        escaped += "\""
        return escaped
    }
}
