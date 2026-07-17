/**
 * ActionEngine — DGBook 版 OpenMAIC ActionEngine 移植（Iter-36 T-4.1）
 *
 * 单一职责：执行**一条** PageAction，区分 fire-and-forget vs synchronous。
 *
 * 与 OpenMAIC `lib/action/engine.ts` 的对照：
 *   - speak / spotlight / laser / reveal / wait / pause-for-discussion 6 case
 *   - fire-and-forget（spotlight / laser）→ 同步 setState 后立即 return
 *   - synchronous（speak / reveal / wait / pause-for-discussion）→ 返回 Promise
 *
 * 与 BlockPlaybackEngine 的边界：
 *   - BlockPlaybackEngine 是"block 顺播"模式（与 stepScripts 联动）
 *   - ActionEngine 只负责"执行单一 action"，cursor 推进由 PageActionRunner（T-4.2）控制
 *   - 两者**共用同一个 TTSAdapter 实例**，避免 TTS 状态分裂
 *
 * 设计文档：docs/iter36-openmaic-action-cursor.md §6 落地映射
 *
 * 不做的事（明确边界）：
 *   - 不维护 cursor / actionIndex（那是 PageActionRunner 的职责）
 *   - 不做 pause/resume 状态机（PageActionRunner 通过外部 dispose + 重建 ActionEngine 实现）
 *   - 不做 onSpeechStart 回调（PageActionRunner 在 dispatch 时调）
 */

import type { PageAction } from '@dgbook/types';

/** spotlight / laser 显示时长上限（ms）
 * 加长到 30 秒：spotlight 应持续到下一个 spotlight 到来时被替换，
 * auto-clear 只是防止 cursor 异常卡死时 effect 永远残留的兜底。
 * TTS 播报一段话通常 8-15 秒，5 秒 auto-clear 会在播报中途消失。
 */
const EFFECT_AUTO_CLEAR_MS = 30_000;

/**
 * ActionEngine 依赖的最小 TTS 接口（鸭子类型）。
 *
 * 这层抽象的作用：
 *   - 单元测试时可以注入一个 mock（避免真的拉 Qwen API / Web Speech）
 *   - 主代码路径仍传入 TTSAdapter 实例（结构兼容自动满足）
 *
 * 与 OpenMAIC AudioPlayer 的接口对齐：speak / stop 是必需的最小集。
 */
export interface ActionEngineTTSDeps {
  speak(text: string, onDone: () => void, onError?: (e: Error) => void): void;
  stop(): void;
}

/**
 * Effect 通道事件 —— 与 OpenMAIC `Effect` 类型对齐（去掉了 OpenMAIC 的 percentage 几何，
 * DGBook 元素查找走 data-element-id 协议，不需要传递坐标）。
 */
export type EffectFire =
  | { kind: 'spotlight'; targetId: string; dimOpacity?: number }
  | { kind: 'laser'; targetId: string; color?: string }
  | { kind: 'reveal'; targetId: string; mode?: 'fade' | 'slide' | 'draw'; durationMs?: number };

/** ActionEngine 与外部 UI 通道的协作回调（订阅式） */
export interface ActionEngineCallbacks {
  /** speak action 触发：把文本抛给字幕通道（PageActionRunner 在 dispatch 阶段调用） */
  onSpeechStart?: (text: string) => void;
  /** speak 结束（TTS onEnded 触发） */
  onSpeechEnd?: () => void;
  /** spotlight / laser / reveal action 触发：把 effect 抛给 overlay 通道 */
  onEffectFire?: (effect: EffectFire) => void;
  /** spotlight / laser auto-clear 或 reveal 动画完成后触发 */
  onEffectClear?: (kind: 'spotlight' | 'laser' | 'reveal') => void;
  /** pause-for-discussion action 触发：让外部进入 live 模式（AI 助教对话） */
  onEnterLive?: (topic: string, prompt?: string) => void;
}

/**
 * ActionEngine
 *
 * 用法：
 *   const engine = new ActionEngine(tts, { onSpeechStart, onEffectFire, ... });
 *   await engine.execute(action);   // sync 类等 Promise 解开；fire-and-forget 类立即 resolve
 *   engine.dispose();               // 清理 effect timer + stop TTS
 */
export class ActionEngine {
  private tts: ActionEngineTTSDeps;
  private callbacks: ActionEngineCallbacks;
  /** spotlight/laser auto-clear 定时器 */
  private effectTimer: ReturnType<typeof setTimeout> | null = null;
  /** 当前活跃的 effect 类型（auto-clear 时回调用） */
  private activeEffectKind: 'spotlight' | 'laser' | null = null;
  private disposed = false;

  /**
   * @param tts 任何符合 ActionEngineTTSDeps 接口的对象（TTSAdapter 实例或 test mock）
   * @param callbacks 4 通道协作回调（onSpeechStart 抛字幕 / onEffectFire 抛 overlay / 等）
   */
  constructor(tts: ActionEngineTTSDeps, callbacks: ActionEngineCallbacks = {}) {
    this.tts = tts;
    this.callbacks = callbacks;
  }

