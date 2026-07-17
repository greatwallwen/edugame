import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';

export interface Merge2048Data {
  [key: string]: unknown;
}

export class Merge2048Mode extends GameMode<Merge2048Data> {
  readonly id = '2048-merge' as const;
  readonly displayName = '知识合成';
  readonly objective = '合并同类知识升级';
  readonly howToPlay = ['知识合成玩法即将上线'];

  init(ctx: GameContext): void {
    this.ctx = ctx;
  }

  destroy(): void {
    this.ctx = null;
  }
}
