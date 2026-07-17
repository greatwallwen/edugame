/**
 * @dgbook/game · GameMode 抽象基类
 *
 * 所有内置游戏模式（bit-flip-quest / pin-rush / signal-surfer / ...）
 * 都继承本类。本基类不依赖 PixiJS：渲染由子类按需 import，
 * 让"纯逻辑单测"可以脱离 WebGL 跑（jsdom 友好）。
 */
import type { GameContext, ModeId, LevelData } from './types';

export abstract class GameMode<TPayload = unknown> {
  abstract readonly id: ModeId;
  abstract readonly displayName: string;
  /** 一句话教学目标（在通关页展示） */
  abstract readonly objective: string;
  /** "怎么玩"列表（≤ 5 行短句） */
  abstract readonly howToPlay: string[];

  protected ctx: GameContext | null = null;

  /** 容器初始化（外部 host 已构建 PIXI.Application 等资源后调用） */
  abstract init(ctx: GameContext): void | Promise<void>;

  /** 每帧更新（dt 单位：毫秒），子类按需重写 */
  update(_dt: number): void {}

  /** 暂停 / 恢复钩子；不持仿真定时器的 mode 可不实现 */
  pause(): void {}
  resume(): void {}

  /** 关闭释放（unmount） */
  abstract destroy(): void;

  /** 子类工具：取本局关卡数据（已 narrow 到 TPayload） */
  protected getLevelData(): LevelData<TPayload> {
    if (!this.ctx) throw new Error('[GameMode] init() not called yet');
    return this.ctx.level as LevelData<TPayload>;
  }
}
