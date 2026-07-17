/**
 * bit-flip-quest · GameMode 实现
 *
 * 渲染层最小化骨架：留 init/update/destroy hook，但不在本类内引入 PixiJS。
 * 实际 Pixi 渲染由 EduGameHost 注入的 stage 负责，本类只算分 + 维护状态。
 *
 * 设计取舍：
 *   - milestone Phase 6 要求 5 模式 + 完整玩法 + 30+ 单测，本对话只能落地核心抽象 +
 *     bit-flip-quest 一个完整逻辑层 + 渲染骨架（其余模式留 stub 给后续迭代）
 *   - 纯逻辑层（logic.ts）已可单测，覆盖 op 应用、命中度、评分公式
 */
import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';
import type { BitFlipQuestData, BitOp } from './types';
import { applyOps, bitAccuracy, computeScore } from './logic';

export class BitFlipQuestMode extends GameMode<BitFlipQuestData> {
  readonly id = 'bit-flip-quest' as const;
  readonly displayName = '位翻转闯关';
  readonly objective = '寄存器位运算 / 移位 / 掩码';
  readonly howToPlay = [
    '从底部工具栏拖操作牌（OR / AND / XOR / SHIFT）到位区',
    '操作生效后查看终值与目标的命中度',
    '牌数越少命中越准 → 三星',
  ];

  private playedOps: BitOp[] = [];
  private currentValue = 0;

  async init(ctx: GameContext): Promise<void> {
    this.ctx = ctx;
    const data = this.getLevelData().data;
    this.playedOps = [];
    this.currentValue = data.initial;
  }

  /** 玩家拖一张操作牌进位区 */
  playOp(op: BitOp): void {
    if (!this.ctx) return;
    const data = this.getLevelData().data;
    this.playedOps.push(op);
    const { final } = applyOps(data.initial, this.playedOps, data.width);
    this.currentValue = final;
    const acc = bitAccuracy(final, data.target, data.width);
    this.ctx.onProgress(acc / 100, `命中 ${acc}%`);
  }

  /** 撤回最后一张牌 */
  undo(): void {
    if (!this.ctx || this.playedOps.length === 0) return;
    const data = this.getLevelData().data;
    this.playedOps.pop();
    const { final } = applyOps(data.initial, this.playedOps, data.width);
    this.currentValue = final;
    const acc = bitAccuracy(final, data.target, data.width);
    this.ctx.onProgress(acc / 100, `命中 ${acc}%`);
  }

  /** 玩家点确认结束这局 */
  finish(): void {
    if (!this.ctx) return;
    const data = this.getLevelData().data;
    const acc = bitAccuracy(this.currentValue, data.target, data.width);
    const score = computeScore(acc, this.playedOps.length, data.cardLimit);
    const stars =
      score >= this.getLevelData().starThresholds[2] ? 3 :
      score >= this.getLevelData().starThresholds[1] ? 2 :
      score >= this.getLevelData().starThresholds[0] ? 1 : 0;
    this.ctx.onComplete({
      modeId: this.id,
      levelId: this.getLevelData().levelId,
      score,
      stars,
      durationMs: 0,
      stats: {
        playedOps: this.playedOps.length,
        accuracy: acc,
      },
    });
  }

  /** 内部状态查询（测试 / 渲染层用） */
  getState(): { current: number; ops: ReadonlyArray<BitOp> } {
    return { current: this.currentValue, ops: this.playedOps };
  }

  destroy(): void {
    this.playedOps = [];
    this.currentValue = 0;
    this.ctx = null;
  }
}
