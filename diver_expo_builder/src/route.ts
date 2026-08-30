/**
 * Metadata attached to an Expo Router route to enrich the generated
 * `diver/app_urls.json` with a human-readable name and description.
 *
 * Import this from the `diver-expo-builder/route` subpath. It is the React
 * Native / Expo counterpart of the Dart `DiverRoute` annotation from
 * `diver_flutter_annotation`: because Expo Router files export a default
 * component rather than a route class, metadata is attached by exporting a
 * `diverRoute` constant instead of decorating a class.
 */
export interface DiverRoute {
  /** Human-readable route name shown in Diver. */
  name?: string;
  /** Human-readable description of the route. */
  description?: string;
}

/**
 * Type-checked helper for declaring Diver route metadata. Returns its argument
 * unchanged — its only job is autocomplete and validation at the call site,
 * the way `@DiverRoute(...)` does in Flutter.
 *
 * @example
 * ```tsx
 * import { defineDiverRoute } from 'diver-expo-builder/route';
 *
 * export const diverRoute = defineDiverRoute({
 *   name: 'Settings',
 *   description: 'App settings screen',
 * });
 *
 * export default function Settings() { ... }
 * ```
 */
export function defineDiverRoute(route: DiverRoute): DiverRoute {
  return route;
}
