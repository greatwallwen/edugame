import { GameMode } from '../../core/GameMode';
import type { GameContext } from '../../core/types';
import type { GodotCompleteMessage, GodotGameData } from './protocol';
import { normalizeGodotResult } from './protocol';

export class GodotGameMode extends GameMode<GodotGameData> {
  readonly id = 'godot-game' as const;
  readonly displayName = 'Godot 实训小游戏';
  readonly objective = '在 Godot Web 互动场景中完成实训任务';
  readonly howToPlay = [
    '等待 Godot 场景加载完成',
    '按关卡目标操作场景中的设备或参数',
    '完成后由小游戏回传进度、得分和星级',
  ];

  private finished = false;

  init(ctx: GameContext): void {
    this.ctx = ctx;
    this.finished = false;
    this.ctx.onProgress(0, 'Godot 场景加载中');
  }

  reportReady(): void {
    if (!this.ctx || this.finished) return;
    this.ctx.onProgress(0, '场景已就绪');
  }

  reportProgress(progress: number, hint?: string): void {
    if (!this.ctx || this.finished) return;
    const ratio = Math.max(0, Math.min(1, progress));
    this.ctx.onProgress(ratio, hint);
  }

  completeFromGodot(message: GodotCompleteMessage): void {
    if (!this.ctx || this.finished) return;
    this.finished = true;
    this.ctx.onComplete(normalizeGodotResult(this.getLevelData(), message));
  }

  destroy(): void {
    this.finished = false;
    this.ctx = null;
  }
}