  /**
   * 执行一条 action。
   * - fire-and-forget（spotlight/laser）：同步 setState 后立即 resolve
   * - synchronous（speak/reveal/wait/pause-for-discussion）：等真的完成才 resolve
   *
   * 注意：fire-and-forget 仍然返回 Promise（保持调用方一致），但 Promise 同帧 resolve。
   */
  async execute(action: PageAction): Promise<void> {
    if (this.disposed) return;

    switch (action.type) {
      // ───── fire-and-forget ────────────────────────────────────────
      case 'spotlight':
        return this.executeSpotlight(action);
      case 'laser':
        return this.executeLaser(action);

      // ───── synchronous ───────────────────────────────────────────
      case 'speak':
        return this.executeSpeak(action);
      case 'reveal':
        return this.executeReveal(action);
      case 'wait':
        return this.executeWait(action);
      case 'pause-for-discussion':
        return this.executePauseForDiscussion(action);
    }
  }

  /**
   * 主动清除当前 effect（用于切场景 / 切 page / cursor 离开等）
   * 与 OpenMAIC ActionEngine.clearEffects() 等价。
   */
  clearEffects(): void {
    if (this.effectTimer) {
      clearTimeout(this.effectTimer);
      this.effectTimer = null;
    }
    if (this.activeEffectKind) {
      const kind = this.activeEffectKind;
      this.activeEffectKind = null;
      this.callbacks.onEffectClear?.(kind);
    }
  }


  stopCurrent(): void {
    if (this.disposed) return;
    this.tts.stop();
    this.clearEffects();
  }

  /** 释放：停 TTS、清 timer */
  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;
    this.clearEffects();
    this.tts.stop();
  }

  // ═════════════════════ private executors ═══════════════════════

  /** spotlight：fire-and-forget · 通知 overlay 通道、注册 auto-clear 定时器 */
  private executeSpotlight(action: Extract<PageAction, { type: 'spotlight' }>): void {
    this.callbacks.onEffectFire?.({
      kind: 'spotlight',
      targetId: action.targetId,
      dimOpacity: action.dimOpacity,
    });
    this.scheduleAutoClear('spotlight');
  }

  /** laser：fire-and-forget · 同 spotlight，参数不同 */
  private executeLaser(action: Extract<PageAction, { type: 'laser' }>): void {
    this.callbacks.onEffectFire?.({
      kind: 'laser',
      targetId: action.targetId,
      color: action.color,
    });
    this.scheduleAutoClear('laser');
  }

  /**
   * speak：synchronous · TTS 朗读完才 resolve。
   * onSpeechStart 回调在朗读启动前抛出（让字幕同步出现）；
   * onSpeechEnd 回调在 TTS onDone / onError 后触发。
   */
  private executeSpeak(action: Extract<PageAction, { type: 'speak' }>): Promise<void> {
    return new Promise<void>((resolve) => {
      this.callbacks.onSpeechStart?.(action.text);
      this.tts.speak(
        action.text,
        () => {
          this.callbacks.onSpeechEnd?.();
          resolve();
        },
        () => {
          // TTS error：仍触发 onSpeechEnd 防止 cursor 卡死
          this.callbacks.onSpeechEnd?.();
          resolve();
        },
      );
    });
  }

  /**
   * reveal：synchronous · 入场动画 · 抛 onEffectFire 后等 durationMs 才 resolve。
   * 与 spotlight/laser 的差异：reveal 是"出现"动画，cursor 等动画完才前进。
   */
  private executeReveal(action: Extract<PageAction, { type: 'reveal' }>): Promise<void> {
    const duration = action.durationMs ?? 400;
    this.callbacks.onEffectFire?.({
      kind: 'reveal',
      targetId: action.targetId,
      mode: action.mode,
      durationMs: duration,
    });
    return new Promise<void>((resolve) => {
      setTimeout(() => {
        this.callbacks.onEffectClear?.('reveal');
        resolve();
      }, duration);
    });
  }

  /** wait：synchronous · 单纯 setTimeout · 用于讲解节奏停顿 */
  private executeWait(action: Extract<PageAction, { type: 'wait' }>): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(resolve, action.ms);
    });
  }

  /**
   * pause-for-discussion：synchronous · 抛 onEnterLive 让外部进入 live 模式。
   * 注意：这里 Promise 永远不 resolve——cursor 必须由外部（PageActionRunner.handleEndDiscussion）
   * 显式调用恢复。这与 OpenMAIC PlaybackEngine.confirmDiscussion / handleEndDiscussion 行为一致。
   */
  private executePauseForDiscussion(
    action: Extract<PageAction, { type: 'pause-for-discussion' }>,
  ): Promise<void> {
    this.callbacks.onEnterLive?.(action.topic, action.prompt);
    return new Promise<void>(() => {
      /* 永不 resolve：cursor 由外部 handleEndDiscussion 重启 */
    });
  }

  /** 调度 spotlight/laser 的 auto-clear · 防止 cursor 卡住时 effect 永远残留 */
  private scheduleAutoClear(kind: 'spotlight' | 'laser'): void {
    if (this.effectTimer) clearTimeout(this.effectTimer);
    this.activeEffectKind = kind;
    this.effectTimer = setTimeout(() => {
      this.effectTimer = null;
      this.activeEffectKind = null;
      this.callbacks.onEffectClear?.(kind);
    }, EFFECT_AUTO_CLEAR_MS);
  }
}
