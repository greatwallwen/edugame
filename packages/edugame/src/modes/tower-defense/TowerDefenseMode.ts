import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';

export interface TowerDefenseData {
  [key: string]: unknown;
}

export class TowerDefenseMode extends GameMode<TowerDefenseData> {
  readonly id = 'tower-defense' as const;
  readonly displayName = '知识塔防';
  readonly objective = '用知识点建塔防御';
  readonly howToPlay = ['知识塔防玩法即将上线'];

  init(ctx: GameContext): void {
    this.ctx = ctx;
  }

  destroy(): void {
    this.ctx = null;
  }
}
