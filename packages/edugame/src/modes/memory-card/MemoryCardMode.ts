import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';
import { createState, flipCard, checkMatch, finalScore, type CardPair, type MemoryCardState } from './logic';

export interface MemoryCardData {
  pairs: ReadonlyArray<CardPair>;
}

export class MemoryCardMode extends GameMode<MemoryCardData> {
  readonly id = 'memory-card' as const;
  readonly displayName = '记忆翻牌';
  readonly objective = '配对翻牌记忆';
  readonly howToPlay = ['点击翻开卡牌', '每次翻两张', '匹配则消除', '用最少次数完成'];

  private state: MemoryCardState = createState([]);

  init(ctx: GameContext): void {
    this.ctx = ctx;
    this.state = createState(this.getLevelData().data.pairs);
  }

  flip(cardIdx: number): void {
    if (!this.ctx || this.state.finished) return;
    this.state = flipCard(this.state, cardIdx);
    if (this.state.revealed.length === 2) {
      // 延迟检查匹配（让玩家看到第二张）
      setTimeout(() => {
        this.state = checkMatch(this.state);
        this.ctx?.onProgress(this.state.matched / this.state.totalPairs, `${this.state.matched}/${this.state.totalPairs}`);
        if (this.state.finished) this.finish();
      }, 600);
    }
  }

  finish(): void {
    if (!this.ctx) return;
    const score = finalScore(this.state);
    const t = this.getLevelData().starThresholds;
    const stars = score >= t[2] ? 3 : score >= t[1] ? 2 : score >= t[0] ? 1 : 0;
    this.ctx.onComplete({ modeId: this.id, levelId: this.getLevelData().levelId, score, stars, durationMs: 0, stats: { attempts: this.state.attempts, matched: this.state.matched } });
  }

  getState(): MemoryCardState { return this.state; }
  destroy(): void { this.state = createState([]); this.ctx = null; }
}
