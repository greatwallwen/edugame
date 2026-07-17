import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';

export interface LabProcedureData {
  [key: string]: unknown;
}

export class LabProcedureMode extends GameMode<LabProcedureData> {
  readonly id = 'lab-procedure' as const;
  readonly displayName = '实验流程闯关';
  readonly objective = '按步骤完成实验';
  readonly howToPlay = ['实验流程闯关玩法即将上线'];

  init(ctx: GameContext): void {
    this.ctx = ctx;
  }

  destroy(): void {
    this.ctx = null;
  }
}
