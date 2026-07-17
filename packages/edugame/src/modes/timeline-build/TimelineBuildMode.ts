import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';

export interface TimelineBuildData {
  [key: string]: unknown;
}

export class TimelineBuildMode extends GameMode<TimelineBuildData> {
  readonly id = 'timeline-build' as const;
  readonly displayName = '时间线拼装';
  readonly objective = '拖拽事件到时间轴';
  readonly howToPlay = ['时间线拼装玩法即将上线'];

  init(ctx: GameContext): void {
    this.ctx = ctx;
  }

  destroy(): void {
    this.ctx = null;
  }
}
