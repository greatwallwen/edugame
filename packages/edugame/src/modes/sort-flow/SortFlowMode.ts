import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';
import { createState, moveItem, evaluate, finalScore, type SortFlowItem, type SortFlowState } from './logic';

export interface SortFlowData {
  /** 正确顺序的步骤列表 */
  steps: ReadonlyArray<SortFlowItem>;
}

export class SortFlowMode extends GameMode<SortFlowData> {
  readonly id = 'sort-flow' as const;
  readonly displayName = '流程排序';
  readonly objective = '拖拽排列正确顺序';
  readonly howToPlay = ['将乱序步骤拖拽到正确位置', '全部排好后提交', '正确位置越多分越高'];

  private state: SortFlowState = createState([], false);
  private steps: ReadonlyArray<SortFlowItem> = [];

  init(ctx: GameContext): void {
    this.ctx = ctx;
    this.steps = this.getLevelData().data.steps;
    this.state = createState(this.steps);
  }

  move(fromIdx: number, toIdx: number): void {
    if (!this.ctx || this.state.finished) return;
    this.state = moveItem(this.state, fromIdx, toIdx);
  }

  submit(): void {
    if (!this.ctx || this.state.finished) return;
    this.state = evaluate(this.state, this.steps);
    const score = finalScore(this.state);
    const t = this.getLevelData().starThresholds;
    const stars = score >= t[2] ? 3 : score >= t[1] ? 2 : score >= t[0] ? 1 : 0;
    this.ctx.onComplete({ modeId: this.id, levelId: this.getLevelData().levelId, score, stars, durationMs: 0, stats: { correctCount: this.state.correctCount, total: this.state.total } });
  }

  getState(): SortFlowState { return this.state; }
  destroy(): void { this.state = createState([], false); this.steps = []; this.ctx = null; }
}
