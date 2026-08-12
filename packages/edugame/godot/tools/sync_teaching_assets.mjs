import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const COURSE_PUBLIC_ROOT = 'apps/player/public/assets/courses/stm32-course';

const GAME_ENTRY_FILES = {
  'ch09-env-spire': [
    'courses/stm32f10x/chapters/ch08_ch09.py',
    'packages/edugame/godot/games/ch09-env-spire/levels/ch09_env_spire_level.json',
    'apps/player/public/manifest.json',
  ],
  'ch11-band-defense': [
    'courses/stm32f10x/chapters/ch10_ch12.py',
    'packages/edugame/godot/games/ch11-band-defense/levels/ch11_band_defense_level.json',
    'apps/player/public/manifest.json',
  ],
  'ch12-solar-survivor': [
    'courses/stm32f10x/chapters/worksheets.py',
    'packages/edugame/godot/games/ch12-solar-survivor/levels/ch12_solar_survivor_level.json',
    'apps/player/public/manifest.json',
  ],
};

const ASSETS = [
  {
    id: 'ch09-questions',
    gameId: 'ch09-env-spire',
    kind: 'array',
    source: 'courses/stm32f10x/knowledge/ch09-env-spire.questions.json',
    publicTarget: `${COURSE_PUBLIC_ROOT}/knowledge/ch09-env-spire.questions.json`,
    localTarget: 'packages/edugame/godot/games/ch09-env-spire/data/questions.local.json',
    url: '/assets/courses/stm32-course/knowledge/ch09-env-spire.questions.json',
  },
  {
    id: 'ch11-questions',
    gameId: 'ch11-band-defense',
    kind: 'array',
    source: 'courses/stm32f10x/knowledge/ch11-band-defense.questions.json',
    publicTarget: `${COURSE_PUBLIC_ROOT}/knowledge/ch11-band-defense.questions.json`,
    localTarget: 'packages/edugame/godot/games/ch11-band-defense/data/questions.local.json',
    url: '/assets/courses/stm32-course/knowledge/ch11-band-defense.questions.json',
  },
  {
    id: 'ch12-questions',
    gameId: 'ch12-solar-survivor',
    kind: 'array',
    source: 'courses/stm32f10x/knowledge/ch12-solar-survivor.questions.json',
    publicTarget: `${COURSE_PUBLIC_ROOT}/knowledge/ch12-solar-survivor.questions.json`,
    localTarget: 'packages/edugame/godot/games/ch12-solar-survivor/data/questions.local.json',
    url: '/assets/courses/stm32-course/knowledge/ch12-solar-survivor.questions.json',
  },
  {
    id: 'ch12-upgrades',
    gameId: 'ch12-solar-survivor',
    kind: 'array',
    source: 'courses/stm32f10x/knowledge/ch12-solar-survivor.upgrades.json',
    publicTarget: `${COURSE_PUBLIC_ROOT}/knowledge/ch12-solar-survivor.upgrades.json`,
    localTarget: 'packages/edugame/godot/games/ch12-solar-survivor/data/upgrades.local.json',
    url: '/assets/courses/stm32-course/knowledge/ch12-solar-survivor.upgrades.json',
  },
  {
    id: 'ch12-binding',
    gameId: 'ch12-solar-survivor',
    kind: 'object',
    source: 'courses/stm32f10x/game-bindings/ch12-solar-survivor.binding.json',
    publicTarget: `${COURSE_PUBLIC_ROOT}/game-bindings/ch12-solar-survivor.binding.json`,
    url: '/assets/courses/stm32-course/game-bindings/ch12-solar-survivor.binding.json',
  },
];

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function validateJson(asset, bytes) {
  let parsed;
  try {
    parsed = JSON.parse(bytes.toString('utf8'));
  } catch (error) {
    throw new Error(`Invalid canonical teaching JSON ${asset.source}: ${error.message}`);
  }
  if (asset.kind === 'array' && (!Array.isArray(parsed) || parsed.length === 0)) {
    throw new Error(`Canonical teaching asset must be a non-empty array: ${asset.source}`);
  }
  if (asset.kind === 'object' && (!parsed || typeof parsed !== 'object' || Array.isArray(parsed))) {
    throw new Error(`Canonical teaching asset must be an object: ${asset.source}`);
  }
}

