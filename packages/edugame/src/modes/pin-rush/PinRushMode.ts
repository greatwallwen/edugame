/**
 * pin-rush · 引脚连线竞速
 *
 * 完整逻辑层：维护 state + 暴露 answer / getState / finish 给 host/渲染层。
 */
import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';
import {
  createInitialState, submitAnswer, computeFinalScore,
  type PinRushState, type PinPair,
} from './logic';

export interface PinRushData {
  pairs: ReadonlyArray<PinPair>;
  perItemSeconds: number;
}

export class PinRushMode extends GameMode<PinRushData> {
  readonly id = 'pin-rush' as const;
  readonly displayName = '引脚连线竞速';
  readonly objective = '复用功能映射 / 数据手册查表能力';
  readonly howToPlay = [
    '左侧滚动出现引脚名',
    '右侧弹出外设需求',
    '拖线把外设连到正确引脚',
    '连续正确 → COMBO 加分',
  ];

  private state: PinRushState = createInitialState([]);
  private pairs: ReadonlyArray<PinPair> = [];

  init(ctx: GameContext): void {
    this.ctx = ctx;
    const data = this.getLevelData().data;
    this.pairs = data.pairs;
    this.state = createInitialState(this.pairs);
  }

  /** 玩家提交连线 */
  answer(selectedPin: string): boolean {
    if (!this.ctx || this.state.finished) return false;
    const { state: next, correct } = submitAnswer(this.state, this.pairs, selectedPin);
    this.state = next;
    this.ctx.onProgress(
      this.state.currentIdx / this.state.total,
      `${this.state.correct}/${this.state.total} · combo ×${this.state.combo}`,
    );
    if (this.state.finished) {
      this.finish();
    }
    return correct;
  }

  /** 手动结束（时间到 / 玩家放弃） */
  finish(): void {
    if (!this.ctx) return;
    const score = computeFinalScore(this.state);
    const thresholds = this.getLevelData().starThresholds;
    const stars =
      score >= thresholds[2] ? 3 :
      score >= thresholds[1] ? 2 :
      score >= thresholds[0] ? 1 : 0;
    this.ctx.onComplete({
      modeId: this.id,
      levelId: this.getLevelData().levelId,
      score,
      stars,
      durationMs: 0,
      stats: {
        correct: this.state.correct,
        wrong: this.state.wrong,
        maxCombo: this.state.maxCombo,
      },
    });
  }

  /** 当前题目（渲染层用） */
  getCurrentPair(): PinPair | null {
    if (this.state.currentIdx >= this.pairs.length) return null;
    return this.pairs[this.state.currentIdx] ?? null;
  }

  getState(): PinRushState {
    return this.state;
  }

  destroy(): void {
    this.state = createInitialState([]);
    this.pairs = [];
    this.ctx = null;
  }
}
