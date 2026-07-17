/**
 * circuit-builder · 电路拼装
 *
 * 完整逻辑层：放置元件 + 连线 + 通电验证。
 */
import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';
import {
  createInitialState, placeComponent, addWire, undoWire, powerOn, computeFinalScore,
  type CircuitBuilderState, type ComponentSlot, type WireConnection,
} from './logic';

export interface CircuitBuilderData {
  drawer: ReadonlyArray<string>;
  targetBehavior: string;
  /** 目标放置位置 */
  targetSlots: ReadonlyArray<ComponentSlot>;
  /** 目标连线 */
  targetWires: ReadonlyArray<WireConnection>;
}

export class CircuitBuilderMode extends GameMode<CircuitBuilderData> {
  readonly id = 'circuit-builder' as const;
  readonly displayName = '电路拼装';
  readonly objective = '原理图 → 实物电路 / 上拉下拉 / 限流电阻';
  readonly howToPlay = [
    '左侧元件抽屉拖到面包板',
    '连线后按"通电"按钮',
    '与目标行为对比',
  ];

  private state: CircuitBuilderState = createInitialState();

  init(ctx: GameContext): void {
    this.ctx = ctx;
    this.state = createInitialState();
  }

  place(componentId: string, pos: [number, number]): void {
    this.state = placeComponent(this.state, componentId, pos);
    this.reportProgress();
  }

  wire(from: string, to: string): void {
    this.state = addWire(this.state, { from, to });
    this.reportProgress();
  }

  undoLastWire(): void {
    this.state = undoWire(this.state);
    this.reportProgress();
  }

  /** 通电验证 + 自动 complete */
  powerOn(): void {
    if (!this.ctx) return;
    const data = this.getLevelData().data;
    this.state = powerOn(this.state, data.targetSlots, data.targetWires);
    const score = computeFinalScore(this.state, data.targetSlots, data.targetWires);
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
        correctPlacements: this.state.correctPlacements,
        correctWires: this.state.correctWires,
        powered: this.state.powered ? 1 : 0,
      },
    });
  }

  getState(): CircuitBuilderState { return this.state; }

  destroy(): void {
    this.state = createInitialState();
    this.ctx = null;
  }

  private reportProgress(): void {
    if (!this.ctx) return;
    const data = this.getLevelData().data;
    const total = data.targetSlots.length + data.targetWires.length;
    const done = this.state.placed.size + this.state.wires.length;
    this.ctx.onProgress(Math.min(1, done / Math.max(1, total)));
  }
}
