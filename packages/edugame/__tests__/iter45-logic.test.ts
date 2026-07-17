/**
 * 四模板逻辑层单元测试
 * sort-flow / card-battle / boss-review / match-3
 */
import { describe, it, expect, vi } from 'vitest';
import { GameSession } from '../src/core/GameSession';
import type { LevelData } from '../src/core/types';
import { SortFlowMode } from '../src/modes/sort-flow';
import { createState as sfCreate, moveItem as sfMove, evaluate as sfEval } from '../src/modes/sort-flow/logic';
import { CardBattleMode } from '../src/modes/card-battle';
import { createState as cbCreate, playCard, finalScore as cbScore } from '../src/modes/card-battle/logic';
import { BossReviewMode } from '../src/modes/boss-review';
import { createState as brCreate, answer as brAnswer, finalScore as brScore } from '../src/modes/boss-review/logic';
import { Match3Mode } from '../src/modes/match-3';
import { createState as m3Create, findMatches, finalScore as m3Score, swap as m3Swap } from '../src/modes/match-3/logic';

describe('SortFlowMode logic', () => {
  const items = [{ id: 'a', label: 'A' }, { id: 'b', label: 'B' }, { id: 'c', label: 'C' }];
  it('no shuffle keeps order', () => { expect(sfCreate(items, false).items).toEqual(['a', 'b', 'c']); });
  it('moveItem swaps', () => { expect(sfMove(sfCreate(items, false), 0, 2).items).toEqual(['b', 'c', 'a']); });
  it('all correct → 100', () => { const r = sfEval(sfCreate(items, false), items); expect(r.score).toBe(100); });
  it('none correct → 0', () => { let s = sfMove(sfCreate(items, false), 0, 2); s = sfMove(s, 0, 2); expect(sfEval(s, items).score).toBe(0); });
  it('Mode via GameSession', async () => {
    const level: LevelData = { modeId: 'sort-flow', levelId: 'sf-1', title: 'T', objective: 'O', difficulty: 1, starThresholds: [40, 70, 90], timeLimit: 0, data: { steps: items } };
    const mode = new SortFlowMode(); const cb = vi.fn();
    await new GameSession(mode, level, { onResult: cb }).start();
    // 洗牌后手动排回正确顺序
    const st = mode.getState();
    const correct = items.map(i => i.id);
    // 逐位修正
    for (let i = 0; i < correct.length; i++) {
      const curIdx = mode.getState().items.indexOf(correct[i]!);
      if (curIdx !== i) mode.move(curIdx, i);
    }
    mode.submit(); expect(cb).toHaveBeenCalledTimes(1); expect(cb.mock.calls[0]?.[0]?.score).toBe(100);
  });
});

describe('CardBattleMode logic', () => {
  const qs = [{ id: '1', prompt: 'Q1', options: ['A', 'B'], correctIndex: 0 }, { id: '2', prompt: 'Q2', options: ['A', 'B'], correctIndex: 1 }, { id: '3', prompt: 'Q3', options: ['A', 'B'], correctIndex: 0 }];
  it('全对 → win', () => {
    let s = cbCreate(100, 60, qs);
    ({ state: s } = playCard(s, qs, 0)); ({ state: s } = playCard(s, qs, 1)); ({ state: s } = playCard(s, qs, 0));
    expect(s.result).toBe('win'); expect(s.aiHp).toBe(0); expect(cbScore(s)).toBeGreaterThanOrEqual(50);
  });
  it('全错 → lose', () => {
    let s = cbCreate(30, 100, qs);
    ({ state: s } = playCard(s, qs, 1)); ({ state: s } = playCard(s, qs, 0));
    expect(s.result).toBe('lose');
  });
  it('Mode via GameSession', async () => {
    const level: LevelData = { modeId: 'card-battle', levelId: 'cb-1', title: 'T', objective: 'O', difficulty: 1, starThresholds: [30, 60, 90], timeLimit: 0, data: { questions: qs, playerHp: 100, aiHp: 60 } };
    const mode = new CardBattleMode(); const cb = vi.fn();
    await new GameSession(mode, level, { onResult: cb }).start();
    mode.selectAnswer(0); mode.selectAnswer(1); mode.selectAnswer(0);
    expect(cb).toHaveBeenCalledTimes(1);
  });
});

describe('BossReviewMode logic', () => {
  const qs = [{ id: '1', prompt: 'Q1', options: ['A', 'B'], correctIndex: 0 }, { id: '2', prompt: 'Q2', options: ['A', 'B'], correctIndex: 1 }, { id: '3', prompt: 'Q3', options: ['A', 'B'], correctIndex: 0 }];
  it('全对 → win + combo', () => {
    let s = brCreate(60, 100, qs);
    ({ state: s } = brAnswer(s, qs, 0)); ({ state: s } = brAnswer(s, qs, 1)); ({ state: s } = brAnswer(s, qs, 0));
    expect(s.result).toBe('win'); expect(s.maxCombo).toBe(3); expect(brScore(s)).toBeGreaterThanOrEqual(60);
  });
  it('全错 → lose', () => {
    let s = brCreate(100, 20, qs);
    ({ state: s } = brAnswer(s, qs, 1)); ({ state: s } = brAnswer(s, qs, 0));
    expect(s.result).toBe('lose');
  });
  it('Mode via GameSession', async () => {
    const level: LevelData = { modeId: 'boss-review', levelId: 'br-1', title: 'T', objective: 'O', difficulty: 1, starThresholds: [30, 60, 90], timeLimit: 0, data: { questions: qs, bossHp: 60, playerHp: 100 } };
    const mode = new BossReviewMode(); const cb = vi.fn();
    await new GameSession(mode, level, { onResult: cb }).start();
    mode.selectAnswer(0); mode.selectAnswer(1); mode.selectAnswer(0);
    expect(cb).toHaveBeenCalledTimes(1);
  });
});

describe('Match3Mode logic', () => {
  const cats = ['R', 'G', 'B', 'Y'];
  it('no initial matches', () => { expect(findMatches(m3Create(6, 6, cats, 10).grid, 6, 6).length).toBe(0); });
  it('horizontal match', () => { expect(findMatches([['R','R','R'],['G','B','Y'],['B','G','R']], 3, 3).length).toBe(3); });
  it('vertical match', () => { expect(findMatches([['R','G','B'],['R','B','Y'],['R','G','B']], 3, 3).length).toBe(3); });
  it('non-adjacent swap noop', () => { const s = m3Create(4, 4, cats, 10); expect(m3Swap(s, 0, 0, 2, 2, cats)).toBe(s); });
  it('finalScore 0 when maxMoves=0', () => { expect(m3Score(m3Create(3, 3, cats, 0))).toBe(0); });
  it('Mode lifecycle', async () => {
    const level: LevelData = { modeId: 'match-3', levelId: 'm3-1', title: 'T', objective: 'O', difficulty: 1, starThresholds: [30, 60, 90], timeLimit: 0, data: { rows: 5, cols: 5, categories: cats, maxMoves: 10 } };
    const mode = new Match3Mode();
    await new GameSession(mode, level, { onResult: vi.fn() }).start();
    expect(mode.getState().rows).toBe(5); mode.destroy();
  });
});
