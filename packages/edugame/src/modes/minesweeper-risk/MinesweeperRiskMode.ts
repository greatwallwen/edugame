import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';

export interface MinesweeperRiskData {
  [key: string]: unknown;
}

export class MinesweeperRiskMode extends GameMode<MinesweeperRiskData> {
  readonly id = 'minesweeper-risk' as const;
  readonly displayName = '风险扫雷';
  readonly objective = '扫雷式风险识别';
  readonly howToPlay = ['风险扫雷玩法即将上线'];

  init(ctx: GameContext): void {
    this.ctx = ctx;
  }

  destroy(): void {
    this.ctx = null;
  }
}
