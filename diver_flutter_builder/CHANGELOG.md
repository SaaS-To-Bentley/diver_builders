## 0.1.6

- Initial public release.
- `build_runner` builder aggregating `go_router` (`@TypedGoRoute`) and
  `auto_route` (`@AutoRouterConfig` / `@RoutePage`) routes into
  `diver/app_urls.json`.
- `upload_urls` executable that POSTs the generated JSON to the Diver API.
- Routes requiring a non-URL runtime object are recorded in
  `diver/app_urls_errors.json` instead of failing the build.
