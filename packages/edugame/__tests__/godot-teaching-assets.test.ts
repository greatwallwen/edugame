import { readFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

describe('Godot teaching asset separation', () => {
  const repositoryRoot = resolve(process.cwd(), '..', '..');

  it('keeps course-owned sources, public assets, and local preview mirrors in sync', async () => {
    const { syncTeachingAssets } = await import('../godot/tools/sync_teaching_assets.mjs');
    const result = await syncTeachingAssets({ repositoryRoot, mode: 'check' });

    expect(result.assets).toHaveLength(5);
    expect(result.assets.every((asset: { hash: string }) => /^[a-f0-9]{12}$/.test(asset.hash))).toBe(true);
  });

  it('keeps all teaching questions in course-owned canonical files', async () => {
    const ch09 = JSON.parse(await readFile(
      join(repositoryRoot, 'courses/stm32f10x/knowledge/ch09-env-spire.questions.json'),
      'utf8',
    ));
    const ch11 = JSON.parse(await readFile(
      join(repositoryRoot, 'courses/stm32f10x/knowledge/ch11-band-defense.questions.json'),
      'utf8',
    ));
    const ch12 = JSON.parse(await readFile(
      join(repositoryRoot, 'courses/stm32f10x/knowledge/ch12-solar-survivor.questions.json'),
      'utf8',
    ));

    expect(ch09).toHaveLength(16);
    expect(ch11).toHaveLength(30);
    expect(ch12).toHaveLength(25);
  });

  it('keeps Ch09 event mechanics separate from course-owned question content', async () => {
    const mechanics = JSON.parse(await readFile(
      join(repositoryRoot, 'packages/edugame/godot/games/ch09-env-spire/data/events.local.json'),
      'utf8',
    )).events;

    expect(mechanics).toHaveLength(16);
    for (const event of mechanics) {
      expect(event.questionId).toBe(event.id);
      expect(event.rewardChoices).toHaveLength(2);
      expect(event.penalty).toBeTypeOf('object');
      expect(event).not.toHaveProperty('prompt');
      expect(event).not.toHaveProperty('options');
      expect(event).not.toHaveProperty('correctAnswer');
      expect(event).not.toHaveProperty('explanation');
    }
  });
});
