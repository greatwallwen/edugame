import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { mkdir, readFile, readdir, rename, rm, stat, writeFile } from 'node:fs/promises';
import { dirname, isAbsolute, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { syncTeachingAssets } from './sync_teaching_assets.mjs';

const toolDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(toolDir, '../../../..');
const publicGodotRoot = resolve(repoRoot, 'apps/player/public/assets/godot');

const GAME_CONFIGS = {
  'ch11-band-defense': {
    projectDir: resolve(repoRoot, 'packages/edugame/godot/games/ch11-band-defense'),
    outputDir: resolve(publicGodotRoot, 'ch11-band-defense'),
    entryFiles: [
      resolve(repoRoot, 'courses/stm32f10x/chapters/ch10_ch12.py'),
      resolve(repoRoot, 'packages/edugame/godot/games/ch11-band-defense/levels/ch11_band_defense_level.json'),
      resolve(repoRoot, 'apps/player/public/manifest.json'),
    ],
  },
  'ch12-solar-survivor': {
    projectDir: resolve(repoRoot, 'packages/edugame/godot/games/ch12-solar-survivor'),
    outputDir: resolve(publicGodotRoot, 'ch12-solar-survivor'),
    entryFiles: [
      resolve(repoRoot, 'courses/stm32f10x/chapters/worksheets.py'),
      resolve(repoRoot, 'packages/edugame/godot/games/ch12-solar-survivor/levels/ch12_solar_survivor_level.json'),
      resolve(repoRoot, 'apps/player/public/manifest.json'),
    ],
  },
};

function assertDirectChild(outputDir, allowedRoot) {
  const absoluteOutput = resolve(outputDir);
  const absoluteRoot = resolve(allowedRoot);
  const child = relative(absoluteRoot, absoluteOutput);
  if (!child || child.startsWith(`..${sep}`) || child === '..' || isAbsolute(child) || child.includes(sep)) {
    throw new Error(`Refusing to clean unsafe Godot export directory: ${absoluteOutput}`);
  }
}

export async function cleanWebExportDirectory(outputDir, allowedRoot) {
  assertDirectChild(outputDir, allowedRoot);
  await rm(resolve(outputDir), { recursive: true, force: true });
  await mkdir(resolve(outputDir), { recursive: true });
}

async function pathExists(path) {
	try {
		await stat(path);
		return true;
	} catch (error) {
		if (error?.code === 'ENOENT') return false;
		throw error;
	}
}

async function releaseAssetNames(outputDir) {
	const entries = await readdir(outputDir, { withFileTypes: true });
	return entries
		.filter((entry) => entry.isFile() && entry.name.startsWith('index.') && entry.name !== 'index.html')
		.map((entry) => entry.name)
		.sort();
}

async function releaseHash(outputDir, assetNames, length = 12) {
	const hash = createHash('sha256');
	for (const name of assetNames) {
		hash.update(name).update('\0').update(await readFile(resolve(outputDir, name))).update('\n');
	}
	return hash.digest('hex').slice(0, length);
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function addressedAssetName(name, hash) {
	return name.replace(/^index/, `index.${hash}`);
}

function versionExportHtml(html, hash, assetNames) {
	for (const required of ['index.js', 'index.wasm', 'index.pck']) {
		if (!assetNames.includes(required)) {
			throw new Error(`Godot export is missing required runtime asset: ${required}`);
		}
	}

	let next = html;
	for (const name of [...assetNames].sort((left, right) => right.length - left.length)) {
		next = next.split(name).join(addressedAssetName(name, hash));
	}

	const executablePattern = /("executable"\s*:\s*)"index"/;
	if (!executablePattern.test(next)) {
		throw new Error('Godot export HTML does not declare the index executable');
	}
	next = next.replace(executablePattern, `$1"index.${hash}"`);

	const packName = addressedAssetName('index.pck', hash);
	const mainPackPattern = /(['"]mainPack['"]\s*:\s*)['"]index(?:\.[a-f0-9]{12})?\.pck['"]/;
	if (mainPackPattern.test(next)) {
		next = next.replace(mainPackPattern, `$1'${packName}'`);
	} else {
		const startMarker = 'engine.startGame({';
		if (!next.includes(startMarker)) {
			throw new Error('Godot export HTML does not contain engine.startGame configuration');
		}
		next = next.replace(startMarker, `${startMarker}\n\t\t\t'mainPack': '${packName}',`);
	}
	return next;
}

async function rewriteEntryUrl(file, gameId, hash) {
  const text = await readFile(file, 'utf8');
  const baseUrl = `/assets/godot/${gameId}/index.html`;
  const pattern = new RegExp(`${escapeRegExp(baseUrl)}(?:\\?v=[a-f0-9]{12})?`, 'g');
  if (!pattern.test(text)) {
    throw new Error(`No ${baseUrl} entry URL found in ${file}`);
  }
  await writeFile(file, text.replace(pattern, `${baseUrl}?v=${hash}`), 'utf8');
}

export async function finalizeWebExport({ outputDir, gameId, entryFiles = [] }) {
	const htmlPath = resolve(outputDir, 'index.html');
	const assetNames = await releaseAssetNames(outputDir);
	const hash = await releaseHash(outputDir, assetNames);
	const html = await readFile(htmlPath, 'utf8');
	await writeFile(htmlPath, versionExportHtml(html, hash, assetNames), 'utf8');
	for (const name of assetNames) {
		await rename(resolve(outputDir, name), resolve(outputDir, addressedAssetName(name, hash)));
	}
	for (const file of entryFiles) await rewriteEntryUrl(file, gameId, hash);
	return { gameId, hash, outputDir: resolve(outputDir) };
}

async function validateFinalizedWebExport(outputDir) {
	const names = await readdir(outputDir);
	if (!names.includes('index.html')) throw new Error('Staged Godot export is missing index.html');
	const hashes = new Set();
	for (const extension of ['js', 'wasm', 'pck']) {
		const pattern = new RegExp(`^index\\.([a-f0-9]{12})\\.${extension}$`);
		const match = names.map((name) => name.match(pattern)).find(Boolean);
		if (!match) throw new Error(`Staged Godot export is missing content-addressed ${extension}`);
		hashes.add(match[1]);
	}
	if (hashes.size !== 1) throw new Error('Staged Godot export runtime assets use inconsistent hashes');
	return [...hashes][0];
}

export async function publishStagedWebExport({ outputDir, stagedOutputDir }) {
	await validateFinalizedWebExport(stagedOutputDir);
	const liveDir = resolve(outputDir);
	const stageDir = resolve(stagedOutputDir);
	if (liveDir === stageDir) throw new Error('Staged and live Godot export directories must differ');
	const backupDir = `${liveDir}.backup-${process.pid}-${Date.now()}`;
	const hadLiveExport = await pathExists(liveDir);
	await rm(backupDir, { recursive: true, force: true });
	let movedLiveExport = false;
	try {
		if (hadLiveExport) {
			await rename(liveDir, backupDir);
			movedLiveExport = true;
		}
		await rename(stageDir, liveDir);
	} catch (error) {
		if (movedLiveExport && !await pathExists(liveDir)) await rename(backupDir, liveDir);
		throw error;
	}
	await rm(backupDir, { recursive: true, force: true });
}

export function createGodotSpawnSpec(godotBin, args, {
	platform = process.platform,
	comspec = process.env.ComSpec || 'cmd.exe',
} = {}) {
	if (platform === 'win32' && /\.(?:cmd|bat)$/i.test(godotBin)) {
		return {
			command: comspec,
			args: ['/d', '/q', '/v:off', '/c', godotBin, ...args],
			options: { cwd: repoRoot, stdio: 'inherit', shell: false },
		};
	}
	return {
		command: godotBin,
		args,
		options: { cwd: repoRoot, stdio: 'inherit', shell: false },
	};
}

function runGodot(godotBin, projectDir, outputPath) {
	return new Promise((resolvePromise, reject) => {
		const spec = createGodotSpawnSpec(
			godotBin,
			['--headless', '--path', projectDir, '--export-release', 'Web', outputPath],
		);
		const child = spawn(spec.command, spec.args, spec.options);
    child.on('error', reject);
    child.on('exit', (code) => {
      if (code === 0) resolvePromise();
      else reject(new Error(`Godot Web export failed for ${projectDir} with exit code ${code}`));
    });
  });
}

export async function exportWebGames({ gameIds, godotBin = process.env.GODOT_BIN || 'godot' }) {
	await syncTeachingAssets({ repositoryRoot: repoRoot, mode: 'sync' });
	const results = [];
	for (const gameId of gameIds) {
		const config = GAME_CONFIGS[gameId];
		if (!config) throw new Error(`Unknown Godot game: ${gameId}`);
		const stagedOutputDir = resolve(publicGodotRoot, `.${gameId}.staging-${process.pid}-${Date.now()}`);
		try {
			await cleanWebExportDirectory(stagedOutputDir, publicGodotRoot);
			await runGodot(godotBin, config.projectDir, resolve(stagedOutputDir, 'index.html'));
			const staged = await finalizeWebExport({ outputDir: stagedOutputDir, gameId });
			await publishStagedWebExport({ outputDir: config.outputDir, stagedOutputDir });
			for (const file of config.entryFiles) await rewriteEntryUrl(file, gameId, staged.hash);
			results.push({ ...staged, outputDir: resolve(config.outputDir) });
		} finally {
			await rm(stagedOutputDir, { recursive: true, force: true });
		}
	}
  return results;
}

async function main() {
  const requested = process.argv.slice(2);
  const gameIds = requested.length === 0 || requested.includes('all')
    ? Object.keys(GAME_CONFIGS)
    : requested;
  const results = await exportWebGames({ gameIds });
  for (const result of results) {
    process.stdout.write(`Godot Web export: ${result.gameId} (${result.hash})\n`);
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    process.stderr.write(`${error instanceof Error ? error.stack : String(error)}\n`);
    process.exitCode = 1;
  });
}
