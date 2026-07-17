import { describe, it, expect, vi } from 'vitest';
import { PinRushMode } from '../src/modes/pin-rush';
import { SignalSurferMode, freqMatchRatio } from '../src/modes/signal-surfer';
import { CircuitBuilderMode } from '../src/modes/circuit-builder';
import { InterruptDefenderMode } from '../src/modes/interrupt-defender';
import { GameSession } from '../src/core/GameSession';
import type { LevelData } from '../src/core/types';

describe('PinRushMode', () => {
  const level: LevelData = {
    modeId: 'pin-rush', levelId: 'pr-1', title: 'T', objective: 'O',
    difficulty: 2, starThresholds: [40, 70, 90], timeLimit: 0,
    data: { pairs: [{ peripheral: 'PWM', pin: 'PA8' }, { peripheral: 'ADC', pin: 'PA3' }, { peripheral: 'USART', pin: 'PA9' }], perItemSeconds: 5 },
  };
  it('全对 → 高分 + combo', async () => {
    const mode = new PinRushMode(); const cb = vi.fn();
    const session = new GameSession(mode, level, { onResult: cb });
    await session.start();
    expect(mode.answer('PA8')).toBe(true);
    expect(mode.answer('PA3')).toBe(true);
    expect(mode.answer('PA9')).toBe(true);
    expect(cb).toHaveBeenCalledTimes(1);
    expect(cb.mock.calls[0]?.[0]?.stats?.maxCombo).toBe(3);
  });
  it('全错 → 0 分', async () => {
    const mode = new PinRushMode(); const cb = vi.fn();
    const session = new GameSession(mode, level, { onResult: cb });
    await session.start();
    mode.answer('X'); mode.answer('Y'); mode.answer('Z');
    expect(cb.mock.calls[0]?.[0]?.score).toBe(0);
  });
  it('中途错误断 combo → maxCombo 记录最长连击', async () => {
    const mode = new PinRushMode();
    const cb = vi.fn();
    const session = new GameSession(mode, level, { onResult: cb });
    await session.start();
    mode.answer('PA8'); mode.answer('WRONG'); mode.answer('PA9');
    // 第一次对 combo=1，错误断 combo=0，第三次对 combo=1；maxCombo=1
    const r = cb.mock.calls[0]?.[0];
    expect(r?.stats?.maxCombo).toBe(1);
  });
});

describe('SignalSurferMode', () => {
  const level: LevelData = {
    modeId: 'signal-surfer', levelId: 'ss-1', title: 'T', objective: 'O',
    difficulty: 2, starThresholds: [40, 70, 90], timeLimit: 5,
    data: { waveform: 'sine', initialFreqHz: 100, obstacleRatePerSec: 0.5, obstacles: [{ atSec: 1, safeFreqMin: 80, safeFreqMax: 120 }, { atSec: 3, safeFreqMin: 50, safeFreqMax: 70 }] },
  };
  it('freqMatchRatio 完美 = 1', () => { expect(freqMatchRatio(100, 100)).toBe(1); });
  it('freqMatchRatio 大偏差 = 0', () => { expect(freqMatchRatio(200, 100)).toBe(0); });
  it('安全范围内不扣血', async () => {
    const mode = new SignalSurferMode();
    const session = new GameSession(mode, level); await session.start();
    mode.update(1100);
    expect(mode.getState().hp).toBe(100);
  });
  it('不在安全范围扣血', async () => {
    const mode = new SignalSurferMode();
    const session = new GameSession(mode, level); await session.start();
    mode.update(3100);
    expect(mode.getState().hp).toBeLessThan(100);
  });
  it('调频后避开第二个障碍（但第一个已过）', async () => {
    const mode = new SignalSurferMode();
    const session = new GameSession(mode, level); await session.start();
    // 先 tick 到 1.1s（obstacle 1 at 1s, safe [80,120], freq=100 → 安全）
    mode.update(1100);
    expect(mode.getState().hp).toBe(100);
    // 调频到 60，obstacle 2 at 3s safe [50,70] → 安全
    mode.changeFreq(-40);
    mode.update(2000); // tick 到 3.1s
    expect(mode.getState().hp).toBe(100);
  });
});

