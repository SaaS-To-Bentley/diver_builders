import fs from 'node:fs';

const DEFAULT_FILE_PATH = 'diver/app_urls.json';
const CONFIG_PATH = 'diver/diver_config.properties';
const ORG_ID_VAR = 'ORG_ID';
const APP_ID_VAR = 'APP_ID';
const API_KEY_VAR = 'DIVER_API_KEY';
const BASE_URL = 'https://api.diver.mthy.dev';

export async function runUpload(filePath: string = DEFAULT_FILE_PATH): Promise<void> {
  const env: Record<string, string | undefined> = {
    ...loadProperties(),
    ...process.env,
  };

  if (!fs.existsSync(filePath)) {
    console.error(
      [
        `Error: ${filePath} not found.`,
        '',
        'Run `diver-expo-builder build` first to generate it.',
      ].join('\n'),
    );
    process.exit(1);
  }

  const orgId = env[ORG_ID_VAR];
  const appId = env[APP_ID_VAR];
  if (!orgId || !appId) {
    console.error(
      [
        `Error: ${ORG_ID_VAR} and ${APP_ID_VAR} must be set, either as`,
        `environment variables or in ${CONFIG_PATH} (KEY=value format).`,
      ].join('\n'),
    );
    process.exit(1);
  }

  const apiKey = env[API_KEY_VAR];
  if (!apiKey) {
    console.error(
      [
        `Error: ${API_KEY_VAR} is not set.`,
        '',
        'The import endpoint requires authentication. Create a key in the Diver',
        'dashboard under Organization -> Members -> API keys, then expose it to',
        `CI as ${API_KEY_VAR}.`,
      ].join('\n'),
    );
    process.exit(1);
  }

  const decoded = JSON.parse(fs.readFileSync(filePath, 'utf8')) as Record<string, unknown>;
  const body = { ...decoded, org_id: orgId, app_id: appId };
  const importUrl = `${BASE_URL}/organizations/${orgId}/apps/${appId}/import`;

  console.log(`Uploading ${filePath} -> ${importUrl}`);
  const response = await fetch(importUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
  });

  if (response.ok) {
    console.log(`Upload succeeded (${response.status}).`);
  } else {
    console.error(`Upload failed (${response.status}): ${await response.text()}`);
    process.exit(1);
  }
}

function loadProperties(): Record<string, string> {
  if (!fs.existsSync(CONFIG_PATH)) return {};

  const result: Record<string, string> = {};
  for (let line of fs.readFileSync(CONFIG_PATH, 'utf8').split('\n')) {
    line = line.trim();
    if (line === '' || line.startsWith('#')) continue;

    const eq = line.indexOf('=');
    if (eq < 0) continue;

    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();
    if (
      value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'")))
    ) {
      value = value.slice(1, -1);
    }
    result[key] = value;
  }
  return result;
}
