import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';

export interface RhythmTapData {
  [key: string]: unknown;
}

export class RhythmTapMode extends GameMode<RhythmTapData> {
  readonly id = 'rhythm-tap' as const;
  readonly displayName = '节奏反应';
  readonly objective = '按节拍点击正确项';
  readonly howToPlay = ['节奏反应玩法即将上线'];

  init(ctx: GameContext): void {
    this.ctx = ctx;
  }

  destroy(): void {
    this.ctx = null;
  }
}
