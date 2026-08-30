# diver_flutter_builder example — auto_route

A minimal Flutter app that wires up [`auto_route`](https://pub.dev/packages/auto_route)
routes and runs [`diver_flutter_builder`](../) over them. It is the auto_route
counterpart to [`example_go_router/`](../example_go_router), which does the same thing with
`go_router`; a real app uses one framework or the other, so the two examples are
separate packages.

Where go_router declares a path on the route class itself, auto_route keeps
every path centrally on the router. So this example is split in two:

- [`lib/app_router.dart`](lib/app_router.dart) — the `@AutoRouterConfig()` router
  and its `routes` list, i.e. every path.
- [`lib/pages.dart`](lib/pages.dart) — the `@RoutePage()` widgets, i.e. how each
  route's parameters are filled.

The comment on each entry in both files explains what it contributes to the
output.

## Run the builder

```sh
flutter pub get
dart run build_runner build
```

This generates:

- `lib/app_router.gr.dart` — the auto_route wiring (from `auto_route_generator`).
- `diver/app_urls.json` — the deeplink-safe routes (from `diver_flutter_builder`).
- `diver/app_urls_errors.json` — routes that are **not** deeplink-safe.

> The example's [`build.yaml`](build.yaml) sets `keep_generated: true` so
> `diver/app_urls.json` is left on disk for inspection. Without it the builder
> deletes that file at the end of every build.

The package carries no platform folders; run `flutter create .` first if you
want to launch the app itself with `flutter run`.

## What the routes demonstrate

| Route | Declaration | Result |
| --- | --- | --- |
| `DashboardPage` | `AutoRoute(path: '/dashboard', page: DashboardRoute.page)` | Plain entry. Page matched by stripping the `Page`/`Route` suffixes off both names |
| `SearchPage` | `/search` + `@DiverRoute` | `name`/`description` from the annotation; `@QueryParam('q')` renames a param, an unannotated one is kebab-cased |
| `BookDetailsPage` | `/books/:id`, `@PathParam('id')` | Path param claimed by annotation (kept out of `query`) + a `bool` query param |
| `LibraryPage` | `/library/:shelf`, `required String shelf` | Path param claimed by **name match** against `:shelf`, with no annotation |
| `ProfilePage` | `CustomRoute(path: '/profile', page: ProfileTab.page)` | `CustomRoute` collected like `AutoRoute`; page matched by its explicit `@RoutePage(name: 'ProfileTab')` |
| `SettingsPage` | `/settings` with `children: [...]` | Parent path collected; the nested `/settings/privacy` is **not** composed (logged as a build message) |
| `CheckoutPage` | `/checkout`, `required Cart cart` | Required parameter nothing claims as a URL value → not deeplink-safe → `app_urls_errors.json` |
| — | `RedirectRoute(path: '/', redirectTo: '/dashboard')` | Not an `AutoRoute` and maps to no page, so it contributes nothing |

Two things fall out of auto_route's own rules rather than the builder's:

- **Query parameters are always `required: false`.** `auto_route_generator`
  rejects a query parameter that is neither nullable nor defaulted ("QueryParams
  must be nullable or have default value"), so one the caller *must* supply
  cannot exist in a compiling app.
- **`super.key` is not a query parameter.** Every `@RoutePage()` page is a
  widget, so its constructor almost always carries a `Key? key`; the builder
  leaves it out.

## Generated `diver/app_urls.json`

```json
{
  "routes": [
    {
      "name": "books/:id",
      "description": "",
      "host": "books",
      "path": ":id",
      "query": [
        { "name": "preview", "type": "boolean", "required": false }
      ]
    },
    { "name": "dashboard", "description": "", "host": "dashboard", "path": "", "query": [] },
    { "name": "library/:shelf", "description": "", "host": "library", "path": ":shelf", "query": [] },
    { "name": "profile", "description": "", "host": "profile", "path": "", "query": [] },
    {
      "name": "Product search",
      "description": "Full-text product search with optional paging and filtering.",
      "host": "search",
      "path": "",
      "query": [
        { "name": "q", "type": "string", "required": false },
        { "name": "page", "type": "string", "required": false },
        { "name": "category", "type": "string", "required": false },
        { "name": "sort-order", "type": "string", "required": false }
      ]
    },
    { "name": "settings", "description": "", "host": "settings", "path": "", "query": [] }
  ]
}
```

## Generated `diver/app_urls_errors.json`

```json
{
  "errors": [
    {
      "route": "CheckoutPage",
      "path": "/checkout",
      "extra": "Cart",
      "reason": "Required constructor parameter `cart` (Cart) is not matched by name to a `:segment` in the route's path, and carries no explicit @PathParam or @QueryParam annotation claiming it as a URL value. auto_route allows passing a runtime object like this when navigating in-app, but a URL cannot carry it, so the route cannot be reached by a deeplink. Give it a default value, make it nullable, or add an @PathParam/@QueryParam annotation to allow URL navigation."
    }
  ]
}
```
