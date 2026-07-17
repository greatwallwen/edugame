/**
 * 核心抽象层单测：ScoreSystem / LevelLoader / GameSession / GameMode lifecycle
 */
import { describe, it, expect, vi } from 'vitest';
import { ScoreSystem } from '../src/core/ScoreSystem';
import { loadLevel, LevelLoadError } from '../src/core/LevelLoader';
import { GameSession } from '../src/core/GameSession';
import { GameMode } from '../src/core/GameMode';
import type { GameContext, LevelData } from '../src/core/types';

class TestMode extends GameMode {
  readonly id = 'bit-flip-quest' as const;
  readonly displayName = 'TestMode';
  readonly objective = 'test';
  readonly howToPlay = ['t1'];
  initCalls = 0;
  destroyCalls = 0;
  pauseCalls = 0;
  resumeCalls = 0;
  updates: number[] = [];
  init(_ctx: GameContext): void { this.initCalls += 1; this.ctx = _ctx; }
  override update(dt: number): void { this.updates.push(dt); }
  override pause(): void { this.pauseCalls += 1; }
  override resume(): void { this.resumeCalls += 1; }
  destroy(): void { this.destroyCalls += 1; }
}

const sampleLevel: LevelData = {
  modeId: 'bit-flip-quest',
  levelId: 'lvl-1',
  title: 'L1',
  objective: 'test',
  difficulty: 1,
  starThresholds: [50, 80, 95],
  timeLimit: 0,
  data: {},
};

describe('ScoreSystem', () => {
  it('hit 累加分数；miss 扣分；clamp 0..100', () => {
    const ss = new ScoreSystem(sampleLevel);
    ss.hit(40);
    ss.hit(30);
    expect(ss.getScore()).toBe(70);
    ss.miss(10);
    expect(ss.getScore()).toBe(60);
    ss.miss(1000);
    expect(ss.getScore()).toBe(0);
  });

  it('combo / maxCombo 在 hit/miss 间正确累计', () => {
    const ss = new ScoreSystem(sampleLevel);
    ss.hit(10); ss.hit(10); ss.hit(10);
    expect(ss.getStats().maxCombo).toBe(3);
    ss.miss();
    ss.hit(10);
    expect(ss.getStats().maxCombo).toBe(3);
  });

  it('星数：阈值 [50,80,95] · 不同得分映射', () => {
    const ss = new ScoreSystem(sampleLevel);
    ss.setScore(40); expect(ss.getStars()).toBe(0);
    ss.setScore(50); expect(ss.getStars()).toBe(1);
    ss.setScore(79); expect(ss.getStars()).toBe(1);
    ss.setScore(80); expect(ss.getStars()).toBe(2);
    ss.setScore(95); expect(ss.getStars()).toBe(3);
    ss.setScore(100); expect(ss.getStars()).toBe(3);
  });
});

describe('LevelLoader', () => {
  it('合法 JSON 顺利加载', () => {
    const lvl = loadLevel({
      modeId: 'bit-flip-quest',
      levelId: 'l1',
      title: 'T',
      objective: 'O',
      difficulty: 2,
      starThresholds: [40, 70, 90],
      timeLimit: 30,
      data: { foo: 1 },
    });
    expect(lvl.modeId).toBe('bit-flip-quest');
    expect(lvl.starThresholds).toEqual([40, 70, 90]);
    expect(lvl.difficulty).toBe(2);
  });

  it('未知 modeId 抛 LevelLoadError', () => {
    expect(() => loadLevel({ modeId: 'unknown', levelId: 'x' })).toThrow(LevelLoadError);
  });

  it('strict 模式下缺 starThresholds 抛错', () => {
    expect(() => loadLevel({ modeId: 'bit-flip-quest', levelId: 'x', objective: 'o' }, { strict: true })).toThrow(LevelLoadError);
  });

  it('non-strict：缺字段时 fallback 默认值', () => {
    const lvl = loadLevel({ modeId: 'bit-flip-quest', levelId: 'x' });
    expect(lvl.starThresholds).toEqual([50, 80, 95]);
    expect(lvl.timeLimit).toBe(0);
  });

  it('阈值会被排序+裁剪到 0..100', () => {
    const lvl = loadLevel({
      modeId: 'bit-flip-quest', levelId: 'x',
      starThresholds: [200, -10, 50],
    });
    // [clamp(200,0,100)=100, clamp(-10,100,100)=100, clamp(50,100,100)=100]
    expect(lvl.starThresholds[0]).toBeLessThanOrEqual(100);
    expect(lvl.starThresholds[1]).toBeGreaterThanOrEqual(lvl.starThresholds[0]);
    expect(lvl.starThresholds[2]).toBeGreaterThanOrEqual(lvl.starThresholds[1]);
  });
});

describe('GameSession lifecycle', () => {
  it('start → mode.init 被调一次，状态 running', async () => {
    const mode = new TestMode();
    const session = new GameSession(mode, sampleLevel);
    await session.start();
    expect(mode.initCalls).toBe(1);
    expect(session.getState()).toBe('running');
  });

  it('pause → resume 触发 mode.pause/resume；状态机正确', async () => {
    const mode = new TestMode();
    const session = new GameSession(mode, sampleLevel);
    await session.start();
    session.pause();
    expect(session.getState()).toBe('paused');
    expect(mode.pauseCalls).toBe(1);
    session.resume();
    expect(session.getState()).toBe('running');
    expect(mode.resumeCalls).toBe(1);
  });

  it('complete → onResult 抛出 + mode.destroy', async () => {
    const mode = new TestMode();
    const cb = vi.fn();
    const session = new GameSession(mode, sampleLevel, { onResult: cb });
    await session.start();
    session.complete({ score: 80 });
    expect(session.getState()).toBe('finished');
    expect(cb).toHaveBeenCalledTimes(1);
    expect(cb.mock.calls[0]?.[0]?.score).toBe(80);
    expect(mode.destroyCalls).toBe(1);
  });

  it('timeLimit 到达后自动 complete', async () => {
    let now = 1000;
    const clock = { now: () => now };
    const lvlWithLimit: LevelData = { ...sampleLevel, timeLimit: 1 };
    const mode = new TestMode();
    const cb = vi.fn();
    const session = new GameSession(mode, lvlWithLimit, { onResult: cb }, clock);
    await session.start();
    now = 2500; // 1.5 秒后
    session.tick();
    expect(cb).toHaveBeenCalledTimes(1);
    expect(session.getState()).toBe('finished');
  });

  it('tick 在 paused 时不调 mode.update', async () => {
    let now = 0;
    const clock = { now: () => now };
    const mode = new TestMode();
    const session = new GameSession(mode, sampleLevel, {}, clock);
    await session.start();
    now = 16; session.tick();
    session.pause();
    now = 32; session.tick();
    expect(mode.updates.length).toBe(1);
  });
});
