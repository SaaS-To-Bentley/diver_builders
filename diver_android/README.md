# diver_android

A single artifact that aggregates [Jetpack Navigation](https://developer.android.com/guide/navigation) **type-safe routes** into `diver/app_urls.json` and uploads them to the Diver API — the Android / Kotlin counterpart of [`diver_flutter_builder`](../diver_flutter_builder) + [`diver_flutter_annotation`](../diver_flutter_annotation) and [`diver_expo_builder`](../diver_expo_builder).

Per the request, the **annotation and the builder live in the same library**:

- `@DiverRoute` — the annotation you put on route classes (source-retained; never in your APK).
- A **KSP processor** (the "builder") that scans those annotations at compile time and writes the JSON.
- An **upload** entrypoint that POSTs the JSON to the Diver API.

## How routes are derived

Jetpack Navigation's type-safe routes are `@Serializable` classes/objects, where required constructor args become path arguments and defaulted args become optional/query arguments. Diver maps that same shape onto its deeplink model. You opt a destination in with `@DiverRoute`:

| Kotlin route | Derived deeplink |
| --- | --- |
| `@DiverRoute data object Home` | host `home` |
| `@DiverRoute data class Profile(val userId: String)` | host `profile`, path `:user-id` |
| `@DiverRoute data class Settings(val tab: String? = null)` | host `settings`, query `tab` |
| `@DiverRoute data class ProductDetails(val id: String, val ref: String? = null)` | host `product-details`, path `:id`, query `ref` |

Rules:

- **host** = the class name, kebab-cased (`ProductDetails` → `product-details`).
- **path** = constructor params with no default and a non-null type, in order, as `:name` segments.
- **query** = params with a default value or a nullable type, kebab-cased.
- A param whose type is **not URL-serializable** (a custom class) makes the whole route **skipped** — the Android analog of Flutter's `$extra` skip. A warning is logged.

Routes are deduplicated by host+path and sorted by host then path.

### Query parameter types

| Kotlin type | Diver type |
| --- | --- |
| `String`, `Int`, `Long`, `Short`, `Byte`, `Float`, `Double`, `Char`, enum | `string` |
| `Boolean` | `boolean` |
| `List`, `MutableList`, `Array` | `list` |
| anything else | route skipped |

Numbers map to `string`, matching the other Diver builders.

## Installation

This artifact is used **twice** in a consuming app module — once for the annotation (compile-time only) and once as the KSP processor:

```kotlin
// build.gradle.kts (your app module)
plugins {
    id("com.google.devtools.ksp") version "2.1.0-1.0.29"
}

dependencies {
    compileOnly("io.github.saas-to-bentley:diver-android:0.1.0") // the @DiverRoute annotation
    ksp("io.github.saas-to-bentley:diver-android:0.1.0")         // the route-aggregating processor
}

ksp {
    // Where app_urls.json is written. Without this, the file is emitted into
    // KSP's generated resources instead.
    arg("diver.outputDir", "${projectDir}/diver")
}
```

`compileOnly` is enough for the annotation because its retention is `SOURCE` — nothing reads it at runtime, so neither the annotation nor this library ends up in your APK.

## Usage

Annotate the destinations you want registered as deeplinks:

```kotlin
import com.diver.android.DiverRoute
import kotlinx.serialization.Serializable

@DiverRoute(name = "Settings", description = "App settings screen")
@Serializable
data class Settings(val tab: String? = null)
```

Then build — KSP runs as part of compilation and writes `diver/app_urls.json`:

```sh
./gradlew :app:assembleDebug      # or any build that compiles the module
```

Routes without `@DiverRoute(name = ...)` fall back to the derived URL (`host/path`) as the name and an empty description.

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

A runnable end-to-end sample lives in [sample/](sample); run `./gradlew :sample:assemble` and inspect `sample/diver/app_urls.json`.

## Uploading routes

The library ships an upload entrypoint (`com.diver.android.upload.UrlUploaderKt`) that injects `org_id`/`app_id` and POSTs the file to `https://api.diver.mthy.dev/import`. Wire it into your app as a Gradle task:

```kotlin
val diverUploader by configurations.creating
dependencies { diverUploader("io.github.saas-to-bentley:diver-android:0.1.0") }

tasks.register<JavaExec>("diverUpload") {
    group = "diver"
    mainClass.set("com.diver.android.upload.UrlUploaderKt")
    classpath = diverUploader
    workingDir = projectDir
}
```

```sh
./gradlew :app:diverUpload
```

Prerequisites:

- `diver/app_urls.json` must exist — build with the KSP processor (and the `diver.outputDir` arg) first.
- `ORG_ID` and `APP_ID` must be set, either as environment variables or in a `diver/diver_config.properties` file in the working directory (`KEY=value`, one per line):

  ```properties
  ORG_ID=your-org-id
  APP_ID=your-app-id
  ```

## Development

```sh
./gradlew test                  # unit tests for route derivation + JSON encoding
./gradlew :sample:assemble      # run the processor against the sample module
```
