/**
 * PageActionRunner — DGBook 版 OpenMAIC PlaybackEngine 移植（Iter-36 T-4.2）
 *
 * 核心定位：
 *   把 page.actions[] 当作有序 action 流，用单一 cursor（actionIndex）推进。
 *   ActionEngine 是"执行单条 action"的工人，PageActionRunner 是"决定下一条何时执行"的指挥。
 *
 * 与 OpenMAIC PlaybackEngine 的对照：
 *   - sceneIndex / actionIndex → 简化为单一 actionIndex（DGBook 只在 page 内驱动）
 *   - mode 4 态：idle / playing / paused / live （等价）
 *   - processNext() → run() 循环 + 单条 dispatch
 *   - snapshot / restore → 同形态
 *
 * 与 BlockPlaybackEngine 的边界：
 *   - BlockPlaybackEngine 模式：page 没有 actions[] 字段时走老路径（block 顺播）
 *   - PageActionRunner 模式：page.actions 非空时由本类接管
 *   - 两者**不能同时跑**（外部 Shell 选一个）
 *
 * 设计文档：docs/iter36-openmaic-action-cursor.md §6 落地映射 + §3 主 SVG 图
 */

import type { PageAction } from '@dgbook/types';
import type { EngineMode, PlaybackSnapshot } from '@dgbook/types';
import { ActionEngine, type ActionEngineCallbacks, type ActionEngineTTSDeps } from './ActionEngine';

/** PageActionRunner 与外部协作的回调接口 */
export interface PageActionRunnerCallbacks extends ActionEngineCallbacks {
  /** 4 态状态机变化 */
  onModeChange?: (mode: EngineMode) => void;
  /** cursor 推进 / snapshot 更新（用于持久化进度） */
  onProgress?: (snapshot: { actionIndex: number; total: number }) => void;
  /** 全部 action 执行完毕 */
  onComplete?: () => void;
}

export interface PageActionRunnerOptions {
  /** page.actions 数组 */
  actions: ReadonlyArray<PageAction>;
  /** 课程 + page 标识（用于 snapshot key，可选） */
  courseId?: string;
  pageId?: string;
}

/**
 * PageActionRunner
 *
 * 状态机（与 OpenMAIC PlaybackEngine 同构）：
 *
 *                  start()                  pause()
 *   idle ──────────────────→ playing ──────────────→ paused
 *     ▲                         ▲                       │
 *     │                         │  resume()             │
 *     │                         └───────────────────────┘
 *     │
 *     │  handleEndDiscussion()
 *     │                              pause-for-discussion action
 *     │                                            │
 *     │                                            ▼
 *     └──────────────────────────────────────── live
 */
export class PageActionRunner {
  private actions: ReadonlyArray<PageAction>;
  private actionIndex = 0;
  private mode: EngineMode = 'idle';

  private actionEngine: ActionEngine;
  private callbacks: PageActionRunnerCallbacks;

  /** 进入 live 模式时保存的 cursor，恢复时回到这里 */
  private savedActionIndex: number | null = null;

  /** courseId / pageId（用于 snapshot 关联） */
  private readonly courseId?: string;
  private readonly pageId?: string;

  constructor(
    tts: ActionEngineTTSDeps,
    options: PageActionRunnerOptions,
    callbacks: PageActionRunnerCallbacks = {},
  ) {
    this.actions = options.actions;
    this.courseId = options.courseId;
    this.pageId = options.pageId;
    this.callbacks = callbacks;

    // ActionEngine 与本类共用同一组 callback（onSpeechStart/onEffectFire/...）
    // pause-for-discussion 走 onEnterLive 走 ActionEngine → 我们包一层让它能切 mode
    const wrappedCallbacks: ActionEngineCallbacks = {
      ...callbacks,
      onEnterLive: (topic, prompt) => {
        this.savedActionIndex = this.actionIndex;
        this.setMode('live');
        callbacks.onEnterLive?.(topic, prompt);
      },
    };
    this.actionEngine = new ActionEngine(tts, wrappedCallbacks);
  }

