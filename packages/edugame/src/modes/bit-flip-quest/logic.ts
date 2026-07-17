/**
 * bit-flip-quest · 纯逻辑层
 *
 * 把"应用一组 BitOp 后得到的最终值 + 命中度"算清楚。
 * 不依赖 PixiJS / DOM，可在 vitest 单测内直接验证。
 */
import type { BitOp } from './types';

/** 把 value 截断到 width 位无符号 */
function maskWidth(value: number, width: number): number {
  if (width >= 32) {
    // 32 位无符号：用 >>> 0 兜底
    return value >>> 0;
  }
  return value & ((1 << width) - 1);
}

/** 应用单条操作 */
export function applyOp(value: number, op: BitOp, width: number): number {
  switch (op.op) {
    case 'or':
      return maskWidth(value | op.mask, width);
    case 'and':
      return maskWidth(value & op.mask, width);
    case 'xor':
      return maskWidth(value ^ op.mask, width);
    case 'shl':
      return maskWidth(value << op.bits, width);
    case 'shr':
      return maskWidth(value >>> op.bits, width);
  }
}

/** 顺序应用一组操作，返回每步快照 + 终态 */
export function applyOps(
  initial: number,
  ops: ReadonlyArray<BitOp>,
  width: number,
): { snapshots: number[]; final: number } {
  const snapshots: number[] = [];
  let v = maskWidth(initial, width);
  for (const op of ops) {
    v = applyOp(v, op, width);
    snapshots.push(v);
  }
  return { snapshots, final: v };
}

/**
 * 命中度：与 target 同位的比特占总位数的比例（0..100）。
 * 例：target = 0b1111_0000，final = 0b1110_0000 → 7/8 命中 → 87.5。
 */
export function bitAccuracy(final: number, target: number, width: number): number {
  const f = maskWidth(final, width);
  const t = maskWidth(target, width);
  const diff = (f ^ t) >>> 0;
  let mismatched = 0;
  for (let i = 0; i < width; i++) {
    if ((diff >>> i) & 1) mismatched += 1;
  }
  const matched = width - mismatched;
  return Math.round((matched / width) * 1000) / 10; // 1 位小数
}

/**
 * 评分：命中度 + 牌数节制。
 * 公式：score = accuracy * (1 - 0.05 * usedCardOver)
 *   - usedCardOver = max(0, used - cardLimit)，超牌每张扣 5%
 *   - 命中 100 时强制 100（避免数值抖动）
 */
export function computeScore(
  accuracy: number,
  used: number,
  cardLimit: number,
): number {
  if (accuracy >= 100) return 100;
  const over = Math.max(0, used - cardLimit);
  const factor = Math.max(0, 1 - 0.05 * over);
  return Math.round(accuracy * factor);
}
