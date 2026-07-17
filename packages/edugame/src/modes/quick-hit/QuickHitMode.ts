import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';
import { createState, answer, tick, finalScore, type QuickHitQuestion, type QuickHitState } from './logic';

export interface QuickHitData {
  questions: ReadonlyArray<QuickHitQuestion>;
  timeLimitSec: number;
}

export class QuickHitMode extends GameMode<QuickHitData> {
  readonly id = 'quick-hit' as const;
  readonly displayName = '知识快打';
  readonly objective = '限时点击正确答案';
  readonly howToPlay = ['屏幕出现多个选项', '在倒计时内点击正确答案', '连续正确 combo 加分'];

  private state: QuickHitState = createState([], 0);
  private questions: ReadonlyArray<QuickHitQuestion> = [];

  init(ctx: GameContext): void {
    this.ctx = ctx;
    const data = this.getLevelData().data;
    this.questions = data.questions;
    this.state = createState(this.questions, data.timeLimitSec);
  }

  override update(dt: number): void {
    if (!this.ctx || this.state.finished) return;
    this.state = tick(this.state, dt);
    this.ctx.onProgress(this.state.currentIdx / this.state.total, `${this.state.correct}/${this.state.total}`);
    if (this.state.finished) this.finish();
  }

  selectAnswer(idx: number): boolean {
    if (!this.ctx || this.state.finished) return false;
    const { state: next, correct } = answer(this.state, this.questions, idx);
    this.state = next;
    if (this.state.finished) this.finish();
    return correct;
  }

  finish(): void {
    if (!this.ctx) return;
    const score = finalScore(this.state);
    const t = this.getLevelData().starThresholds;
    const stars = score >= t[2] ? 3 : score >= t[1] ? 2 : score >= t[0] ? 1 : 0;
    this.ctx.onComplete({ modeId: this.id, levelId: this.getLevelData().levelId, score, stars, durationMs: 0, stats: { correct: this.state.correct, wrong: this.state.wrong, maxCombo: this.state.maxCombo } });
  }

  getCurrentQuestion(): QuickHitQuestion | null {
    return this.questions[this.state.currentIdx] ?? null;
  }

  getState(): QuickHitState { return this.state; }

  destroy(): void { this.state = createState([], 0); this.questions = []; this.ctx = null; }
}
