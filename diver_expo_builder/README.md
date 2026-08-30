# diver_expo_builder

A CLI that aggregates [Expo Router](https://docs.expo.dev/router/introduction/) routes into `diver/app_urls.json` — the Expo/React Native counterpart of [`diver_flutter_builder`](../diver_flutter_builder).

Expo Router is file-based, so instead of scanning for `@TypedGoRoute` annotations the builder walks the `app/` directory and derives one route per route file. As in the Flutter builder, the first URL segment becomes the deeplink `host` and the remainder the `path`, and the output is sorted by host then path.

| File convention | Handling |
| --- | --- |
| `(group)/` | Stripped from the URL |
| `[param]` | Becomes `:param` path segment |
| `[...param]` | Catch-all, becomes `:param` |
| `index.tsx` | Collapses into its directory path |
| `_layout.tsx`, `_`-prefixed files/dirs | Skipped |
| `+not-found.tsx`, `+html.tsx`, … | Skipped |
| `*+api.ts` (API routes) | Skipped |
| `home.ios.tsx` / `home.web.tsx` | Platform variants dedupe to one route |

The root route (`app/index.tsx`) resolves to a bare `/` with no host, so it is skipped — same as the Flutter builder skipping empty-host paths.

A runnable Expo app exercising all of these conventions lives in [example/](example/).

## Installation

Add the package as a dev dependency in the consuming Expo app:

```sh
npm install --save-dev ../diver_expo_builder
```

A dev dependency is enough even though route files import the `defineDiverRoute` helper from it (see [Route metadata](#route-metadata)): Metro bundles that helper into your app at build time, so it doesn't need to be a runtime dependency.

## Usage

```sh
npx diver-expo-builder build
```

This produces `diver/app_urls.json` containing every route discovered in `app/` (or `src/app/`). Options:

| Option | Default | Description |
| --- | --- | --- |
| `--app-dir <dir>` | auto-detect `app/` or `src/app/` | The Expo Router routes directory. |
| `--out <file>` | `diver/app_urls.json` | Output file path. |

Unlike the Flutter builder there is no `keep_generated` option — the file is only written when you run the command. Add `diver/` to your `.gitignore` if you don't want to commit it.

## Route metadata

Where the Flutter builder reads an optional `@DiverRoute(...)` annotation, a route file contributes a human-readable `name` and `description` by exporting a `diverRoute` constant. Use the `defineDiverRoute` helper from this package's `diver-expo-builder/route` subpath for type-checked metadata — the React Native analog of the Flutter annotation:

```tsx
import { defineDiverRoute } from 'diver-expo-builder/route';

export const diverRoute = defineDiverRoute({
  name: 'Settings',
  description: 'App settings screen',
});

export default function Settings() { ... }
```

The helper is optional — a plain object works too and needs no dependency, but won't catch typos:

```tsx
export const diverRoute = {
  name: 'Settings',
  description: 'App settings screen',
};
```

Routes without it fall back to the URL (`host/path`) as the name and an empty description.

## Query parameters

Expo Router has no static route config for query params, so the builder reads them from the type argument of `useLocalSearchParams<{ ... }>()` (or `useGlobalSearchParams`) in the route file — the closest analog to reading Dart constructor parameters:

```tsx
export default function Settings() {
  const { tab, verbose, filters } = useLocalSearchParams<{
    tab?: string;
    verbose?: 'true' | 'false';
    filters?: string[];
  }>();
  ...
}
```

Types map to `string`, `boolean`, or `list`: arrays become `list`, and a `'true' | 'false'` literal union (or the `boolean` keyword) becomes `boolean` — expo-router constrains param values to `string | string[]`, so the literal union is the form that typechecks. Everything else falls back to `string`. Params that match a dynamic path segment (e.g. `id` in `app/user/[id].tsx`) are excluded from the query list. Untyped `useLocalSearchParams()` calls contribute no query params.

### Example

Given:

```
app/
  _layout.tsx
  index.tsx
  (tabs)/
    home.tsx
    settings.tsx        # exports diverRoute + typed useLocalSearchParams
  user/[id]/index.tsx
  +not-found.tsx
```

The generated `diver/app_urls.json` will be:

```json
{
  "routes": [
    {
      "name": "home",
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
        {"name": "tab", "type": "string"}
      ]
    },
    {
      "name": "user/:id",
      "description": "",
      "host": "user",
      "path": ":id",
      "query": []
    }
  ]
}
```

## Uploading routes

The `upload` command POSTs the generated `diver/app_urls.json` to the Diver API:

```sh
npx diver-expo-builder upload
```

Pass a custom path as the first argument to read from somewhere other than `diver/app_urls.json`:

```sh
npx diver-expo-builder upload path/to/app_urls.json
```

Prerequisites:

- `diver/app_urls.json` must exist — run `npx diver-expo-builder build` first.
- `ORG_ID` and `APP_ID` must be set, either as environment variables or in a `diver/diver_config.properties` file in the working directory. The file uses a simple `KEY=value` format, one per line:

  ```properties
  ORG_ID=your-org-id
  APP_ID=your-app-id
  ```

## Development

```sh
npm install
npm run build   # compiles src/ to dist/
```
