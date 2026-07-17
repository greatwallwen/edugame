/**
 * bit-flip-quest 单测：纯逻辑层 + Mode 集成
 */
import { describe, it, expect, vi } from 'vitest';
import {
  applyOp, applyOps, bitAccuracy, computeScore,
  BitFlipQuestMode,
} from '../src/modes/bit-flip-quest';
import type { BitFlipQuestLevel } from '../src/modes/bit-flip-quest';
import { GameSession } from '../src/core/GameSession';

describe('bit-flip logic · applyOp', () => {
  it('OR 把对应位置 1', () => {
    expect(applyOp(0, { op: 'or', mask: 0b1010 }, 8)).toBe(0b1010);
    expect(applyOp(0b0101, { op: 'or', mask: 0b1010 }, 8)).toBe(0b1111);
  });

  it('AND 用 mask 滤位', () => {
    expect(applyOp(0xFF, { op: 'and', mask: 0x0F }, 8)).toBe(0x0F);
  });

  it('XOR 翻转对应位', () => {
    expect(applyOp(0b1100, { op: 'xor', mask: 0b1010 }, 8)).toBe(0b0110);
  });

  it('SHL/SHR 移位 + 截断到 width', () => {
    expect(applyOp(0b0001, { op: 'shl', bits: 3 }, 8)).toBe(0b1000);
    expect(applyOp(0b1000, { op: 'shr', bits: 3 }, 8)).toBe(0b0001);
    // 8 bit 截断
    expect(applyOp(0xFF, { op: 'shl', bits: 1 }, 8)).toBe(0xFE);
  });

  it('32 位无符号边界：>>> 不溢出', () => {
    const got = applyOp(0x80000000, { op: 'shl', bits: 1 }, 32);
    expect(got >>> 0).toBe(0);
  });
});

describe('bit-flip logic · applyOps + bitAccuracy', () => {
  it('多步操作产生 snapshot 序列', () => {
    const r = applyOps(0, [
      { op: 'or', mask: 0b0001 },
      { op: 'or', mask: 0b0010 },
      { op: 'or', mask: 0b0100 },
    ], 8);
    expect(r.snapshots).toEqual([0b0001, 0b0011, 0b0111]);
    expect(r.final).toBe(0b0111);
  });

  it('bitAccuracy 完全命中 = 100', () => {
    expect(bitAccuracy(0xFF, 0xFF, 8)).toBe(100);
  });

  it('bitAccuracy 7/8 命中 = 87.5', () => {
    expect(bitAccuracy(0b1110_0000, 0b1111_0000, 8)).toBe(87.5);
  });

  it('bitAccuracy 全错 = 0', () => {
    expect(bitAccuracy(0x00, 0xFF, 8)).toBe(0);
  });
});

describe('bit-flip logic · computeScore', () => {
  it('完美命中 → 100，无视用牌数', () => {
    expect(computeScore(100, 5, 1)).toBe(100);
  });

  it('未超牌 → 直接 round(accuracy)', () => {
    expect(computeScore(80, 1, 1)).toBe(80);
    expect(computeScore(75.5, 1, 1)).toBe(76);
  });

  it('超牌每张扣 5%', () => {
    // accuracy=80, used=3, limit=1 → over=2 → factor=0.9 → 72
    expect(computeScore(80, 3, 1)).toBe(72);
  });

  it('超牌过多时分数被压到 0', () => {
    expect(computeScore(80, 100, 1)).toBe(0);
  });
});

describe('BitFlipQuestMode integration', () => {
  const level: BitFlipQuestLevel = {
    modeId: 'bit-flip-quest',
    levelId: 'l-test',
    title: 'T',
    objective: 'O',
    difficulty: 1,
    starThresholds: [50, 80, 95],
    timeLimit: 0,
    data: {
      width: 8,
      initial: 0,
      target: 0b1010_1010,
      cardLimit: 1,
      operations: [
        { op: 'or', mask: 0b1010_1010 },
        { op: 'or', mask: 0b1111_0000 },
      ],
    },
  };

  it('一张牌完美命中 → 100 分 3 星', async () => {
    const mode = new BitFlipQuestMode();
    const cb = vi.fn();
    const session = new GameSession(mode, level, { onResult: cb });
    await session.start();
    mode.playOp({ op: 'or', mask: 0b1010_1010 });
    mode.finish();
    expect(cb).toHaveBeenCalledTimes(1);
    const r = cb.mock.calls[0]?.[0];
    expect(r?.score).toBe(100);
    expect(r?.stars).toBe(3);
    expect(r?.stats?.playedOps).toBe(1);
  });

  it('错误的牌 → 命中度低，星数对应阈值', async () => {
    const mode = new BitFlipQuestMode();
    const cb = vi.fn();
    const session = new GameSession(mode, level, { onResult: cb });
    await session.start();
    mode.playOp({ op: 'or', mask: 0b1111_0000 });
    mode.finish();
    const r = cb.mock.calls[0]?.[0];
    // final = 0b1111_0000, target = 0b1010_1010 → 4/8 命中 = 50 → 1 星
    expect(r?.score).toBe(50);
    expect(r?.stars).toBe(1);
  });

  it('undo 撤回最后一张牌', async () => {
    const mode = new BitFlipQuestMode();
    const session = new GameSession(mode, level);
    await session.start();
    mode.playOp({ op: 'or', mask: 0b1010_1010 });
    mode.playOp({ op: 'or', mask: 0b1111_0000 });
    expect(mode.getState().ops.length).toBe(2);
    mode.undo();
    expect(mode.getState().ops.length).toBe(1);
    expect(mode.getState().current).toBe(0b1010_1010);
  });

  it('多张牌但完美命中 → 仍 100（cardLimit 不影响 100% 上限）', async () => {
    const mode = new BitFlipQuestMode();
    const cb = vi.fn();
    const session = new GameSession(mode, level, { onResult: cb });
    await session.start();
    // 一张就够，但玩家用了两张
    mode.playOp({ op: 'or', mask: 0b1010_1010 });
    mode.playOp({ op: 'and', mask: 0b1111_1111 });
    mode.finish();
    const r = cb.mock.calls[0]?.[0];
    expect(r?.score).toBe(100);
  });
});
