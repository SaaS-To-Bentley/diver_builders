# diver_builders

Build-time route aggregators for Diver, one per app platform. Each package does the
same two things for the framework it targets:

1. **Aggregate** — at build time, read the app's own routing declarations and write
   every deeplink-safe route to `diver/app_urls.json`.
2. **Upload** — POST that file to the Diver API (`api.diver.mthy.dev`) so the routes
   are registered for the app.

Nothing here ships at runtime: the annotations are compile-time only and the JSON is
a build artifact.

## Packages

| Package | Platform | Reads | Mechanism |
| --- | --- | --- | --- |
| [`diver_flutter_builder`](diver_flutter_builder) | Flutter / Dart | go_router `@TypedGoRoute` and auto_route `@AutoRouterConfig` / `@RoutePage` | `build_runner` builder |
| [`diver_android`](diver_android) | Android / Kotlin | Jetpack Navigation type-safe routes marked `@DiverRoute` | KSP processor |
| [`diver_ios`](diver_ios) | iOS / Swift | SwiftUI navigation values conforming to `DiverRoute` | SwiftPM command plugin over a SwiftSyntax scanner |
| [`diver_expo_builder`](diver_expo_builder) | Expo / React Native | Expo Router's file-based `app/` tree | CLI |

Android and iOS keep the marker and the builder in one artifact. Flutter splits them:
the optional `@DiverRoute` metadata annotation is its own package,
[`diver_flutter_annotation`](diver_flutter_annotation), so an app can depend on it at
runtime without pulling in the build-time builder.

## The shared output

Every package writes the same shape, sorted by host then path and deduplicated by
host + path:

```json
{
  "routes": [
    {
      "name": "Product search",
      "description": "Full-text product search.",
      "host": "search",
      "path": "",
      "query": [
        { "name": "term", "type": "string", "required": true }
      ]
    }
  ]
}
```

- **host** — the first URL segment (Flutter, Expo) or the kebab-cased route type name
  (Android, iOS).
- **path** — the remaining segments, with parameters as `:name`.
- **query** — parameters that aren't part of the path. `type` is one of `string`,
  `boolean`, or `list`; numbers map to `string` on every platform. `required` is false
  whenever the app can construct the route without the value (a default or a nullable
  type).
- **name** / **description** — from the platform's metadata hook (`@DiverRoute`,
  `diverName`, an exported `diverRoute` constant), falling back to the derived
  `host/path` and an empty description.

A route that needs a value a URL cannot carry — a runtime object passed in-app, such
as go_router's required `$extra` — is not deeplink-safe and is left out. The Flutter
builder records those in `diver/app_urls_errors.json` with the reason; the others log
a warning and skip.

## Uploading

Each package ships its own upload entry point, all reading `diver/app_urls.json` and
all configured the same way — environment variables, or a `diver/diver_config.properties`
file (`KEY=value`, one per line) in the working directory:

```properties
ORG_ID=your-org-id
APP_ID=your-app-id
DIVER_API_KEY=dk_your-api-key
```

| Package | Build | Upload |
| --- | --- | --- |
| `diver_flutter_builder` | `dart run build_runner build` | `dart run diver_flutter_builder:upload_urls` |
| `diver_android` | `./gradlew :app:assembleDebug` | `./gradlew :app:diverUpload` |
| `diver_ios` | `swift package --allow-writing-to-package-directory diver-build` | `swift run diver-upload` |
| `diver_expo_builder` | `npx diver-expo-builder build` | `npx diver-expo-builder upload` |

The Flutter builder deletes `diver/app_urls.json` after each build unless its
`keep_generated` option is set, so set that first or the upload finds no file.

`ORG_ID` and `APP_ID` are read by all four. `DIVER_API_KEY` authenticates the upload
as an org-scoped machine caller (create one in the Diver dashboard under
**Organization → Members → API keys**) and is sent as `Authorization: Bearer <key>`.

The uploaders are not yet in sync on that last point: the Flutter and Expo ones
require the key and post to `/organizations/{org}/apps/{app}/import`, while the
Android and iOS ones still post unauthenticated to `/import`. See each package's
README for its exact prerequisites and options.

## Working in this repo

Every package is a plain in-tree directory, so a single `git clone` gets all of them.

One leftover from when `diver_flutter_builder` was a submodule: its two example apps
still depend on `diver_flutter_annotation` by git URL rather than a relative path.
Now that both packages live here, they can use `path: ../../diver_flutter_annotation`
instead.

Every package is self-contained — its own toolchain, its own README, its own
`.gitignore` — and is developed and released independently. The root
[`.gitignore`](.gitignore) only covers OS, editor, and local-config noise.

Publishing to the public registries (pub.dev, npm, Maven Central) is driven by
git tags via [`.github/workflows/release.yml`](.github/workflows/release.yml).
See [RELEASING.md](RELEASING.md) for the tag conventions and the one-time
setup needed on each registry.
