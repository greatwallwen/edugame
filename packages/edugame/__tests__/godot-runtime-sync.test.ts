import { mkdtemp, mkdir, readFile, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

async function fixture() {
  const root = await mkdtemp(join(tmpdir(), 'dgbook-runtime-'));
  const sourceDir = join(root, 'shared');
  const gamesDir = join(root, 'games');
  await mkdir(sourceDir, { recursive: true });
  await writeFile(join(sourceDir, 'runtime.gd'), 'class_name DGBRuntime\n', 'utf8');
  await writeFile(join(sourceDir, 'bridge.gd'), 'class_name DGBBridge\n', 'utf8');
  for (const game of ['game-a', 'game-b']) {
    await mkdir(join(gamesDir, game, 'scripts'), { recursive: true });
    await writeFile(join(gamesDir, game, 'project.godot'), 'config_version=5\n', 'utf8');
    await writeFile(join(gamesDir, game, 'scripts', 'game.gd'), '# game owned\n', 'utf8');
  }
  return { root, sourceDir, gamesDir };
}

describe('Godot runtime synchronization', () => {
  it('copies canonical files and writes equal deterministic locks', async () => {
    const { syncRuntime } = await import('../godot/tools/sync_runtime.mjs');
    const { sourceDir, gamesDir } = await fixture();

    const result = await syncRuntime({ sourceDir, gamesDir, mode: 'sync' });

    expect(result.games).toEqual(['game-a', 'game-b']);
    const lockA = await readFile(join(gamesDir, 'game-a', 'dgbook-runtime.lock.json'), 'utf8');
    const lockB = await readFile(join(gamesDir, 'game-b', 'dgbook-runtime.lock.json'), 'utf8');
    expect(lockA).toBe(lockB);
    expect(await readFile(join(gamesDir, 'game-a', 'addons', 'dgbook_runtime', 'runtime.gd'), 'utf8'))
      .toBe('class_name DGBRuntime\n');
  });

  it('is idempotent and never overwrites game-owned files', async () => {
    const { syncRuntime } = await import('../godot/tools/sync_runtime.mjs');
    const { sourceDir, gamesDir } = await fixture();
    await syncRuntime({ sourceDir, gamesDir, mode: 'sync' });
    const firstLock = await readFile(join(gamesDir, 'game-a', 'dgbook-runtime.lock.json'), 'utf8');

    await syncRuntime({ sourceDir, gamesDir, mode: 'sync' });

    expect(await readFile(join(gamesDir, 'game-a', 'dgbook-runtime.lock.json'), 'utf8')).toBe(firstLock);
    expect(await readFile(join(gamesDir, 'game-a', 'scripts', 'game.gd'), 'utf8')).toBe('# game owned\n');
  });

  it('check mode reports modified generated files without repairing them', async () => {
    const { syncRuntime } = await import('../godot/tools/sync_runtime.mjs');
    const { sourceDir, gamesDir } = await fixture();
    await syncRuntime({ sourceDir, gamesDir, mode: 'sync' });
    const generated = join(gamesDir, 'game-b', 'addons', 'dgbook_runtime', 'bridge.gd');
    await writeFile(generated, '# modified\n', 'utf8');

    await expect(syncRuntime({ sourceDir, gamesDir, mode: 'check' }))
      .rejects.toThrow(/game-b.*bridge\.gd/s);
    expect(await readFile(generated, 'utf8')).toBe('# modified\n');
  });

  it('check mode permits Godot-generated script UID sidecars', async () => {
    const { syncRuntime } = await import('../godot/tools/sync_runtime.mjs');
    const { sourceDir, gamesDir } = await fixture();
    await syncRuntime({ sourceDir, gamesDir, mode: 'sync' });
    await writeFile(
      join(gamesDir, 'game-a', 'addons', 'dgbook_runtime', 'runtime.gd.uid'),
      'uid://generated-by-godot\n',
      'utf8',
    );

    await expect(syncRuntime({ sourceDir, gamesDir, mode: 'check' })).resolves.toMatchObject({
      games: ['game-a', 'game-b'],
    });
  });

  it('can keep the standalone template synchronized as an explicit target', async () => {
    const { syncRuntime } = await import('../godot/tools/sync_runtime.mjs');
    const { root, sourceDir, gamesDir } = await fixture();
    const templateDir = join(root, 'template');
    await mkdir(templateDir, { recursive: true });
    await writeFile(join(templateDir, 'project.godot'), 'config_version=5\n', 'utf8');

    const result = await syncRuntime({
      sourceDir,
      gamesDir,
      mode: 'sync',
      extraTargets: [{ name: 'template', directory: templateDir }],
    });

    expect(result.games).toContain('template');
    expect(await readFile(join(templateDir, 'addons', 'dgbook_runtime', 'bridge.gd'), 'utf8'))
      .toBe('class_name DGBBridge\n');
  });
});
