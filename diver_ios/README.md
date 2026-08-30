# diver_ios

A single Swift package that aggregates SwiftUI [type-safe navigation](https://developer.apple.com/documentation/swiftui/navigationstack) routes into `diver/app_urls.json` and uploads them to the Diver API — the iOS / Swift counterpart of [`diver_flutter_builder`](../diver_flutter_builder), [`diver_expo_builder`](../diver_expo_builder), and [`diver_android`](../diver_android).

As with the Android library, the **annotation and the builder live in one package** (three products):

- **`DiverRoute`** — a marker protocol you conform your route values to (the "annotation").
- **`DiverBuild`** — a SwiftPM command plugin (the "builder"): it runs a [SwiftSyntax](https://github.com/swiftlang/swift-syntax) scanner over your source and writes the JSON.
- **`diver-upload`** — an executable that POSTs the JSON to the Diver API.

Swift has no compile-time symbol processor like KSP, and macros can't aggregate across files or emit side files, so the builder is a **SwiftSyntax source scanner driven by a SwiftPM plugin** — the Swift analog of build_runner / KSP / the TypeScript compiler API.

## How routes are derived

SwiftUI type-safe routes are `Hashable`/`Codable` value types used with `navigationDestination(for:)`. You opt one in by conforming it to `DiverRoute`:

| Swift route | Derived deeplink |
| --- | --- |
| `struct Home: DiverRoute {}` | host `home` |
| `struct Profile: DiverRoute { let userId: String }` | host `profile`, path `:user-id` |
| `struct Settings: DiverRoute { var tab: String? }` | host `settings`, query `tab` |
| `struct ProductDetails: DiverRoute { let id: String; var ref: String? }` | host `product-details`, path `:id`, query `ref` |

Rules (identical to the Android builder):

- **host** = the type name, kebab-cased (`ProductDetails` → `product-details`).
- **path** = stored properties with no default and a non-optional type, in order, as `:name` segments.
- **query** = properties with a default value or an optional type, kebab-cased.
- A property whose type is a **closure or tuple** makes the route **skipped** (the iOS analog of Flutter's `$extra`); a warning is logged.

Routes are deduplicated by host+path and sorted by host then path.

### The syntax-only caveat

The scanner parses source — it does **not** type-check — so it can't tell an `enum` from an arbitrary `struct`. An unknown nominal type is therefore assumed to be a URL-serializable scalar and mapped to `string`. In practice this is fine: SwiftUI routes are `Codable`, so their properties are already serializable. If a route genuinely isn't deeplink-safe, simply don't conform it to `DiverRoute`.

### Query parameter types

| Swift type | Diver type |
| --- | --- |
| `String`, `Int`, `Double`, `Character`, an `enum`, any other nominal type | `string` |
| `Bool` | `boolean` |
| `[T]` / `Array<T>` | `list` |
| closure / tuple | route skipped |

Numbers map to `string`, matching the other Diver builders.

## Installation

Add the package to your app (Xcode → Add Package Dependencies, or in `Package.swift`):

```swift
.package(url: "https://github.com/Mikkelet/diver_ios.git", from: "0.1.0")
```

Add the **`DiverRoute`** library to your app target. The **`DiverBuild`** plugin is a command plugin — you don't link it; you invoke it (see below).

## Usage

Conform your route values and (optionally) add metadata as static string constants:

```swift
import DiverRoute

struct Settings: DiverRoute, Codable, Hashable {
    static let diverName = "Settings"
    static let diverDescription = "App settings screen"
    var tab: String?
}
```

Then run the builder, which writes `diver/app_urls.json` at the package root:

```sh
swift package --allow-writing-to-package-directory diver-build
```

(In Xcode, the same command is available under the target's context menu as **DiverBuild**.) Routes without `diverName` fall back to the derived URL (`host/path`) as the name and an empty description.

### Example output

```json
{
  "routes": [
    {
      "name": "Settings",
      "description": "App settings screen",
      "host": "settings",
      "path": "",
      "query": [{ "name": "tab", "type": "string" }]
    }
  ]
}
```

A runnable sample lives in [Sources/DiverSample](Sources/DiverSample); `swift package --allow-writing-to-package-directory diver-build` generates `diver/app_urls.json` from it.

## Uploading routes

The `diver-upload` executable injects `org_id`/`app_id` and POSTs the file to `https://api.diver.mthy.dev/import`:

```sh
swift run diver-upload                       # reads diver/app_urls.json
swift run diver-upload path/to/app_urls.json # or a custom path
```

Prerequisites:

- `diver/app_urls.json` must exist — run `diver-build` first.
- `ORG_ID` and `APP_ID` must be set, either as environment variables or in a `diver/diver_config.properties` file in the working directory (`KEY=value`, one per line):

  ```properties
  ORG_ID=your-org-id
  APP_ID=your-app-id
  ```

## Development

```sh
swift test                                                    # unit tests for route derivation + JSON
swift package --allow-writing-to-package-directory diver-build # run the scanner over the sample
```

## Layout

| Target | Role |
| --- | --- |
| `DiverRoute` | The `DiverRoute` marker protocol (imported by the app). |
| `DiverKit` | Pure route derivation + JSON encoding (SwiftSyntax-free, unit-tested). |
| `DiverScanner` | SwiftSyntax executable the plugin runs. |
| `DiverBuildPlugin` | The `diver-build` command plugin. |
| `DiverUpload` | The `diver-upload` executable. |
| `DiverSample` | Example routes, also used as scanner input. |
