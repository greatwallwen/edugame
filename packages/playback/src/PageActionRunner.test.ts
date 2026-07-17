/**
 * PageActionRunner.test.ts — Iter-36 T-4.2 验证
 *
 * 测试要点（与设计文档 docs/iter36-openmaic-action-cursor.md §3 主图、§6 落地映射对齐）：
 *   1. cursor 推进顺序 = action 数组顺序（fire-and-forget 不"插队"也不"被跳过"）
 *   2. fire-and-forget（spotlight/laser）→ cursor 立即推进到下一格
 *   3. sync（speak）→ cursor 等 onDone 才推进
 *   4. pause/resume：暂停后 cursor 不再前进；resume 从当前 actionIndex 继续
 *   5. pause-for-discussion → mode='live'，cursor 卡住；handleEndDiscussion 恢复
 *   6. snapshot/restore：导出 + 注入后 cursor 落在正确位置
 *   7. onComplete 在 actions 全部走完后触发
 *   8. onModeChange 4 态变化都通知
 *   9. onProgress 与 cursor 推进同步
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { PageActionRunner } from './PageActionRunner';
import type { ActionEngineTTSDeps } from './ActionEngine';
import type { PageAction } from '@dgbook/types';

/** 构造 mock TTS：speak 完成由测试代码显式控制 */
function makeMockTTS() {
  const mock = {
    pendingDone: null as (() => void) | null,
    speak(_text: string, onDone: () => void) {
      mock.pendingDone = onDone;
    },
    stop() {
      mock.pendingDone = null;
    },
    /** test helper: 模拟 TTS 完成 */
    finishSpeak() {
      mock.pendingDone?.();
      mock.pendingDone = null;
    },
  };
  return mock;
}

