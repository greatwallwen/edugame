import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';

export interface MazeTroubleshootData {
  [key: string]: unknown;
}

export class MazeTroubleshootMode extends GameMode<MazeTroubleshootData> {
  readonly id = 'maze-troubleshoot' as const;
  readonly displayName = '迷宫排障';
  readonly objective = '走迷宫+排除故障';
  readonly howToPlay = ['迷宫排障玩法即将上线'];

  init(ctx: GameContext): void {
    this.ctx = ctx;
  }

  destroy(): void {
    this.ctx = null;
  }
}
