/**
 * interrupt-defender · 中断防御战
 *
 * 完整逻辑层：玩家配置 NVIC 优先级，tick 驱动 IRQ 调度 + 抢占。
 */
import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';
import {
  createInitialState, setIrqPriority, tick, computeFinalScore,
  type InterruptDefenderState, type IrqWave,
} from './logic';

export interface InterruptDefenderData {
  irqQueue: ReadonlyArray<IrqWave>;
  hp: number;
}

export class InterruptDefenderMode extends GameMode<InterruptDefenderData> {
  readonly id = 'interrupt-defender' as const;
  readonly displayName = '中断防御战';
  readonly objective = 'NVIC 优先级 / 抢占优先级 vs 子优先级 / 中断嵌套';
  readonly howToPlay = [
    '先为各 IRQ 设置抢占优先级（0..15）',
    '高优先级怪物会抢占低优先级处理',
    '城堡 HP 归 0 失败',
  ];

  private state: InterruptDefenderState = createInitialState(100);
  private waves: ReadonlyArray<IrqWave> = [];

  init(ctx: GameContext): void {
    this.ctx = ctx;
    const data = this.getLevelData().data;
    this.waves = data.irqQueue;
    this.state = createInitialState(data.hp);
  }

  /** 玩家配置 IRQ 优先级 */
  configurePriority(tag: string, priority: number): void {
    this.state = setIrqPriority(this.state, tag, priority);
  }

  override update(dt: number): void {
    if (!this.ctx || this.state.finished) return;
    this.state = tick(this.state, this.waves, dt);
    this.ctx.onProgress(
      Math.min(1, this.state.elapsed / Math.max(1, this.getLevelData().timeLimit)),
      `HP ${this.state.hp} · 已处理 ${this.state.handled}`,
    );
    if (this.state.finished || (this.getLevelData().timeLimit > 0 && this.state.elapsed >= this.getLevelData().timeLimit)) {
      this.finish();
    }
  }

  finish(): void {
    if (!this.ctx) return;
    const score = computeFinalScore(this.state, this.waves.length);
    const thresholds = this.getLevelData().starThresholds;
    const stars =
      score >= thresholds[2] ? 3 :
      score >= thresholds[1] ? 2 :
      score >= thresholds[0] ? 1 : 0;
    this.state = { ...this.state, finished: true };
    this.ctx.onComplete({
      modeId: this.id,
      levelId: this.getLevelData().levelId,
      score,
      stars,
      durationMs: Math.round(this.state.elapsed * 1000),
      stats: {
        hp: this.state.hp,
        handled: this.state.handled,
        missed: this.state.missed,
      },
    });
  }

  getState(): InterruptDefenderState { return this.state; }

  destroy(): void {
    this.state = createInitialState(100);
    this.waves = [];
    this.ctx = null;
  }
}
