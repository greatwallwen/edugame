import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';
import { createState, answer, finalScore, type BossQuestion, type BossReviewState } from './logic';

export interface BossReviewData {
  questions: ReadonlyArray<BossQuestion>;
  bossHp: number;
  playerHp: number;
}

export class BossReviewMode extends GameMode<BossReviewData> {
  readonly id = 'boss-review' as const;
  readonly displayName = 'Boss 复习战';
  readonly objective = '多轮答题打 Boss';
  readonly howToPlay = ['每轮回答一道题', '答对伤害 Boss', '答错自己扣血', '连续答对 combo 加成伤害'];

  private state: BossReviewState = createState(0, 0, []);
  private questions: ReadonlyArray<BossQuestion> = [];

  init(ctx: GameContext): void {
    this.ctx = ctx;
    const data = this.getLevelData().data;
    this.questions = data.questions;
    this.state = createState(data.bossHp, data.playerHp, this.questions);
  }

  selectAnswer(idx: number): boolean {
    if (!this.ctx || this.state.finished) return false;
    const { state: next, correct } = answer(this.state, this.questions, idx);
    this.state = next;
    this.ctx.onProgress(this.state.currentIdx / this.state.total, `${this.state.correct}/${this.state.total}`);
    if (this.state.finished) this.finish();
    return correct;
  }

  private finish(): void {
    if (!this.ctx) return;
    const score = finalScore(this.state);
    const t = this.getLevelData().starThresholds;
    const stars = score >= t[2] ? 3 : score >= t[1] ? 2 : score >= t[0] ? 1 : 0;
    this.ctx.onComplete({ modeId: this.id, levelId: this.getLevelData().levelId, score, stars, durationMs: 0, stats: { correct: this.state.correct, wrong: this.state.wrong, maxCombo: this.state.maxCombo, bossHp: this.state.bossHp, playerHp: this.state.playerHp } });
  }

  getCurrentQuestion(): BossQuestion | null {
    return this.questions[this.state.currentIdx] ?? null;
  }

  getState(): BossReviewState { return this.state; }
  destroy(): void { this.state = createState(0, 0, []); this.questions = []; this.ctx = null; }
}
