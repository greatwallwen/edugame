import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';
import { createState, swap, finalScore, type Match3State } from './logic';

export interface Match3Data {
  rows: number;
  cols: number;
  /** 分类 ID 列表（至少 4 种以保证可玩性） */
  categories: ReadonlyArray<string>;
  maxMoves: number;
}

export class Match3Mode extends GameMode<Match3Data> {
  readonly id = 'match-3' as const;
  readonly displayName = '三消分类';
  readonly objective = '消除同类知识点';
  readonly howToPlay = ['交换相邻格子', '同类三连即消除', '连锁消除额外加分', '在步数内尽量多消'];

  private state: Match3State = createState(0, 0, [], 0);
  private categories: ReadonlyArray<string> = [];

  init(ctx: GameContext): void {
    this.ctx = ctx;
    const data = this.getLevelData().data;
    this.categories = data.categories;
    this.state = createState(data.rows, data.cols, this.categories, data.maxMoves);
  }

  doSwap(r1: number, c1: number, r2: number, c2: number): boolean {
    if (!this.ctx || this.state.finished) return false;
    const prev = this.state;
    this.state = swap(this.state, r1, c1, r2, c2, this.categories);
    const moved = this.state !== prev;
    if (moved) {
      this.ctx.onProgress(this.state.moves / this.state.maxMoves, `${this.state.moves}/${this.state.maxMoves}`);
      if (this.state.finished) this.finish();
    }
    return moved;
  }

  private finish(): void {
    if (!this.ctx) return;
    const score = finalScore(this.state);
    const t = this.getLevelData().starThresholds;
    const stars = score >= t[2] ? 3 : score >= t[1] ? 2 : score >= t[0] ? 1 : 0;
    this.ctx.onComplete({ modeId: this.id, levelId: this.getLevelData().levelId, score, stars, durationMs: 0, stats: { totalMatched: this.state.totalMatched, moves: this.state.moves, score: this.state.score } });
  }

  getState(): Match3State { return this.state; }
  destroy(): void { this.state = createState(0, 0, [], 0); this.categories = []; this.ctx = null; }
}
