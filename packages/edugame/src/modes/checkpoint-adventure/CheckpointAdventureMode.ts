import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';

export interface CheckpointAdventureData {
  [key: string]: unknown;
}

export class CheckpointAdventureMode extends GameMode<CheckpointAdventureData> {
  readonly id = 'checkpoint-adventure' as const;
  readonly displayName = '关卡冒险';
  readonly objective = '多关卡线性闯关';
  readonly howToPlay = ['关卡冒险玩法即将上线'];

  init(ctx: GameContext): void {
    this.ctx = ctx;
  }

  destroy(): void {
    this.ctx = null;
  }
}
