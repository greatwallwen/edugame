import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';

export interface RepairSimData {
  [key: string]: unknown;
}

export class RepairSimMode extends GameMode<RepairSimData> {
  readonly id = 'repair-sim' as const;
  readonly displayName = '故障维修模拟';
  readonly objective = '诊断+修复流程';
  readonly howToPlay = ['故障维修模拟玩法即将上线'];

  init(ctx: GameContext): void {
    this.ctx = ctx;
  }

  destroy(): void {
    this.ctx = null;
  }
}