  // ═════════════════════ Public API ═══════════════════════════════

  getMode(): EngineMode {
    return this.mode;
  }

  /** idle → playing：从 actions[0] 开始 */
  start(): void {
    if (this.mode !== 'idle') return;
    this.actionIndex = 0;
    this.setMode('playing');
    void this.processNext();
  }

  /** playing → paused：当前 action 执行完后 cursor 不再前进 */
  pause(): void {
    if (this.mode === 'playing') {
      this.setMode('paused');
      // 注意：当前正在执行的 sync action（如 speak）会继续完成；
      // 完成后 processNext 检查 mode !== 'playing' 则 return，不再推进
    }
  }

  /** paused → playing：从当前 actionIndex 继续 */
  resume(): void {
    if (this.mode === 'paused') {
      this.setMode('playing');
      void this.processNext();
    }
  }

  /** live → playing：用户结束 AI 助教讨论，从保存的 cursor 继续 */
  handleEndDiscussion(): void {
    if (this.mode !== 'live') return;
    if (this.savedActionIndex !== null) {
      // pause-for-discussion 是 sync action，cursor 在 dispatch 时已经++过；
      // 恢复时直接从下一格开始（即 savedActionIndex 已经是"下一格"）
      this.actionIndex = this.savedActionIndex;
      this.savedActionIndex = null;
    }
    this.setMode('playing');
    void this.processNext();
  }

  /** 整体停止：mode → idle，cursor 复位，actionEngine 清理 */
  stop(): void {
    this.setMode('idle');
    this.actionIndex = 0;
    this.savedActionIndex = null;
    this.actionEngine.clearEffects();
  }


  gotoPrev(): void {
    if (this.mode !== 'playing' && this.mode !== 'paused') return;
    this.actionEngine.stopCurrent();
    // 减 2 退到"上一段之前"，processNext 再 advance 1 后 execute 上一段
    this.actionIndex = Math.max(0, this.actionIndex - 2);
    if (this.mode === 'paused') this.setMode('playing');
    void this.processNext();
  }

  gotoNext(): void {
    if (this.mode !== 'playing' && this.mode !== 'paused') return;
    this.actionEngine.stopCurrent();
    // actionIndex 已经指向"下一个还没执行的"，processNext 直接 advance + execute
    if (this.mode === 'paused') this.setMode('playing');
    void this.processNext();
  }

  /** Iter-40-G · 暂停 / 继续切换（学生 Space 键交互） */
  togglePause(): void {
    if (this.mode === 'playing') this.pause();
    else if (this.mode === 'paused') this.resume();
    else if (this.mode === 'idle') this.start();
  }

  /**
   * 块级导航底座 · 把 cursor 跳到指定 action 下标并从那里开始播报。
   *
   * 用途：Shell 的「上一个 / 下一个内容块」把"目标 block 的首个 action 下标"传进来，
   *   runner 从该 action 开始连续播报（讲解 + 动画 step + 视频联动随之触发）。
   *
   * 语义：seekTo(i) 后，下一条执行的就是 actions[i]（processNext 会先 advance 再 execute，
   *   所以这里把 actionIndex 设为 i——与 gotoNext 的 cursor 约定一致：actionIndex 指向"还没执行的"）。
   *
   * 边界：
   *   - i 夹在 [0, length]；i===length 表示"跳到结尾"（下次 processNext 触发 onComplete）。
   *   - idle 时 seekTo 也会自动切到 playing 并开播（块级导航点哪播哪，无需先按播放）。
   */
  seekTo(index: number): void {
    const clamped = Math.max(0, Math.min(index, this.actions.length));
    this.actionEngine.stopCurrent();
    this.actionIndex = clamped;
    if (this.mode === 'live') {
      // live 模式下不直接跳（避免与讨论态打架）；先回 playing
      this.savedActionIndex = null;
    }
    this.setMode('playing');
    void this.processNext();
  }

