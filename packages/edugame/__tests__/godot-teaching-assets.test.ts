import { readFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

describe('Godot teaching asset separation', () => {
  const repositoryRoot = resolve(process.cwd(), '..', '..');

  it('keeps course-owned sources, public assets, and local preview mirrors in sync', async () => {
    const { syncTeachingAssets } = await import('../godot/tools/sync_teaching_assets.mjs');
    const result = await syncTeachingAssets({ repositoryRoot, mode: 'check' });

    expect(result.assets).toHaveLength(4);
    expect(result.assets.every((asset: { hash: string }) => /^[a-f0-9]{12}$/.test(asset.hash))).toBe(true);
  });

  it('keeps all teaching questions in course-owned canonical files', async () => {
    const ch11 = JSON.parse(await readFile(
      join(repositoryRoot, 'courses/stm32f10x/knowledge/ch11-band-defense.questions.json'),
      'utf8',
    ));
    const ch12 = JSON.parse(await readFile(
      join(repositoryRoot, 'courses/stm32f10x/knowledge/ch12-solar-survivor.questions.json'),
      'utf8',
    ));

    expect(ch11).toHaveLength(30);
    expect(ch12).toHaveLength(25);
  });
});
