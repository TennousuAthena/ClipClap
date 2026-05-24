import { readFileSync, writeFileSync } from 'node:fs';

const profilePath = 'build-profile.json5';
let content = readFileSync(profilePath, 'utf8');

content = content.replace(/\n\s*"signingConfigs"\s*:\s*\[[\s\S]*?\n\s*\],\n/, '\n');
content = content.replace(/\n\s*"signingConfig"\s*:\s*"[^"]+",\n/g, '\n');

writeFileSync(profilePath, content);
