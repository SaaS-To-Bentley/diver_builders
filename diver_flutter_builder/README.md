# diver_flutter_builder

A `build_runner` builder that aggregates [`go_router`](https://pub.dev/packages/go_router) and [`auto_route`](https://pub.dev/packages/auto_route) routes into `diver/app_urls.json` at build time. A consuming app is expected to use one framework or the other, but both are scanned unconditionally, so nothing needs to be configured to pick one.

## go_router

The builder scans every Dart library in the consuming package for classes annotated with `@TypedGoRoute(...)`, collects their path and query parameters, and writes them — sorted by host then path — to `diver/app_urls.json`. Optional `@DiverRoute(...)` annotations (from [`diver_flutter_annotation`](../diver_flutter_annotation)) contribute a human-readable `name` and `description` for each route.

Routes whose class declares a **required** `$extra` constructor parameter are kept out of `app_urls.json`: they need a runtime object that a URL cannot carry, so they are not deeplink-safe. Each excluded route is instead recorded in `diver/app_urls_errors.json` with a description of why it cannot be used for a deeplink, and reported as a build warning. The error file is only written when there is at least one excluded route, and `build_runner` removes it automatically once every route is deeplink-safe again.

A `$extra` parameter that is **optional** does not exclude its route — the route can still be opened from a URL, where `$extra` simply arrives as `null` or its default. A `$extra` is treated as optional when either:

- its type is **nullable** (e.g. `Item? $extra`), or
- it declares a **default value** (e.g. `this.$extra = const Item()`).

In all cases `$extra` is never emitted as a query parameter.

## auto_route

auto_route declares paths differently from go_router: they live centrally, on an `@AutoRouterConfig()` router's `routes` list, rather than on the page itself. The builder finds that router, reads each `AutoRoute(path: '/books/:id', page: BookDetailsRoute.page)` entry (`CustomRoute`, `AdaptiveRoute`, `CupertinoRoute` and `MaterialRoute` all count too — they carry the same `path`/`page` shape), and matches `page:` back to the `@RoutePage()` class it points to — first by an explicit `@RoutePage(name: ...)`, otherwise by comparing both names with common suffixes (`Route`/`Page`/`Screen`/`View`) stripped, which stands in for auto_route_generator's own configurable naming pattern without having to replicate it exactly.

**Only top-level routes are collected.** A parent `AutoRoute` with `children: [...]` still contributes its own path, but its children are not descended into — nested path composition isn't supported yet, and each skipped child is logged as a build message.

A page's parameters are read from its constructor the same way go_router's are, except that a widget's own `Key? key` is skipped (a page is a widget, so it nearly always has one, and it is never a URL value) and a parameter's role is decided by its `@PathParam('name')` / `@QueryParam('name')` annotation first (using the given name if one is supplied, the Dart parameter name otherwise), falling back to matching the parameter's own name against a `:segment` in the path when neither annotation is present — mirroring how auto_route itself resolves parameters at runtime.

Query parameters always come out `required: false` here: `auto_route_generator` rejects a query parameter that is neither nullable nor defaulted, so one the caller must supply cannot exist in a compiling app.

A **required** parameter that is neither annotated nor name-matched to a `:segment` excludes its route, the same way a required `$extra` does for go_router: auto_route has no single named escape hatch for a runtime-only payload, so an unclaimed required parameter is the signal that this route can't be reached from a URL. Making it optional (nullable, or given a default) or adding a `@PathParam`/`@QueryParam` annotation makes the route deeplink-safe again.

```dart
@AutoRouterConfig(replaceInRouteName: 'Screen|Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(path: '/home', page: HomeRoute.page),
    AutoRoute(path: '/books/:id', page: BookDetailsRoute.page),
  ];
}

@RoutePage()
class BookDetailsPage extends StatelessWidget {
  const BookDetailsPage({
    @PathParam('id') required this.bookId,
    @QueryParam('sort') this.sortBy,
  });

  final String bookId;
  final String? sortBy;

  @override
  Widget build(BuildContext context) => /* ... */;
}
```

produces:

```json
{ "name": "", "description": "", "host": "books", "path": ":id", "query": [{"name": "sort", "type": "string", "required": false}] }
```

## Installation

Add the builder as a dev dependency and the annotation as a regular dependency in the consuming app:

```yaml
dependencies:
  diver_flutter_annotation: ^0.1.1

dev_dependencies:
  diver_flutter_builder: ^0.1.6
  build_runner: ^2.4.0
```

For a complete, runnable setup see the two example apps — one per framework, since a real app uses one or the other:

- [`example_go_router/`](example_go_router) — go_router, exercising plain routes, query parameters, path parameters, `@DiverRoute` metadata, and both optional and required `$extra`.
- [`example_auto_route/`](example_auto_route) — auto_route, exercising `@PathParam`/`@QueryParam` and name-matched path parameters, explicit and suffix-matched `@RoutePage` names, `CustomRoute`, nested `children:`, and a required parameter that makes a route unreachable from a URL.

## Usage

Run the builder:

```sh
dart run build_runner build
```

This produces `diver/app_urls.json` containing every deeplink-safe route discovered in the package.

### Example

Given:

```dart
@TypedGoRoute<HomeRoute>(path: '/home')
class HomeRoute extends GoRouteData { ... }

@DiverRoute(name: 'Settings', description: 'App settings screen')
@TypedGoRoute<SettingsRoute>(path: '/settings')
class SettingsRoute extends GoRouteData {
  SettingsRoute({this.tab});
  final String? tab;
}

@TypedGoRoute<DetailRoute>(path: '/detail')
class DetailRoute extends GoRouteData {
  DetailRoute({required this.$extra});
  final Item $extra;
}
```

The generated `diver/app_urls.json` will be:

```json
{
  "routes": [
    {
      "name": "",
      "description": "",
      "host": "home",
      "path": "",
      "query": []
    },
    {
      "name": "Settings",
      "description": "App settings screen",
      "host": "settings",
      "path": "",
      "query": [
        {"name": "tab", "type": "string", "required": false}
      ]
    }
  ]
}
```

Each query parameter carries a `required` flag: it is `true` when the caller must supply the parameter — that is, when the corresponding constructor parameter has no default value and a non-nullable type — and `false` when it is optional (nullable or defaulted). Above, `tab` is `String? tab`, so `required` is `false`.

`DetailRoute` is excluded from `app_urls.json` because its `$extra` is required (non-nullable, no default). Routes without a `@DiverRoute` annotation get empty `name` and `description` defaults.

Because `DetailRoute` was excluded, the builder also writes `diver/app_urls_errors.json`:

```json
{
  "errors": [
    {
      "route": "DetailRoute",
      "path": "/detail",
      "extra": "Item",
      "reason": "Route requires a non-nullable $extra constructor parameter (Item) with no default value. $extra carries a runtime Dart object that cannot be encoded in a URL, and the route cannot be constructed without it, so it cannot be reached by a deeplink. Make $extra nullable or give it a default value to allow URL navigation without the payload."
    }
  ]
}
```

## Configuration

The builder is wired up via `build.yaml` and auto-applies to dependents. No additional configuration is required in the consuming package.

### Options

| Option | Default | Description |
| --- | --- | --- |
| `keep_generated` | `false` | When `true`, the generated `diver/app_urls.json` is left in the source tree after the build. When `false` (the default), the file is deleted on each build so it never gets committed. Enable this when you need to inspect the output or run `upload_urls` against it. |

Override per-target via `build.yaml` in the consuming package:

```yaml
targets:
  $default:
    builders:
      diver_flutter_builder|url_aggregator:
        options:
          keep_generated: true
```

## Uploading routes

The package ships an `upload_urls` executable that POSTs the generated `diver/app_urls.json` to the Diver API.

```sh
dart run diver_flutter_builder:upload_urls
```

Pass a custom path as the first argument to read from somewhere other than `diver/app_urls.json`:

```sh
dart run diver_flutter_builder:upload_urls path/to/diver/app_urls.json
```

Prerequisites:

- `diver/app_urls.json` must exist — run `dart run build_runner build` first.
- `ORG_ID`, `APP_ID` and `DIVER_API_KEY` must be set, either as environment variables or in a `diver/diver_config.properties` file in the working directory. The file uses a simple `KEY=value` format, one per line:

  ```properties
  ORG_ID=your-org-id
  APP_ID=your-app-id
  DIVER_API_KEY=dk_your-api-key
  ```

  `DIVER_API_KEY` authenticates the upload as an org-scoped machine caller — create one in the Diver dashboard under **Organization → Members → API keys**. The key is sent as `Authorization: Bearer <key>` on the import request; without it the API rejects the upload with 401.