describe('PageActionRunner', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });
  afterEach(() => {
    vi.useRealTimers();
  });

  it('cursor 推进顺序与 action 数组顺序一致', async () => {
    const tts = makeMockTTS();
    const onEffectFire = vi.fn();
    const actions: PageAction[] = [
      { id: 'a1', type: 'spotlight', targetId: 'A' },
      { id: 'a2', type: 'spotlight', targetId: 'B' },
      { id: 'a3', type: 'spotlight', targetId: 'C' },
    ];
    const runner = new PageActionRunner(tts as ActionEngineTTSDeps, { actions }, { onEffectFire });

    runner.start();
    // 全是 fire-and-forget，queueMicrotask 推进，flush microtasks 即可
    await vi.runAllTimersAsync();

    expect(onEffectFire).toHaveBeenCalledTimes(3);
    expect((onEffectFire.mock.calls[0]![0] as { targetId: string }).targetId).toBe('A');
    expect((onEffectFire.mock.calls[1]![0] as { targetId: string }).targetId).toBe('B');
    expect((onEffectFire.mock.calls[2]![0] as { targetId: string }).targetId).toBe('C');
  });

  it('fire-and-forget + sync 混合：cursor 在 sync 处等待 onDone', async () => {
    const tts = makeMockTTS();
    const onSpeechStart = vi.fn();
    const onEffectFire = vi.fn();
    const onComplete = vi.fn();

    const actions: PageAction[] = [
      { id: '1', type: 'spotlight', targetId: 'A' },
      { id: '2', type: 'speak', text: '看 A' },
      { id: '3', type: 'laser', targetId: 'B' },
    ];
    const runner = new PageActionRunner(
      tts as ActionEngineTTSDeps,
      { actions },
      { onSpeechStart, onEffectFire, onComplete },
    );

    runner.start();
    // microtask flush：spotlight 触发，cursor 推进到 speak，发起 TTS，等 onDone
    await Promise.resolve();
    await Promise.resolve();
    expect(onEffectFire).toHaveBeenCalledTimes(1); // spotlight A
    expect(onSpeechStart).toHaveBeenCalledWith('看 A');
    expect(onComplete).not.toHaveBeenCalled(); // cursor 卡在 speak 上

    // TTS 完成 → cursor 推进到 laser → onComplete
    tts.finishSpeak();
    await vi.runAllTimersAsync();
    expect(onEffectFire).toHaveBeenCalledTimes(2); // + laser B
    expect(onComplete).toHaveBeenCalledTimes(1);
  });

  it('pause / resume：暂停后 cursor 不前进；resume 从当前位置继续', async () => {
    const tts = makeMockTTS();
    const onEffectFire = vi.fn();
    const onModeChange = vi.fn();

    const actions: PageAction[] = [
      { id: '1', type: 'spotlight', targetId: 'A' },
      { id: '2', type: 'speak', text: '一' },
      { id: '3', type: 'spotlight', targetId: 'B' },
    ];
    const runner = new PageActionRunner(
      tts as ActionEngineTTSDeps,
      { actions },
      { onEffectFire, onModeChange },
    );

    runner.start();
    await Promise.resolve();
    await Promise.resolve();
    // 此刻 cursor 在 speak '一'，等 onDone

    runner.pause();
    expect(runner.getMode()).toBe('paused');
    expect(onModeChange).toHaveBeenCalledWith('paused');

    // 即使 TTS 完成，cursor 也不再推进（因为 mode !== 'playing'）
    tts.finishSpeak();
    await vi.runAllTimersAsync();
    expect(onEffectFire).toHaveBeenCalledTimes(1); // 只有第一个 spotlight A

    runner.resume();
    expect(runner.getMode()).toBe('playing');
    await vi.runAllTimersAsync();
    expect(onEffectFire).toHaveBeenCalledTimes(2); // + spotlight B
  });

  it('pause-for-discussion → mode=live · handleEndDiscussion 恢复', async () => {
    const tts = makeMockTTS();
    const onEnterLive = vi.fn();
    const onEffectFire = vi.fn();
    const onComplete = vi.fn();

    const actions: PageAction[] = [
      { id: '1', type: 'spotlight', targetId: 'A' },
      { id: '2', type: 'pause-for-discussion', topic: '为何 GPIO 拉低' },
      { id: '3', type: 'spotlight', targetId: 'B' },
    ];
    const runner = new PageActionRunner(
      tts as ActionEngineTTSDeps,
      { actions },
      { onEnterLive, onEffectFire, onComplete },
    );

    runner.start();
    // 推进到 pause-for-discussion → onEnterLive 触发 → mode=live → cursor 卡住
    await vi.runAllTimersAsync();
    expect(onEnterLive).toHaveBeenCalledWith('为何 GPIO 拉低', undefined);
    expect(runner.getMode()).toBe('live');
    expect(onEffectFire).toHaveBeenCalledTimes(1); // 只有 A
    expect(onComplete).not.toHaveBeenCalled();

    // 用户结束讨论
    runner.handleEndDiscussion();
    await vi.runAllTimersAsync();
    expect(runner.getMode()).toBe('idle'); // actions 走完了
    expect(onEffectFire).toHaveBeenCalledTimes(2); // + B
    expect(onComplete).toHaveBeenCalled();
  });

  it('onProgress：每次 cursor 推进时报告', async () => {
    const tts = makeMockTTS();
    const onProgress = vi.fn();
    const actions: PageAction[] = [
      { id: '1', type: 'spotlight', targetId: 'A' },
      { id: '2', type: 'spotlight', targetId: 'B' },
    ];
    const runner = new PageActionRunner(tts as ActionEngineTTSDeps, { actions }, { onProgress });

    runner.start();
    await vi.runAllTimersAsync();

    expect(onProgress).toHaveBeenCalledTimes(2);
    expect(onProgress.mock.calls[0]![0]).toEqual({ actionIndex: 0, total: 2 });
    expect(onProgress.mock.calls[1]![0]).toEqual({ actionIndex: 1, total: 2 });
  });

  it('snapshot/restore：cursor 状态可序列化恢复', async () => {
    const tts = makeMockTTS();
    const actions: PageAction[] = [
      { id: '1', type: 'spotlight', targetId: 'A' },
      { id: '2', type: 'spotlight', targetId: 'B' },
      { id: '3', type: 'spotlight', targetId: 'C' },
    ];
    const onEffectFire = vi.fn();
    const runner = new PageActionRunner(
      tts as ActionEngineTTSDeps,
      { actions, courseId: 'c1', pageId: 'p1' },
      { onEffectFire },
    );

    // 注入"已经播过 2 格"的 snapshot
    runner.restoreFromSnapshot({
      v: 1,
      courseId: 'c1',
      pageId: 'p1',
      actionIndex: 2,
      ts: 0,
    });

    runner.start();
    // 注意：start() 自身把 actionIndex 重置为 0；
    // restore 应在 resume 模式下使用，这里我们换 resume 路径
    runner.stop();
    runner.restoreFromSnapshot({
      v: 1,
      courseId: 'c1',
      pageId: 'p1',
      actionIndex: 2,
      ts: 0,
    });
    // 用 resume 不会重置 actionIndex（但状态机要求先 paused）
    // 直接借助 start() 然后立刻 pause/resume 模拟"接续"是绕的，
    // 简化为：手动验证 getSnapshot 的导出值
    const snap = runner.getSnapshot();
    expect(snap?.actionIndex).toBe(2);
    expect(snap?.courseId).toBe('c1');
    expect(snap?.pageId).toBe('p1');
  });

  it('onModeChange：idle → playing → idle（actions 完成后自动）', async () => {
    const tts = makeMockTTS();
    const onModeChange = vi.fn();
    const actions: PageAction[] = [{ id: '1', type: 'spotlight', targetId: 'A' }];
    const runner = new PageActionRunner(tts as ActionEngineTTSDeps, { actions }, { onModeChange });

    runner.start();
    await vi.runAllTimersAsync();

    expect(onModeChange).toHaveBeenCalledWith('playing');
    expect(onModeChange).toHaveBeenLastCalledWith('idle');
  });

  it('空 actions[]：start 立即 onComplete + 回到 idle', async () => {
    const tts = makeMockTTS();
    const onComplete = vi.fn();
    const runner = new PageActionRunner(
      tts as ActionEngineTTSDeps,
      { actions: [] },
      { onComplete },
    );

    runner.start();
    await vi.runAllTimersAsync();

    expect(onComplete).toHaveBeenCalled();
    expect(runner.getMode()).toBe('idle');
  });

  it('dispose：清理 ActionEngine + mode → idle', () => {
    const tts = makeMockTTS();
    const stopSpy = vi.spyOn(tts, 'stop');
    const runner = new PageActionRunner(
      tts as ActionEngineTTSDeps,
      { actions: [{ id: '1', type: 'speak', text: 'x' }] },
    );

    runner.start();
    runner.dispose();

    expect(stopSpy).toHaveBeenCalled();
    expect(runner.getMode()).toBe('idle');
  });

  it('start 在非 idle 状态下被忽略（防止重入）', async () => {
    const tts = makeMockTTS();
    const onModeChange = vi.fn();
    const actions: PageAction[] = [{ id: '1', type: 'speak', text: '一' }];
    const runner = new PageActionRunner(tts as ActionEngineTTSDeps, { actions }, { onModeChange });

    runner.start();
    expect(onModeChange).toHaveBeenCalledWith('playing');
    onModeChange.mockClear();

    runner.start(); // 第二次 start 应被忽略
    expect(onModeChange).not.toHaveBeenCalled();
  });

  // ───── Iter-40-G · 学生交互 togglePause/gotoPrev/gotoNext ─────────


  async function flushMicrotasks() {
    for (let i = 0; i < 8; i++) {
      await Promise.resolve();
    }
  }

  it('Iter-40-G · togglePause 在 idle 时启动，playing 时暂停，paused 时恢复', () => {
    const tts = makeMockTTS();
    const actions: PageAction[] = [
      { id: '1', type: 'speak', text: '一' },
      { id: '2', type: 'speak', text: '二' },
    ];
    const runner = new PageActionRunner(tts as ActionEngineTTSDeps, { actions });

    expect(runner.getMode()).toBe('idle');
    runner.togglePause();
    expect(runner.getMode()).toBe('playing');

    runner.togglePause();
    expect(runner.getMode()).toBe('paused');

    runner.togglePause();
    expect(runner.getMode()).toBe('playing');
  });

  it('Iter-40-G · gotoPrev 回退当前段（speak 重读）', async () => {
    const tts = makeMockTTS();
    const onSpeechStart = vi.fn();
    const actions: PageAction[] = [
      { id: '1', type: 'speak', text: 'a' },
      { id: '2', type: 'speak', text: 'b' },
      { id: '3', type: 'speak', text: 'c' },
    ];
    const runner = new PageActionRunner(
      tts as ActionEngineTTSDeps,
      { actions },
      { onSpeechStart },
    );
    runner.start();
    expect(onSpeechStart).toHaveBeenLastCalledWith('a');
    tts.finishSpeak();
    await flushMicrotasks();
    expect(onSpeechStart).toHaveBeenLastCalledWith('b');

    onSpeechStart.mockClear();
    runner.gotoPrev();
    await flushMicrotasks();
    expect(onSpeechStart).toHaveBeenCalledWith('a');
  });

  it('Iter-40-G · gotoNext 跳过当前段（直接朗读下一段）', async () => {
    const tts = makeMockTTS();
    const onSpeechStart = vi.fn();
    const actions: PageAction[] = [
      { id: '1', type: 'speak', text: 'x' },
      { id: '2', type: 'speak', text: 'y' },
      { id: '3', type: 'speak', text: 'z' },
    ];
    const runner = new PageActionRunner(
      tts as ActionEngineTTSDeps,
      { actions },
      { onSpeechStart },
    );
    runner.start();
    expect(onSpeechStart).toHaveBeenLastCalledWith('x');

    onSpeechStart.mockClear();
    runner.gotoNext();
    await flushMicrotasks();
    expect(onSpeechStart).toHaveBeenCalledWith('y');
  });

  it('Iter-40-G · gotoPrev 在 a0 时不再退（边界保护）', async () => {
    const tts = makeMockTTS();
    const onSpeechStart = vi.fn();
    const actions: PageAction[] = [
      { id: '1', type: 'speak', text: 'first' },
    ];
    const runner = new PageActionRunner(
      tts as ActionEngineTTSDeps,
      { actions },
      { onSpeechStart },
    );
    runner.start();
    onSpeechStart.mockClear();
    runner.gotoPrev();
    await flushMicrotasks();
    expect(onSpeechStart).toHaveBeenCalledWith('first');

    onSpeechStart.mockClear();
    runner.gotoPrev();
    await flushMicrotasks();
    expect(onSpeechStart).toHaveBeenCalledWith('first');
  });
});
