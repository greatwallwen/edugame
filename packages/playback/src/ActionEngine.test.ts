/**
 * ActionEngine.test.ts — Iter-36 T-4.1 验证
 *
 * 测试要点（与设计文档 docs/iter36-openmaic-action-cursor.md 对齐）：
 *   1. fire-and-forget（spotlight/laser）→ Promise 在同帧 resolve（不阻塞 cursor）
 *   2. synchronous（speak）→ Promise 等 TTS onDone 才 resolve
 *   3. wait → Promise 等 setTimeout 才 resolve
 *   4. reveal → 抛 onEffectFire 后等 durationMs 才 resolve
 *   5. pause-for-discussion → 抛 onEnterLive，Promise 永不 resolve
 *   6. 4 通道回调正确触发（onSpeechStart / onEffectFire / onEnterLive）
 *   7. dispose() 后 execute 不再触发任何回调
 *   8. clearEffects() 清掉 spotlight/laser auto-clear 定时器
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ActionEngine, type ActionEngineTTSDeps } from './ActionEngine';
import type { PageAction } from '@dgbook/types';

/** 构造 mock TTSAdapter：可控制 speak 是同步完成还是异步完成 */
function makeMockTTS(): ActionEngineTTSDeps & { lastSpeakText: string | null; pendingDone: (() => void) | null } {
  const mock = {
    lastSpeakText: null as string | null,
    pendingDone: null as (() => void) | null,
    speak(text: string, onDone: () => void) {
      mock.lastSpeakText = text;
      mock.pendingDone = onDone;
    },
    stop() {
      mock.pendingDone = null;
    },
  };
  return mock;
}