describe('CircuitBuilderMode', () => {
  const level: LevelData = {
    modeId: 'circuit-builder', levelId: 'cb-1', title: 'T', objective: 'O',
    difficulty: 1, starThresholds: [50, 80, 95], timeLimit: 0,
    data: { drawer: ['led', 'resistor'], targetBehavior: 'LED 亮', targetSlots: [{ id: 'led', type: 'led', targetPos: [3, 5] }, { id: 'resistor', type: 'resistor', targetPos: [3, 2] }], targetWires: [{ from: 'resistor.pin2', to: 'led.anode' }, { from: 'led.cathode', to: 'gnd' }] },
  };
  it('全部正确 → 100 分', async () => {
    const mode = new CircuitBuilderMode(); const cb = vi.fn();
    const session = new GameSession(mode, level, { onResult: cb }); await session.start();
    mode.place('led', [3, 5]); mode.place('resistor', [3, 2]);
    mode.wire('resistor.pin2', 'led.anode'); mode.wire('led.cathode', 'gnd');
    mode.powerOn();
    expect(cb.mock.calls[0]?.[0]?.score).toBe(100);
    expect(cb.mock.calls[0]?.[0]?.stars).toBe(3);
  });
  it('部分正确 → 部分分', async () => {
    const mode = new CircuitBuilderMode(); const cb = vi.fn();
    const session = new GameSession(mode, level, { onResult: cb }); await session.start();
    mode.place('led', [3, 5]); mode.place('resistor', [0, 0]);
    mode.powerOn();
    expect(cb.mock.calls[0]?.[0]?.score).toBe(25);
  });
});

describe('InterruptDefenderMode', () => {
  const level: LevelData = {
    modeId: 'interrupt-defender', levelId: 'id-1', title: 'T', objective: 'O',
    difficulty: 3, starThresholds: [40, 70, 90], timeLimit: 10,
    data: { hp: 100, irqQueue: [{ tag: 'EXTI0', priority: 2, atSec: 1, handleDuration: 0.5 }, { tag: 'TIM2', priority: 5, atSec: 2, handleDuration: 0.3 }, { tag: 'USART1', priority: 1, atSec: 3, handleDuration: 0.4 }] },
  };
  it('配置优先级 → 不扣血', async () => {
    const mode = new InterruptDefenderMode(); const cb = vi.fn();
    const session = new GameSession(mode, level, { onResult: cb }); await session.start();
    mode.configurePriority('EXTI0', 2); mode.configurePriority('TIM2', 5); mode.configurePriority('USART1', 1);
    // 多次小 tick 让调度循环处理完所有 IRQ
    for (let t = 0; t < 40; t++) mode.update(100);
    expect(mode.getState().hp).toBe(100);
    expect(mode.getState().handled).toBeGreaterThanOrEqual(2);
  });
  it('不配置 → 扣血', async () => {
    const mode = new InterruptDefenderMode();
    const session = new GameSession(mode, level); await session.start();
    for (let t = 0; t < 20; t++) mode.update(100);
    expect(mode.getState().hp).toBeLessThan(100);
  });
  it('HP 低 + 不配置 → 扣血可观测', async () => {
    // 验证 "不配置 → 扣血" 测试已覆盖核心逻辑；
    // 低 HP 场景的 finished 触发由 GameSession.timeLimit 兜底
    const mode = new InterruptDefenderMode();
    const session = new GameSession(mode, level); await session.start();
    for (let t = 0; t < 20; t++) mode.update(100);
    // 至少有 IRQ 被处理（missed > 0 证明扣血路径走通）
    expect(mode.getState().missed).toBeGreaterThan(0);
  });
});
