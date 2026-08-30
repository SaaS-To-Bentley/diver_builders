import fs from 'node:fs';
import path from 'node:path';

import { parseRouteFile, type QueryParam } from './parse.js';

export interface Route {
  name: string;
  description: string;
  host: string;
  path: string;
  query: QueryParam[];
}

const ROUTE_EXTENSIONS = new Set(['.tsx', '.ts', '.jsx', '.js']);
const PLATFORM_SUFFIXES = new Set(['ios', 'android', 'native', 'web']);

export function detectAppDir(cwd: string = process.cwd()): string {
  for (const candidate of ['app', path.join('src', 'app')]) {
    const dir = path.join(cwd, candidate);
    if (fs.existsSync(dir) && fs.statSync(dir).isDirectory()) return dir;
  }
  throw new Error(
    'No app/ or src/app/ directory found. Pass --app-dir to point at the Expo Router routes directory.',
  );
}

/// Scans an Expo Router `app/` directory and derives one route per route
/// file, mirroring diver_flutter_builder: the first URL segment becomes the
/// deeplink `host`, the remainder the `path`. Routes that resolve to the bare
/// root (`app/index.tsx`) have no host and are skipped.
export function scanRoutes(appDir: string): Route[] {
  const routes: Route[] = [];
  const seenPaths = new Set<string>();

  for (const file of walk(appDir)) {
    const segments = routeSegments(appDir, file);
    if (segments === null) continue;
    if (segments.length === 0) continue;

    const pathParams = new Set<string>();
    const urlSegments = segments.map((segment) => normalizeSegment(segment, pathParams));
    const fullPath = '/' + urlSegments.join('/');
    if (seenPaths.has(fullPath)) continue;
    seenPaths.add(fullPath);

    const host = urlSegments[0];
    const remainder = urlSegments.slice(1).join('/');
    const { meta, query } = parseRouteFile(file, fs.readFileSync(file, 'utf8'));
    const fallbackName = remainder === '' ? host : `${host}/${remainder}`;

    routes.push({
      name: meta?.name ? meta.name : fallbackName,
      description: meta?.description ?? '',
      host,
      path: remainder,
      query: query.filter((param) => !pathParams.has(param.name)),
    });
  }

  routes.sort((a, b) => {
    const byHost = a.host.localeCompare(b.host);
    return byHost !== 0 ? byHost : a.path.localeCompare(b.path);
  });
  return routes;
}

function* walk(dir: string): Generator<string> {
  const entries = fs
    .readdirSync(dir, { withFileTypes: true })
    .sort((a, b) => a.name.localeCompare(b.name));
  for (const entry of entries) {
    if (entry.name.startsWith('.') || entry.name.startsWith('_')) continue;
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      yield* walk(fullPath);
    } else if (entry.isFile()) {
      yield fullPath;
    }
  }
}

/// Maps a route file to its URL segments, or null when the file is not a
/// navigable route (layouts, `+` specials, API routes, non-route extensions).
/// `(group)` directory segments are stripped, `index` files collapse into
/// their directory, and platform suffixes (`home.ios.tsx`) are removed so
/// platform variants dedupe to a single route.
function routeSegments(appDir: string, filePath: string): string[] | null {
  const parts = path.relative(appDir, filePath).split(path.sep);
  const fileName = parts.pop()!;
  const extension = path.extname(fileName);
  if (!ROUTE_EXTENSIONS.has(extension)) return null;

  let base = fileName.slice(0, -extension.length);
  const dot = base.lastIndexOf('.');
  if (dot > 0 && PLATFORM_SUFFIXES.has(base.slice(dot + 1))) {
    base = base.slice(0, dot);
  }
  if (base === '' || base.startsWith('+') || base.endsWith('+api')) return null;

  const dirSegments = parts.filter(
    (part) => !(part.startsWith('(') && part.endsWith(')')),
  );
  return base === 'index' ? dirSegments : [...dirSegments, base];
}

function normalizeSegment(segment: string, pathParams: Set<string>): string {
  const catchAll = segment.match(/^\[\.\.\.(.+)\]$/);
  if (catchAll) {
    pathParams.add(catchAll[1]);
    return `:${catchAll[1]}`;
  }
  const dynamic = segment.match(/^\[(.+)\]$/);
  if (dynamic) {
    pathParams.add(dynamic[1]);
    return `:${dynamic[1]}`;
  }
  return segment;
}