describe('ActionEngine', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });
  afterEach(() => {
    vi.useRealTimers();
  });

  it('spotlight: fire-and-forget · 同帧 resolve · 触发 onEffectFire', async () => {
    const tts = makeMockTTS();
    const onEffectFire = vi.fn();
    const engine = new ActionEngine(tts, { onEffectFire });

    const action: PageAction = {
      id: 'a1',
      type: 'spotlight',
      targetId: 'gpioA',
      dimOpacity: 0.6,
    };
    await engine.execute(action);

    expect(onEffectFire).toHaveBeenCalledWith({
      kind: 'spotlight',
      targetId: 'gpioA',
      dimOpacity: 0.6,
    });
  });

  it('laser: fire-and-forget · 同帧 resolve · 触发 onEffectFire 带 color', async () => {
    const tts = makeMockTTS();
    const onEffectFire = vi.fn();
    const engine = new ActionEngine(tts, { onEffectFire });

    await engine.execute({ id: 'l1', type: 'laser', targetId: 'pin5', color: '#00ff00' });

    expect(onEffectFire).toHaveBeenCalledWith({
      kind: 'laser',
      targetId: 'pin5',
      color: '#00ff00',
    });
  });

  it('speak: 等 TTS onDone 才 resolve · 触发 onSpeechStart + onSpeechEnd', async () => {
    const tts = makeMockTTS();
    const onSpeechStart = vi.fn();
    const onSpeechEnd = vi.fn();
    const engine = new ActionEngine(tts, { onSpeechStart, onSpeechEnd });

    const promise = engine.execute({ id: 's1', type: 'speak', text: '你好世界' });

    // 第一时间 onSpeechStart 应该已被调用，TTS speak 已被发起
    expect(onSpeechStart).toHaveBeenCalledWith('你好世界');
    expect(tts.lastSpeakText).toBe('你好世界');
    expect(onSpeechEnd).not.toHaveBeenCalled();

    // 模拟 TTS 完成
    tts.pendingDone!();
    await promise;

    expect(onSpeechEnd).toHaveBeenCalled();
  });

  it('wait: 等 setTimeout 才 resolve（用 fake timers 验证）', async () => {
    const tts = makeMockTTS();
    const engine = new ActionEngine(tts);

    let resolved = false;
    const promise = engine.execute({ id: 'w1', type: 'wait', ms: 1000 }).then(() => {
      resolved = true;
    });

    // 还没到时间
    await vi.advanceTimersByTimeAsync(500);
    expect(resolved).toBe(false);

    // 到时间
    await vi.advanceTimersByTimeAsync(500);
    await promise;
    expect(resolved).toBe(true);
  });

  it('reveal: 抛 onEffectFire(reveal) 后等 durationMs 才 resolve', async () => {
    const tts = makeMockTTS();
    const onEffectFire = vi.fn();
    const onEffectClear = vi.fn();
    const engine = new ActionEngine(tts, { onEffectFire, onEffectClear });

    let resolved = false;
    const promise = engine
      .execute({ id: 'r1', type: 'reveal', targetId: 'box1', mode: 'fade', durationMs: 400 })
      .then(() => {
        resolved = true;
      });

    expect(onEffectFire).toHaveBeenCalledWith({
      kind: 'reveal',
      targetId: 'box1',
      mode: 'fade',
      durationMs: 400,
    });
    expect(resolved).toBe(false);

    await vi.advanceTimersByTimeAsync(400);
    await promise;
    expect(resolved).toBe(true);
    expect(onEffectClear).toHaveBeenCalledWith('reveal');
  });

  it('pause-for-discussion: 触发 onEnterLive · Promise 永不 resolve', async () => {
    const tts = makeMockTTS();
    const onEnterLive = vi.fn();
    const engine = new ActionEngine(tts, { onEnterLive });

    let resolved = false;
    void engine
      .execute({
        id: 'd1',
        type: 'pause-for-discussion',
        topic: '为什么 GPIO 要拉低',
        prompt: 'discussion prompt',
      })
      .then(() => {
        resolved = true;
      });

    expect(onEnterLive).toHaveBeenCalledWith('为什么 GPIO 要拉低', 'discussion prompt');

    // 等 30s（远超任何理论 timeout），Promise 不应 resolve
    await vi.advanceTimersByTimeAsync(30_000);
    expect(resolved).toBe(false);
  });

  it('clearEffects: 清掉 spotlight 的 auto-clear 定时器并触发 onEffectClear', async () => {
    const tts = makeMockTTS();
    const onEffectClear = vi.fn();
    const engine = new ActionEngine(tts, { onEffectClear });

    await engine.execute({ id: 'a', type: 'spotlight', targetId: 'x' });
    expect(onEffectClear).not.toHaveBeenCalled();

    engine.clearEffects();
    expect(onEffectClear).toHaveBeenCalledWith('spotlight');
  });

  it('dispose: 后续 execute 不再触发任何回调 · stop TTS', async () => {
    const tts = makeMockTTS();
    const stopSpy = vi.spyOn(tts, 'stop');
    const onEffectFire = vi.fn();
    const onSpeechStart = vi.fn();
    const engine = new ActionEngine(tts, { onEffectFire, onSpeechStart });

    engine.dispose();
    expect(stopSpy).toHaveBeenCalled();

    await engine.execute({ id: 'a', type: 'spotlight', targetId: 'x' });
    await engine.execute({ id: 's', type: 'speak', text: 'hi' });

    expect(onEffectFire).not.toHaveBeenCalled();
    expect(onSpeechStart).not.toHaveBeenCalled();
  });

  it('speak: TTS error 也触发 onSpeechEnd 防止 cursor 卡死', async () => {
    // 改造 mock 让 speak 直接调 onError
    const tts: ActionEngineTTSDeps = {
      speak(_text, _onDone, onError) {
        onError?.(new Error('mock TTS error'));
      },
      stop() {},
    };
    const onSpeechEnd = vi.fn();
    const engine = new ActionEngine(tts, { onSpeechEnd });

    await engine.execute({ id: 's', type: 'speak', text: 'fail-me' });
    expect(onSpeechEnd).toHaveBeenCalled();
  });

  it('AUTO_CLEAR_MS 后自动 onEffectClear（spotlight 显示上限保护）', async () => {
    const tts = makeMockTTS();
    const onEffectClear = vi.fn();
    const engine = new ActionEngine(tts, { onEffectClear });

    await engine.execute({ id: 'a', type: 'spotlight', targetId: 'x' });
    expect(onEffectClear).not.toHaveBeenCalled();

    // 30s 后自动 clear（与 ActionEngine.ts EFFECT_AUTO_CLEAR_MS 对应）
    await vi.advanceTimersByTimeAsync(30_000);
    expect(onEffectClear).toHaveBeenCalledWith('spotlight');
  });
});
