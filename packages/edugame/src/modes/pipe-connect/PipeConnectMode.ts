import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';

export interface PipeConnectData {
  [key: string]: unknown;
}

export class PipeConnectMode extends GameMode<PipeConnectData> {
  readonly id = 'pipe-connect' as const;
  readonly displayName = '管线连接';
  readonly objective = '连通管路/电路';
  readonly howToPlay = ['管线连接玩法即将上线'];

  init(ctx: GameContext): void {
    this.ctx = ctx;
  }

  destroy(): void {
    this.ctx = null;
  }
}
