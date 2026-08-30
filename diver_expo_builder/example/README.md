# diver-expo-builder example

A minimal Expo Router app demonstrating [`diver-expo-builder`](..). The routes in [src/app](src/app) cover every convention the builder handles:

| Route file | Demonstrates | Result |
| --- | --- | --- |
| `index.tsx` | Root route has no host | Skipped |
| `_layout.tsx`, `+not-found.tsx` | Layouts and `+` specials | Skipped |
| `profile.tsx` | `defineDiverRoute({ name, description })` metadata helper | `diverexample://profile` |
| `settings.tsx` | `defineDiverRoute` + typed `useLocalSearchParams` → query params (`string`, `'true' \| 'false'` → boolean, `string[]` → list) | `diverexample://settings?tab=…` |
| `products/index.tsx` | Plain-object `diverRoute` (no helper) + `index` collapses into its directory | `diverexample://products` |
| `products/[id].tsx` | Dynamic segment; `id` excluded from query, `ref` kept | `diverexample://products/:id?ref=…` |
| `docs/[...slug].tsx` | Catch-all segment | `diverexample://docs/:slug` |
| `(info)/about.tsx` | Group segment stripped from the URL | `diverexample://about` |

Route metadata uses the `defineDiverRoute` helper imported from the `diver-expo-builder/route` subpath, except `products/index.tsx` which uses a plain object to show both forms are supported.

## Setup

```sh
npm install
```

The builder is wired up as a `file:..` dev dependency with two scripts:

```sh
npm run diver:build    # writes diver/app_urls.json from src/app
npm run diver:upload   # POSTs it to the Diver API (needs ORG_ID / APP_ID)
```

To upload, set `ORG_ID` and `APP_ID` as environment variables or create `diver/diver_config.properties`:

```properties
ORG_ID=your-org-id
APP_ID=your-app-id
```

## Running the app

```sh
npm start        # Expo dev server
npm run web      # in the browser
```

The deeplink scheme is `diverexample` (see [app.json](app.json)), so a generated route like `settings` is reachable at `diverexample://settings?tab=general&verbose=true`.
