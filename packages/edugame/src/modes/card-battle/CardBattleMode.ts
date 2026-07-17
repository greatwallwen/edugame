import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';
import { createState, playCard, finalScore, type BattleQuestion, type CardBattleState } from './logic';

export interface CardBattleData {
  questions: ReadonlyArray<BattleQuestion>;
  playerHp: number;
  aiHp: number;
}

export class CardBattleMode extends GameMode<CardBattleData> {
  readonly id = 'card-battle' as const;
  readonly displayName = '卡牌流程战斗';
  readonly objective = '回合制知识卡牌对战';
  readonly howToPlay = ['每回合出一张知识卡牌', '答对伤害 Boss', '答错自己扣血', '击败 Boss 或血量更多者胜'];

  private state: CardBattleState = createState(0, 0, []);
  private questions: ReadonlyArray<BattleQuestion> = [];

  init(ctx: GameContext): void {
    this.ctx = ctx;
    const data = this.getLevelData().data;
    this.questions = data.questions;
    this.state = createState(data.playerHp, data.aiHp, this.questions);
  }

  selectAnswer(idx: number): boolean {
    if (!this.ctx || this.state.finished) return false;
    const { state: next, correct } = playCard(this.state, this.questions, idx);
    this.state = next;
    this.ctx.onProgress(this.state.currentIdx / this.state.total, `回合 ${this.state.round - 1}`);
    if (this.state.finished) this.finish();
    return correct;
  }

  private finish(): void {
    if (!this.ctx) return;
    const score = finalScore(this.state);
    const t = this.getLevelData().starThresholds;
    const stars = score >= t[2] ? 3 : score >= t[1] ? 2 : score >= t[0] ? 1 : 0;
    this.ctx.onComplete({ modeId: this.id, levelId: this.getLevelData().levelId, score, stars, durationMs: 0, stats: { correct: this.state.correct, wrong: this.state.wrong, playerHp: this.state.playerHp, aiHp: this.state.aiHp } });
  }

  getCurrentQuestion(): BattleQuestion | null {
    return this.questions[this.state.currentIdx] ?? null;
  }

  getState(): CardBattleState { return this.state; }
  destroy(): void { this.state = createState(0, 0, []); this.questions = []; this.ctx = null; }
}
