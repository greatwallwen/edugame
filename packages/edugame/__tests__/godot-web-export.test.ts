import { access, mkdtemp, mkdir, readFile, readdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

describe('Godot Web export release tooling', () => {
  it('lets the repository command select one game and uses the Windows wrapper by default', async () => {
    const repositoryPackage = JSON.parse(await readFile(
      join(process.cwd(), '..', '..', 'package.json'),
      'utf8',
    ));
    const { defaultGodotBinary } = await import('../godot/tools/export_web.mjs');

    expect(repositoryPackage.scripts['godot:web:export']).toBe(
      'node packages/edugame/godot/tools/export_web.mjs',
    );
    expect(defaultGodotBinary({ platform: 'win32' })).toBe('godot.cmd');
    expect(defaultGodotBinary({ platform: 'linux' })).toBe('godot');
  });

  it('registers every production Godot game in the release pipeline', async () => {
    const { configuredGodotGames } = await import('../godot/tools/export_web.mjs');

    expect(configuredGodotGames()).toEqual([
      {
        gameId: 'ch09-env-spire',
        entryFiles: [
          'courses/stm32f10x/chapters/ch08_ch09.py',
          'packages/edugame/godot/games/ch09-env-spire/levels/ch09_env_spire_level.json',
          'apps/player/public/manifest.json',
        ],
      },
      {
        gameId: 'ch11-band-defense',
        entryFiles: [
          'courses/stm32f10x/chapters/ch10_ch12.py',
          'packages/edugame/godot/games/ch11-band-defense/levels/ch11_band_defense_level.json',
          'apps/player/public/manifest.json',
        ],
      },
      {
        gameId: 'ch12-solar-survivor',
        entryFiles: [
          'courses/stm32f10x/chapters/worksheets.py',
          'packages/edugame/godot/games/ch12-solar-survivor/levels/ch12_solar_survivor_level.json',
          'apps/player/public/manifest.json',
        ],
      },
    ]);
  });

  it('publishes the Ch09 game entry through the course and player manifest', async () => {
    const repoRoot = join(process.cwd(), '..', '..');
    const entryUrlPattern = /^\/assets\/godot\/ch09-env-spire\/index\.html(?:\?v=[a-f0-9]{12})?$/;
    const courseSource = await readFile(
      join(repoRoot, 'courses', 'stm32f10x', 'chapters', 'ch08_ch09.py'),
      'utf8',
    );
    const levelManifest = JSON.parse(await readFile(
      join(process.cwd(), 'godot', 'games', 'ch09-env-spire', 'levels', 'ch09_env_spire_level.json'),
      'utf8',
    ));
    const playerManifest = JSON.parse(await readFile(
      join(repoRoot, 'apps', 'player', 'public', 'manifest.json'),
      'utf8',
    ));
    const serializedPlayerManifest = JSON.stringify(playerManifest);
    const findGameData = (value: unknown): Record<string, unknown> | undefined => {
      if (Array.isArray(value)) {
        for (const item of value) {
          const found = findGameData(item);
          if (found) return found;
        }
        return undefined;
      }
      if (!value || typeof value !== 'object') return undefined;
      const record = value as Record<string, unknown>;
      if (record.gameId === 'ch09-env-spire') return record;
      for (const child of Object.values(record)) {
        const found = findGameData(child);
        if (found) return found;
      }
      return undefined;
    };
    const playerGameData = findGameData(playerManifest);
    const courseEntryUrl = courseSource.match(
      /"entryUrl": "(\/assets\/godot\/ch09-env-spire\/index\.html(?:\?v=[a-f0-9]{12})?)"/,
    )?.[1];
    const levelEntryUrl = levelManifest.data.entryUrl;
    const playerEntryUrl = playerGameData?.entryUrl;

    expect(courseSource).toContain('"gameId": "ch09-env-spire"');
    expect(courseEntryUrl).toMatch(entryUrlPattern);
    expect(courseSource).toContain('"nodeCount": 12');
    expect(levelManifest.data).toMatchObject({
      gameId: 'ch09-env-spire',
      nodeCount: 12,
    });
    expect(levelEntryUrl).toMatch(entryUrlPattern);
    expect(playerGameData).toMatchObject({ gameId: 'ch09-env-spire', nodeCount: 12 });
    expect(playerEntryUrl).toMatch(entryUrlPattern);
    expect([levelEntryUrl, playerEntryUrl]).toEqual([courseEntryUrl, courseEntryUrl]);
    expect(serializedPlayerManifest).toContain('"gameId":"ch09-env-spire"');
  });

  it('uses an explicit command interpreter for Windows wrappers without shell mode', async () => {
    const { createGodotSpawnSpec } = await import('../godot/tools/export_web.mjs');
    const spec = createGodotSpawnSpec(
      'C:\\Tools\\Godot\\godot.cmd',
      ['--headless', '--path', 'C:\\Project With Spaces'],
      { platform: 'win32', comspec: 'C:\\Windows\\System32\\cmd.exe' },
    );

    expect(spec.command).toBe('C:\\Windows\\System32\\cmd.exe');
    expect(spec.options).toMatchObject({ shell: false });
    expect(spec.args.join(' ')).toContain('godot.cmd');
    expect(spec.args.join(' ')).toContain('Project With Spaces');
  });

  it('excludes editor tooling and tests from both game exports', async () => {
    for (const gameId of ['ch09-env-spire', 'ch11-band-defense', 'ch12-solar-survivor']) {
      const preset = await readFile(
        join(process.cwd(), 'godot', 'games', gameId, 'export_presets.cfg'),
        'utf8',
      );
      expect(preset).toContain('addons/godot_mcp_enhanced/**/*');
      expect(preset).toContain('godot_mcp_config.json');
      expect(preset).toContain('tests/**/*');
      expect(preset).toContain('visual-audit/**/*');
    }
    const ch11Preset = await readFile(
      join(process.cwd(), 'godot', 'games', 'ch11-band-defense', 'export_presets.cfg'),
      'utf8',
    );
    const ch12Preset = await readFile(
      join(process.cwd(), 'godot', 'games', 'ch12-solar-survivor', 'export_presets.cfg'),
      'utf8',
    );
    const ch09Preset = await readFile(
      join(process.cwd(), 'godot', 'games', 'ch09-env-spire', 'export_presets.cfg'),
      'utf8',
    );
    expect(ch09Preset).toContain('export_filter="scenes"');
    expect(ch09Preset).toContain(
      'export_files=PackedStringArray("res://scenes/main.tscn")',
    );
    expect(ch09Preset).toContain('assets/card-art/prototypes/*-v4.png');
    expect(ch09Preset).toContain('assets/enemy-art/*.png');
    for (const runtimeData of [
      'addons/dgbook_runtime/*.gd',
	  'assets/fonts/DingTalkJinBuTi.ttf',
      'assets/fonts/NotoSansSC-VF.ttf',
      'data/cards.local.json',
      'data/enemies.local.json',
      'data/events.local.json',
      'data/relics.local.json',
      'data/run_maps.local.json',
	  'dev/node_lab.gd',
      'levels/ch09_env_spire_level.json',
      'scripts/*.gd',
    ]) {
      expect(ch09Preset).toContain(runtimeData);
    }
    expect(ch09Preset).toContain('data/questions.local.json');
    expect(ch09Preset).toContain('teaching-assets.lock.json');
    expect(ch11Preset).toContain('data/questions.local.json');
    expect(ch11Preset).toContain('teaching-assets.lock.json');
    expect(ch12Preset).toContain('data/questions.local.json');
    expect(ch12Preset).toContain('data/upgrades.local.json');
    expect(ch12Preset).toContain('teaching-assets.lock.json');
  });

  it('ships Ch09 as a desktop-only experience without compact mobile layout branches', async () => {
    const gameRoot = join(process.cwd(), 'godot', 'games', 'ch09-env-spire');
    const project = await readFile(join(gameRoot, 'project.godot'), 'utf8');
    const preset = await readFile(join(gameRoot, 'export_presets.cfg'), 'utf8');
    const rootScript = await readFile(join(gameRoot, 'scripts', 'env_spire_root.gd'), 'utf8');
    const nodeLabScript = await readFile(join(gameRoot, 'dev', 'node_lab.gd'), 'utf8');

    expect(project).not.toContain('rendering_method.mobile');
    expect(preset).not.toContain('vram_texture_compression/for_mobile');
    expect(rootScript).toContain('func is_desktop_viewport_supported(');
    expect(rootScript).toContain('DesktopOnlyOverlay');
    expect(rootScript).not.toContain('_apply_responsive_layout');
    expect(nodeLabScript).not.toContain('_apply_responsive_layout');
    expect(nodeLabScript).not.toContain('var compact');
  });

  it('cleans only a game directory below the configured public Godot root', async () => {
    const { cleanWebExportDirectory } = await import('../godot/tools/export_web.mjs');
    const root = await mkdtemp(join(tmpdir(), 'dgbook-godot-export-'));
    const outputDir = join(root, 'ch11-band-defense');
    await mkdir(outputDir, { recursive: true });
    await writeFile(join(outputDir, 'index.legacy.pck'), 'old', 'utf8');
    await writeFile(join(outputDir, 'local-server.stderr.log'), 'noise', 'utf8');

    await cleanWebExportDirectory(outputDir, root);

    expect(await readdir(outputDir)).toEqual([]);
    await expect(cleanWebExportDirectory(root, root)).rejects.toThrow(/refusing to clean/i);
    await expect(cleanWebExportDirectory(join(root, '..', 'outside'), root)).rejects.toThrow(/refusing to clean/i);
  });

  it('content-addresses the complete Godot runtime and every configured iframe entry', async () => {
    const { finalizeWebExport } = await import('../godot/tools/export_web.mjs');
    const root = await mkdtemp(join(tmpdir(), 'dgbook-godot-finalize-'));
    const outputDir = join(root, 'public', 'assets', 'godot', 'ch11-band-defense');
    const sourceEntry = join(root, 'chapter.py');
    const levelEntry = join(root, 'level.json');
    const manifestEntry = join(root, 'manifest.json');
    await mkdir(outputDir, { recursive: true });
    await writeFile(join(outputDir, 'index.pck'), 'current-pck-content');
    await writeFile(join(outputDir, 'index.wasm'), 'wasm', 'utf8');
    await writeFile(join(outputDir, 'index.js'), 'engine', 'utf8');
    await writeFile(join(outputDir, 'index.audio.worklet.js'), 'audio', 'utf8');
    await writeFile(join(outputDir, 'index.audio.position.worklet.js'), 'position', 'utf8');
    await writeFile(join(outputDir, 'index.png'), 'splash', 'utf8');
    await writeFile(join(outputDir, 'index.icon.png'), 'icon', 'utf8');
    await writeFile(join(outputDir, 'index.apple-touch-icon.png'), 'apple', 'utf8');
    await writeFile(join(outputDir, 'index.html'), [
      '<link rel="icon" href="index.icon.png">',
      '<link rel="apple-touch-icon" href="index.apple-touch-icon.png">',
      '<img src="index.png">',
      '<script src="index.js"></script>',
      '<script>',
      'const GODOT_CONFIG = {"executable":"index","fileSizes":{"index.pck":19,"index.wasm":4}};',
      'engine.startGame({',
      "  'onProgress': function () {},",
      '});',
      '</script>',
    ].join('\n'), 'utf8');
    await writeFile(sourceEntry, '"entryUrl": "/assets/godot/ch11-band-defense/index.html"', 'utf8');
    await writeFile(levelEntry, '"entryUrl": "/assets/godot/ch11-band-defense/index.html?v=aaaaaaaaaaaa"', 'utf8');
    await writeFile(manifestEntry, '"entryUrl": "/assets/godot/ch11-band-defense/index.html?v=bbbbbbbbbbbb"', 'utf8');

    const result = await finalizeWebExport({
      outputDir,
      gameId: 'ch11-band-defense',
      entryFiles: [sourceEntry, levelEntry, manifestEntry],
    });

    expect(result.hash).toMatch(/^[a-f0-9]{12}$/);
    const hash = result.hash;
    const html = await readFile(join(outputDir, 'index.html'), 'utf8');
    expect(html).toContain(`src="index.${hash}.js"`);
    expect(html).toContain(`"executable":"index.${hash}"`);
    expect(html).toContain(`"index.${hash}.pck":19`);
    expect(html).toContain(`"index.${hash}.wasm":4`);
    expect(html).toContain(`'mainPack': 'index.${hash}.pck'`);
    expect(html).toContain(`href="index.${hash}.icon.png"`);
    expect(html).toContain(`href="index.${hash}.apple-touch-icon.png"`);
    expect(html).toContain(`src="index.${hash}.png"`);
    for (const name of [
      `index.${hash}.js`,
      `index.${hash}.wasm`,
      `index.${hash}.pck`,
      `index.${hash}.audio.worklet.js`,
      `index.${hash}.audio.position.worklet.js`,
      `index.${hash}.png`,
      `index.${hash}.icon.png`,
      `index.${hash}.apple-touch-icon.png`,
    ]) {
      await expect(access(join(outputDir, name))).resolves.toBeUndefined();
    }
    expect(await readdir(outputDir)).not.toContain('index.js');
    expect(await readdir(outputDir)).not.toContain('index.wasm');
    expect(await readdir(outputDir)).not.toContain('index.pck');
    for (const file of [sourceEntry, levelEntry, manifestEntry]) {
      expect(await readFile(file, 'utf8')).toContain(
        `/assets/godot/ch11-band-defense/index.html?v=${hash}`,
      );
    }
  });

  it('keeps the live export intact when a staged export is invalid', async () => {
    const { publishStagedWebExport } = await import('../godot/tools/export_web.mjs');
    const root = await mkdtemp(join(tmpdir(), 'dgbook-godot-publish-'));
    const outputDir = join(root, 'ch11-band-defense');
    const stagedOutputDir = join(root, '.ch11-band-defense.staging');
    await mkdir(outputDir, { recursive: true });
    await mkdir(stagedOutputDir, { recursive: true });
    await writeFile(join(outputDir, 'live.marker'), 'known-good', 'utf8');
    await writeFile(join(stagedOutputDir, 'partial.marker'), 'incomplete', 'utf8');

    await expect(publishStagedWebExport({ outputDir, stagedOutputDir })).rejects.toThrow(/missing/i);
    expect(await readFile(join(outputDir, 'live.marker'), 'utf8')).toBe('known-good');
  });
});
