import Foundation

private func loadConfig() -> [String: String] {
    let path = "diver/diver_config.properties"
    guard let content = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8) else {
        return [:]
    }
    var result: [String: String] = [:]
    for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") { continue }
        guard let eq = line.firstIndex(of: "=") else { continue }
        let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
        var value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
        if value.count >= 2,
           (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
            value = String(value.dropFirst().dropLast())
        }
        result[key] = value
    }
    return result
}

private func die(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let arguments = Array(CommandLine.arguments.dropFirst())
let filePath = arguments.first ?? "diver/app_urls.json"

guard FileManager.default.fileExists(atPath: filePath) else {
    die("""
    Error: \(filePath) not found.

    Generate it first with the Diver build plugin:
        swift package diver-build
    """)
}

// Environment variables take precedence over the properties file.
var config = loadConfig()
for (key, value) in ProcessInfo.processInfo.environment { config[key] = value }

guard let orgId = config["ORG_ID"], !orgId.isEmpty,
      let appId = config["APP_ID"], !appId.isEmpty else {
    die("""
    Error: ORG_ID and APP_ID must be set, either as environment variables or in
    diver/diver_config.properties (KEY=value format).
    """)
}

guard let fileData = FileManager.default.contents(atPath: filePath),
      var root = (try? JSONSerialization.jsonObject(with: fileData)) as? [String: Any] else {
    die("Error: \(filePath) is not valid JSON.")
}
root["org_id"] = orgId
root["app_id"] = appId

guard let body = try? JSONSerialization.data(withJSONObject: root) else {
    die("Error: failed to encode request body.")
}

let url = URL(string: "https://api.diver.mthy.dev/import")!
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = body

print("Uploading \(filePath) -> \(url.absoluteString)")
do {
    let (data, response) = try await URLSession.shared.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    if (200..<300).contains(status) {
        print("Upload succeeded (\(status)).")
    } else {
        die("Upload failed (\(status)): \(String(data: data, encoding: .utf8) ?? "")")
    }
} catch {
    die("Upload failed: \(error)")
}