async function writeMirror(path, bytes) {
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, bytes);
}

async function assertMirror(path, expected, differences) {
  try {
    const actual = await readFile(path);
    if (!actual.equals(expected)) differences.push(`stale mirror: ${path}`);
  } catch (error) {
    if (error?.code === 'ENOENT') differences.push(`missing mirror: ${path}`);
    else throw error;
  }
}

async function rewriteVersionedUrl(path, baseUrl, hash, mode, differences) {
  const text = await readFile(path, 'utf8');
  const pattern = new RegExp(`${escapeRegExp(baseUrl)}(?:\\?v=[a-f0-9]{12})?`, 'g');
  if (!pattern.test(text)) {
    differences.push(`missing teaching URL ${baseUrl}: ${path}`);
    return;
  }
  const expected = `${baseUrl}?v=${hash}`;
  if (mode === 'sync') {
    await writeFile(path, text.replace(pattern, expected), 'utf8');
  } else if (!text.includes(expected)) {
    differences.push(`stale teaching URL ${baseUrl}: ${path}`);
  }
}

function lockContents(gameId, assets) {
  return `${JSON.stringify({
    version: 1,
    gameId,
    authority: 'courses/stm32f10x',
    generated: assets.map((asset) => ({
      id: asset.id,
      source: asset.source,
      publicTarget: asset.publicTarget,
      localTarget: asset.localTarget ?? null,
      sha256: asset.sha256,
    })),
  }, null, 2)}\n`;
}

export async function syncTeachingAssets({ repositoryRoot, mode = 'sync' }) {
  if (!['sync', 'check'].includes(mode)) throw new Error(`Unsupported teaching asset mode: ${mode}`);
  const root = resolve(repositoryRoot);
  const differences = [];
  const described = [];

  for (const asset of ASSETS) {
    const sourcePath = join(root, asset.source);
    const bytes = await readFile(sourcePath);
    validateJson(asset, bytes);
    const fullHash = sha256(bytes);
    const description = { ...asset, sha256: fullHash, hash: fullHash.slice(0, 12) };
    described.push(description);

    const targets = [asset.publicTarget, asset.localTarget].filter(Boolean).map((path) => join(root, path));
    for (const target of targets) {
      if (mode === 'sync') await writeMirror(target, bytes);
      else await assertMirror(target, bytes, differences);
    }
    for (const entryFile of GAME_ENTRY_FILES[asset.gameId]) {
      await rewriteVersionedUrl(join(root, entryFile), asset.url, description.hash, mode, differences);
    }
  }

  for (const gameId of Object.keys(GAME_ENTRY_FILES)) {
    const gameAssets = described.filter((asset) => asset.gameId === gameId);
    const lockPath = join(root, 'packages/edugame/godot/games', gameId, 'teaching-assets.lock.json');
    const expected = lockContents(gameId, gameAssets);
    if (mode === 'sync') await writeFile(lockPath, expected, 'utf8');
    else {
      try {
        if (await readFile(lockPath, 'utf8') !== expected) differences.push(`stale teaching lock: ${lockPath}`);
      } catch (error) {
        if (error?.code === 'ENOENT') differences.push(`missing teaching lock: ${lockPath}`);
        else throw error;
      }
    }
  }

  if (differences.length > 0) throw new Error(`Teaching asset check failed:\n${differences.join('\n')}`);
  return { assets: described.map(({ id, gameId, hash, source }) => ({ id, gameId, hash, source })) };
}

async function main() {
  const mode = process.argv[2];
  if (!['sync', 'check'].includes(mode)) throw new Error('Usage: sync_teaching_assets.mjs <sync|check>');
  const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..');
  const result = await syncTeachingAssets({ repositoryRoot, mode });
  process.stdout.write(`Teaching assets ${mode}: ${result.assets.length} assets\n`);
}

if (resolve(process.argv[1] ?? '') === resolve(fileURLToPath(import.meta.url))) {
  main().catch((error) => {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  });
}
