import { lstat, realpath } from 'node:fs/promises';
import { join, normalize } from 'node:path';
import { describe, expect, it } from 'vitest';

describe('Godot production asset layout', () => {
  it('resolves each game-local asset link to the central EduGame asset library', async () => {
    for (const gameId of ['ch09-env-spire', 'ch11-band-defense', 'ch12-solar-survivor']) {
      const central = join(process.cwd(), 'assets', 'games', gameId);
      const gameLocal = join(process.cwd(), 'godot', 'games', gameId, 'assets');
      const localStats = await lstat(gameLocal);

      expect(localStats.isSymbolicLink(), `${gameId} assets should be a link`).toBe(true);
      expect(normalize(await realpath(gameLocal))).toBe(normalize(await realpath(central)));
    }
  });
});
