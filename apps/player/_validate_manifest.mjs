// 在 monorepo 根目录跑：node --experimental-vm-modules .codegraph/_validate.mjs <file>
// 通过 pnpm workspace symlink 解析 @dgbook/types
import { safeParseCourseManifest } from '@dgbook/types';
import { readFileSync } from 'node:fs';

const path = process.argv[2];
const raw = JSON.parse(readFileSync(path, 'utf-8'));
const result = safeParseCourseManifest(raw);

if (result.success) {
  console.log(`OK ${path}`);
  process.exit(0);
}

console.log(`FAIL ${path}`);
console.log(`  total issues: ${result.error.issues.length}`);
for (const issue of result.error.issues.slice(0, 30)) {
  const path = Array.isArray(issue.path) ? issue.path.join('.') : String(issue.path);
  console.log(`  - path=${path} code=${issue.code} message=${issue.message}`);
}
process.exit(1);
