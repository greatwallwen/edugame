import { describe, expect, it, vi } from 'vitest';
import { GameSession } from '../src/core/GameSession';
import type { GameResult, LevelData } from '../src/core/types';
import { resolveGodotInitData } from '../src/core/EduGameHost';
import {
  getGodotResultPresentation,
  createGodotInitGate,
  GodotGameMode,
  isGodotToHostMessage,
  normalizeGodotResult,
  type GodotGameData,
} from '../src/modes/godot-game';

const level: LevelData<GodotGameData> = {
  modeId: 'godot-game',
  levelId: 'godot-gpio-01',
  title: 'GPIO Wiring Lab',
  objective: 'Wire an LED and drive PA5 high',
  difficulty: 2,
  starThresholds: [60, 80, 95],
  timeLimit: 0,
  data: {
    gameId: 'gpio-lab',
    entryUrl: '/assets/godot/gpio-lab/index.html',
  },
};

describe('godot-game protocol', () => {
  const result = (stats?: Record<string, number>): GameResult => ({
    modeId: 'godot-game',
    levelId: 'test',
    score: 81,
    stars: 2,
    durationMs: 1000,
    stats,
  });

  it('presents Ch11 and Ch12 native scores with game-specific labels', () => {
    expect(getGodotResultPresentation(result({ bandScore: 8450 }))).toMatchObject({
      label: '手环分',
      score: 8450,
    });
    expect(getGodotResultPresentation(result({ solarScore: 1560 }))).toMatchObject({
      label: '追光分',
      score: 1560,
    });
  });

  it('falls back to the normalized result score for other Godot games', () => {
    expect(getGodotResultPresentation(result())).toMatchObject({ label: '得分', score: 81 });
  });

  it('does not treat stats from non-Godot modes as Godot-native scores', () => {
    const nonGodotResult: GameResult = {
      ...result({ bandScore: 8450, solarScore: 1560 }),
      modeId: 'quick-hit',
    };

    expect(getGodotResultPresentation(nonGodotResult)).toMatchObject({
      label: '得分',
      score: 81,
    });
  });

  it('claims initialization once per iframe load and invalidates stale async work', () => {
    const gate = createGodotInitGate();
    const first = gate.claim();

    expect(first).not.toBeNull();
    expect(gate.claim()).toBeNull();
    expect(gate.isCurrent(first!)).toBe(true);

    gate.reset();
    expect(gate.isCurrent(first!)).toBe(false);
    const second = gate.claim();
    expect(second).not.toBeNull();
    expect(second).not.toBe(first);
  });

  it('normalizes score and derives stars from level thresholds', () => {
    const result = normalizeGodotResult(level, {
      type: 'DGB_GODOT_COMPLETE',
      score: 106.4,
      durationMs: 1234.6,
      stats: { mistakes: 1 },
    });

    expect(result.score).toBe(100);
    expect(result.stars).toBe(3);
    expect(result.durationMs).toBe(1235);
    expect(result.stats?.mistakes).toBe(1);
  });

  it('rejects malformed messages at the iframe protocol boundary', () => {
    expect(isGodotToHostMessage({ type: 'DGB_GODOT_READY', version: 1, gameId: 'ch11' })).toBe(true);
    expect(isGodotToHostMessage({ type: 'DGB_GODOT_PROGRESS', progress: 0.5, stats: { leaks: 1 } })).toBe(true);
    expect(isGodotToHostMessage({ type: 'DGB_GODOT_COMPLETE', score: 91, stars: 3 })).toBe(true);
    expect(isGodotToHostMessage({ type: 'DGB_GODOT_LOG', level: 'warn', message: 'test' })).toBe(true);

    for (const malformed of [
      { type: 'DGB_GODOT_READY', version: '1' },
      { type: 'DGB_GODOT_PROGRESS' },
      { type: 'DGB_GODOT_PROGRESS', progress: Number.NaN },
      { type: 'DGB_GODOT_PROGRESS', progress: 0.5, stats: { leaks: Number.POSITIVE_INFINITY } },
      { type: 'DGB_GODOT_COMPLETE', score: Number.POSITIVE_INFINITY },
      { type: 'DGB_GODOT_COMPLETE', score: 90, stars: -1 },
      { type: 'DGB_GODOT_COMPLETE', score: 90, stars: 1.5 },
      { type: 'DGB_GODOT_COMPLETE', score: 90, durationMs: Number.NaN },
      { type: 'DGB_GODOT_LOG', level: 'fatal', message: 'test' },
      { type: 'DGB_GODOT_LOG' },
    ]) {
      expect(isGodotToHostMessage(malformed)).toBe(false);
    }
  });

  it('defensively normalizes non-finite direct completion input', () => {
    const result = normalizeGodotResult(level, {
      type: 'DGB_GODOT_COMPLETE',
      score: Number.NaN,
      stars: 9 as 3,
      durationMs: Number.POSITIVE_INFINITY,
      stats: { broken: Number.NaN },
    });

    expect(result).toMatchObject({ score: 0, stars: 0, durationMs: 0 });
    expect(result.stats).toBeUndefined();
  });

  it('lets Godot completion drive GameSession completion once', async () => {
    const mode = new GodotGameMode();
    const onResult = vi.fn();
    const session = new GameSession(mode, level, { onResult });
    await session.start();

    mode.completeFromGodot({ type: 'DGB_GODOT_COMPLETE', score: 81 });
    mode.completeFromGodot({ type: 'DGB_GODOT_COMPLETE', score: 20 });

    expect(onResult).toHaveBeenCalledTimes(1);
    expect(onResult.mock.calls[0]?.[0]?.stars).toBe(2);
  });

  it('fails closed when a required external teaching asset cannot be loaded', async () => {
    const fetchMock = vi.fn().mockResolvedValue({ ok: false, status: 503 });
    vi.stubGlobal('fetch', fetchMock);

    await expect(resolveGodotInitData({
      ...level.data,
      knowledgeSource: 'external',
      questionsUrl: '/knowledge/questions.json?v=123456789abc',
    })).rejects.toThrow(/503/);

    vi.unstubAllGlobals();
  });

  it('rejects malformed external teaching arrays instead of starting empty', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ not: 'an array' }),
    });
    vi.stubGlobal('fetch', fetchMock);

    await expect(resolveGodotInitData({
      ...level.data,
      knowledgeSource: 'external',
      questionsUrl: '/knowledge/questions.json?v=123456789abc',
    })).rejects.toThrow(/questions/i);

    vi.unstubAllGlobals();
  });
});
