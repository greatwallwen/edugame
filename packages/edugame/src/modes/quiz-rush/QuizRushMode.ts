import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';
import { createState, answer, tick, finalScore, type QuickHitQuestion, type QuickHitState } from '../quick-hit/logic';

export interface QuizRushData {
  questions: ReadonlyArray<QuickHitQuestion>;
  timeLimitSec: number;
  bonusTimeSec?: number;
}

export class QuizRushMode extends GameMode<QuizRushData> {
  readonly id = 'quiz-rush' as const;
  readonly displayName = '限时问答冲刺';
  readonly objective = '倒计时连续答题';
  readonly howToPlay = ['倒计时不断减少', '答对加时间', '答错扣分不加时', '坚持到最后'];

  private state: QuickHitState = createState([], 0);
  private questions: ReadonlyArray<QuickHitQuestion> = [];
  private bonusTime = 2;

  init(ctx: GameContext): void {
    this.ctx = ctx;
    const data = this.getLevelData().data;
    this.questions = data.questions;
    this.bonusTime = data.bonusTimeSec ?? 2;
    this.state = createState(this.questions, data.timeLimitSec);
  }

  override update(dt: number): void {
    if (!this.ctx || this.state.finished) return;
    this.state = tick(this.state, dt);
    this.ctx.onProgress(this.state.currentIdx / this.state.total, `剩余 ${Math.ceil(this.state.timeLeft)}s`);
    if (this.state.finished) this.finish();
  }

  selectAnswer(idx: number): boolean {
    if (!this.ctx || this.state.finished) return false;
    const { state: next, correct } = answer(this.state, this.questions, idx);
    this.state = next;
    if (correct) this.state = { ...this.state, timeLeft: this.state.timeLeft + this.bonusTime };
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

  getCurrentQuestion(): QuickHitQuestion | null { return this.questions[this.state.currentIdx] ?? null; }
  getState(): QuickHitState { return this.state; }
  destroy(): void { this.state = createState([], 0); this.questions = []; this.ctx = null; }
}
