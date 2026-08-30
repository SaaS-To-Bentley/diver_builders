#!/usr/bin/env node
import { runBuild, type BuildOptions } from './build.js';
import { runUpload } from './upload.js';

const USAGE = `Usage: diver-expo-builder <command> [options]

Commands:
  build               Scan the Expo Router app directory and write diver/app_urls.json
    --app-dir <dir>   Routes directory (default: auto-detect app/ or src/app/)
    --out <file>      Output file (default: diver/app_urls.json)
  upload [file]       POST a generated app_urls.json to the Diver API
                      (default file: diver/app_urls.json)
`;

async function main(): Promise<void> {
  const [command, ...rest] = process.argv.slice(2);

  switch (command) {
    case 'build': {
      const options: BuildOptions = {};
      for (let i = 0; i < rest.length; i++) {
        const arg = rest[i];
        if (arg === '--app-dir' && rest[i + 1] !== undefined) {
          options.appDir = rest[++i];
        } else if (arg === '--out' && rest[i + 1] !== undefined) {
          options.out = rest[++i];
        } else {
          console.error(`Unknown or incomplete option: ${arg}\n\n${USAGE}`);
          process.exit(1);
        }
      }
      runBuild(options);
      break;
    }
    case 'upload':
      await runUpload(rest[0]);
      break;
    case undefined:
    case '--help':
    case '-h':
      console.log(USAGE);
      process.exit(command === undefined ? 1 : 0);
      break;
    default:
      console.error(`Unknown command: ${command}\n\n${USAGE}`);
      process.exit(1);
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
