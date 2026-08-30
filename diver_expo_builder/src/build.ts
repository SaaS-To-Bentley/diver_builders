import fs from 'node:fs';
import path from 'node:path';

import { detectAppDir, scanRoutes } from './scan.js';

export const DEFAULT_OUTPUT = path.join('diver', 'app_urls.json');

export interface BuildOptions {
  appDir?: string;
  out?: string;
}

export function runBuild(options: BuildOptions = {}): void {
  const appDir = path.resolve(options.appDir ?? detectAppDir());
  if (!fs.existsSync(appDir) || !fs.statSync(appDir).isDirectory()) {
    throw new Error(`Routes directory not found: ${appDir}`);
  }
  const out = options.out ?? DEFAULT_OUTPUT;

  const routes = scanRoutes(appDir);
  const body = JSON.stringify({ routes }, null, 2);

  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, `${body}\n`);
  console.log(`Wrote ${routes.length} route(s) from ${appDir} to ${out}.`);
}