  /** 当前 cursor 指向的 action 下标（指向"还没执行的"，即正在播的是 actionIndex-1）。 */
  getActionIndex(): number {
    return this.actionIndex;
  }

  /** 释放资源（dispose actionEngine + 重置） */
  dispose(): void {
    this.actionEngine.dispose();
    this.setMode('idle');
  }

  /** 导出当前 cursor 进度（用于 localStorage 持久化） */
  getSnapshot(): PlaybackSnapshot | null {
    if (!this.courseId || !this.pageId) return null;
    return {
      v: 1,
      courseId: this.courseId,
      pageId: this.pageId,
      actionIndex: this.actionIndex,
      ts: Date.now(),
    };
  }

  /** 从 snapshot 恢复 cursor（注意：不会自动 start，外部需调 start/resume） */
  restoreFromSnapshot(snapshot: PlaybackSnapshot): void {
    if (
      snapshot.courseId !== this.courseId ||
      snapshot.pageId !== this.pageId ||
      typeof snapshot.actionIndex !== 'number'
    ) {
      return;
    }
    // 限制在 actions 范围内
    this.actionIndex = Math.max(0, Math.min(snapshot.actionIndex, this.actions.length));
  }

  // ═════════════════════ Core loop ═══════════════════════════════

  /**
   * 核心 cursor 推进函数（对标 OpenMAIC PlaybackEngine.processNext）
   *
   * 关键设计（与 OpenMAIC 一致）：
   *   1. mode !== 'playing' 直接 return（暂停 / live / idle 时不推进）
   *   2. cursor 越界检查 → mode = idle + onComplete
   *   3. **先 onProgress 通知，再 actionIndex++**（snapshot 指向"还没执行的"，恢复时重播）
   *   4. fire-and-forget action：execute 立即 resolve，紧跟 processNext
   *   5. sync action：await execute → 检查 mode 仍是 playing → processNext
   */
  private async processNext(): Promise<void> {
    if (this.mode !== 'playing') return;

    // 越界 → 完成
    if (this.actionIndex >= this.actions.length) {
      this.actionEngine.clearEffects();
      this.setMode('idle');
      this.callbacks.onComplete?.();
      return;
    }

    const action = this.actions[this.actionIndex];
    // noUncheckedIndexedAccess 下 action 推断为 PageAction | undefined，但
    // 我们刚做了 actionIndex < this.actions.length 守卫，逻辑上一定有值。
    // 双重保险：加一道运行时判定（防御性 + 让 TS 收窄类型）。
    if (!action) {
      this.setMode('idle');
      this.callbacks.onComplete?.();
      return;
    }

    // 先 onProgress 报当前 cursor（snapshot 指向"还没执行的"，恢复语义见 OpenMAIC 注释）
    this.callbacks.onProgress?.({
      actionIndex: this.actionIndex,
      total: this.actions.length,
    });

    // ★★★ THE CURSOR ADVANCE ★★★（与 OpenMAIC 第 33 行对应）
    this.actionIndex++;

    try {
      await this.actionEngine.execute(action);
    } catch (err) {
      // 单条 action 异常不应让整个 cursor 卡死
      // 已有 console.error 是可接受的（生产侧 player 不抛错给用户）
      console.error('[PageActionRunner] action failed, advancing:', err);
    }

    // pause-for-discussion 的 Promise 永不 resolve，所以走到这里时 mode 已是 'live'
    // 上面 await 会一直 hang，下一行不会执行——这是预期行为
    // （由 handleEndDiscussion 显式恢复 cursor）

    if (this.mode === 'playing') {
      // 用 queueMicrotask 而非直接调，避免大量 fire-and-forget 时同步递归爆栈
      // （与 OpenMAIC `queueMicrotask(() => this.processNext())` 一致）
      queueMicrotask(() => void this.processNext());
    }
  }

  private setMode(mode: EngineMode): void {
    if (this.mode === mode) return;
    this.mode = mode;
    this.callbacks.onModeChange?.(mode);
  }
}
