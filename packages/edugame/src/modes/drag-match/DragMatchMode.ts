import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';
import { createState, submitPair, undoPair, evaluate, finalScore, type DragPair, type DragMatchState } from './logic';

export interface DragMatchData {
  pairs: ReadonlyArray<DragPair>;
}

export class DragMatchMode extends GameMode<DragMatchData> {
  readonly id = 'drag-match' as const;
  readonly displayName = '拖拽匹配';
  readonly objective = '拖拽连线/归类';
  readonly howToPlay = ['左侧 items 拖到右侧 targets', '全部配对后提交', '正确配对越多分越高'];

  private state: DragMatchState = createState([]);
  private pairs: ReadonlyArray<DragPair> = [];

  init(ctx: GameContext): void {
    this.ctx = ctx;
    this.pairs = this.getLevelData().data.pairs;
    this.state = createState(this.pairs);
  }

  match(itemId: string, targetId: string): void {
    if (!this.ctx || this.state.finished) return;
    this.state = submitPair(this.state, itemId, targetId);
    this.ctx.onProgress(this.state.submitted.size / this.state.total);
  }

  undo(itemId: string): void {
    this.state = undoPair(this.state, itemId);
  }

  submit(): void {
    if (!this.ctx || this.state.finished) return;
    this.state = evaluate(this.state, this.pairs);
    const score = finalScore(this.state);
    const t = this.getLevelData().starThresholds;
    const stars = score >= t[2] ? 3 : score >= t[1] ? 2 : score >= t[0] ? 1 : 0;
    this.ctx.onComplete({ modeId: this.id, levelId: this.getLevelData().levelId, score, stars, durationMs: 0, stats: { correct: this.state.correct, total: this.state.total } });
  }

  getState(): DragMatchState { return this.state; }
  destroy(): void { this.state = createState([]); this.pairs = []; this.ctx = null; }
}
