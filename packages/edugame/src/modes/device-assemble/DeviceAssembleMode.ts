import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';

export interface DeviceAssembleData {
  [key: string]: unknown;
}

export class DeviceAssembleMode extends GameMode<DeviceAssembleData> {
  readonly id = 'device-assemble' as const;
  readonly displayName = '设备拼装';
  readonly objective = '拖拽组装设备';
  readonly howToPlay = ['设备拼装玩法即将上线'];

  init(ctx: GameContext): void {
    this.ctx = ctx;
  }

  destroy(): void {
    this.ctx = null;
  }
}
