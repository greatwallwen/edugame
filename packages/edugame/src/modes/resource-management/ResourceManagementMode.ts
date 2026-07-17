import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';

export interface ResourceManagementData {
  [key: string]: unknown;
}

export class ResourceManagementMode extends GameMode<ResourceManagementData> {
  readonly id = 'resource-management' as const;
  readonly displayName = '资源调度';
  readonly objective = '分配有限资源达成目标';
  readonly howToPlay = ['资源调度玩法即将上线'];

  init(ctx: GameContext): void {
    this.ctx = ctx;
  }

  destroy(): void {
    this.ctx = null;
  }
}
