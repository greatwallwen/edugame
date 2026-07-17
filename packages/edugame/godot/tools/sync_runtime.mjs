import { createHash } from 'node:crypto';
import { cp, mkdir, readFile, readdir, rm, stat, writeFile } from 'node:fs/promises';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const RUNTIME_VERSION = 1;

function posixPath(path) {
  return path.split(sep).join('/');
}

async function exists(path) {
  try {
    await stat(path);
    return true;
  } catch (error) {
    if (error?.code === 'ENOENT') return false;
    throw error;
  }
}

async function listFiles(root, current = root) {
  const entries = await readdir(current, { withFileTypes: true });
  const files = [];
  for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name))) {
    const absolute = join(current, entry.name);
    if (entry.isDirectory()) files.push(...await listFiles(root, absolute));
    else if (entry.isFile()) files.push(posixPath(relative(root, absolute)));
  }
  return files;
}

async function describeTree(root) {
  const files = [];
  for (const path of await listFiles(root)) {
    const contents = await readFile(join(root, path));
    const sha256 = createHash('sha256').update(contents).digest('hex');
    files.push({ path, sha256 });
  }
  const sourceHash = createHash('sha256');
  for (const file of files) {
    sourceHash.update(file.path).update('\0').update(file.sha256).update('\n');
  }
  return { version: RUNTIME_VERSION, sourceHash: sourceHash.digest('hex'), files };
}

function stableLock(manifest) {
  return `${JSON.stringify(manifest, null, 2)}\n`;
}

async function discoverGames(gamesDir) {
  const entries = await readdir(gamesDir, { withFileTypes: true });
  const games = [];
  for (const entry of entries) {
    if (entry.isDirectory() && await exists(join(gamesDir, entry.name, 'project.godot'))) games.push(entry.name);
  }
  return games.sort();
}

function manifestDifferences(expected, actual, game) {
  const differences = [];
  const actualByPath = new Map(actual.files.map((file) => [file.path, file.sha256]));
  const expectedPaths = new Set(expected.files.map((file) => file.path));
  for (const file of expected.files) {
    if (!actualByPath.has(file.path)) differences.push(`${game}: missing ${file.path}`);
    else if (actualByPath.get(file.path) !== file.sha256) differences.push(`${game}: modified ${file.path}`);
  }
  for (const file of actual.files) {
    if (file.path.endsWith('.gd.uid') && expectedPaths.has(file.path.slice(0, -'.uid'.length))) continue;
    if (!expectedPaths.has(file.path)) differences.push(`${game}: unexpected ${file.path}`);
  }
  return differences;
}

export async function syncRuntime({ sourceDir, gamesDir, mode = 'sync', extraTargets = [] }) {
  if (!['sync', 'check'].includes(mode)) throw new Error(`Unsupported mode: ${mode}`);
  const canonical = await describeTree(sourceDir);
  const targets = (await discoverGames(gamesDir))
    .map((name) => ({ name, directory: join(gamesDir, name) }))
    .concat(extraTargets)
    .sort((a, b) => a.name.localeCompare(b.name));
  const games = targets.map((target) => target.name);
  const differences = [];

  for (const target of targets) {
    const game = target.name;
    const gameDir = target.directory;
    const destination = join(gameDir, 'addons', 'dgbook_runtime');
    const lockPath = join(gameDir, 'dgbook-runtime.lock.json');
    if (mode === 'sync') {
      await rm(destination, { recursive: true, force: true });
      await mkdir(dirname(destination), { recursive: true });
      await cp(sourceDir, destination, { recursive: true });
      await writeFile(lockPath, stableLock(canonical), 'utf8');
      continue;
    }

    if (!await exists(destination)) {
      differences.push(`${game}: missing addons/dgbook_runtime`);
      continue;
    }
    differences.push(...manifestDifferences(canonical, await describeTree(destination), game));
    if (!await exists(lockPath)) {
      differences.push(`${game}: missing dgbook-runtime.lock.json`);
    } else if (await readFile(lockPath, 'utf8') !== stableLock(canonical)) {
      differences.push(`${game}: stale dgbook-runtime.lock.json`);
    }
  }

  if (differences.length > 0) throw new Error(`Godot runtime check failed:\n${differences.join('\n')}`);
  return { games, manifest: canonical };
}

async function main() {
  const mode = process.argv[2];
  if (!['sync', 'check'].includes(mode)) throw new Error('Usage: sync_runtime.mjs <sync|check>');
  const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..');
  const result = await syncRuntime({
    sourceDir: join(repositoryRoot, 'packages', 'edugame', 'godot', 'shared', 'dgbook_runtime'),
    gamesDir: join(repositoryRoot, 'packages', 'edugame', 'godot', 'games'),
    mode,
    extraTargets: [{
      name: 'template',
      directory: join(repositoryRoot, 'packages', 'edugame', 'godot', 'template'),
    }],
  });
  process.stdout.write(`Godot runtime ${mode}: ${result.games.join(', ')} (${result.manifest.files.length} files)\n`);
}

if (resolve(process.argv[1] ?? '') === resolve(fileURLToPath(import.meta.url))) {
  main().catch((error) => {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  });
}
