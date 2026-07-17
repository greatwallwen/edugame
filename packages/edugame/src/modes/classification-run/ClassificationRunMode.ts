import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';

export interface ClassificationRunData {
  [key: string]: unknown;
}

export class ClassificationRunMode extends GameMode<ClassificationRunData> {
  readonly id = 'classification-run' as const;
  readonly displayName = '分类跑酷';
  readonly objective = '跑酷中收集正确分类';
  readonly howToPlay = ['分类跑酷玩法即将上线'];

  init(ctx: GameContext): void {
    this.ctx = ctx;
  }

  destroy(): void {
    this.ctx = null;
  }
}
