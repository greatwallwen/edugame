/**
 * interrupt-defender · 纯逻辑层
 *
 * 中断防御战：CPU 城堡被 IRQ 怪物攻击，玩家设置 NVIC 优先级守城。
 * 核心机制：高优先级抢占低优先级；调度正确 → 怪物被处理；错配 → 扣 HP。
 */

export interface IrqWave {
  /** IRQ 标签（如 "EXTI0" / "TIM2"） */
  tag: string;
  /** 优先级 0..15（0 最高） */
  priority: number;
  /** 出现时间（秒） */
  atSec: number;
  /** 处理耗时（秒） */
  handleDuration: number;
}

export interface InterruptDefenderState {
  /** 玩家为各 IRQ 设置的优先级 */
  config: Map<string, number>;
  /** 城堡 HP */
  hp: number;
  /** 已处理的 IRQ 数 */
  handled: number;
  /** 未处理（错配）的 IRQ 数 */
  missed: number;
  /** 当前时间（秒） */
  elapsed: number;
  /** 当前正在处理的 IRQ（优先级最高的） */
  activeIrq: string | null;
  /** 活跃 IRQ 剩余处理时间 */
  activeRemaining: number;
  /** 等待队列 */
  pending: IrqWave[];
  /** 已处理的波次索引 */
  processedWaves: number;
  finished: boolean;
}

export function createInitialState(hp: number): InterruptDefenderState {
  return {
    config: new Map(),
    hp,
    handled: 0,
    missed: 0,
    elapsed: 0,
    activeIrq: null,
    activeRemaining: 0,
    pending: [],
    processedWaves: 0,
    finished: false,
  };
}

/** 玩家设置某 IRQ 的优先级 */
export function setIrqPriority(
  state: InterruptDefenderState,
  tag: string,
  priority: number,
): InterruptDefenderState {
  const config = new Map(state.config);
  config.set(tag, Math.max(0, Math.min(15, priority)));
  return { ...state, config };
}

/**
 * 每帧 tick：推进时间、入队新 IRQ、按优先级调度。
 */
export function tick(
  state: InterruptDefenderState,
  waves: ReadonlyArray<IrqWave>,
  dt: number,
): InterruptDefenderState {
  if (state.finished) return state;

  const elapsed = state.elapsed + dt / 1000;
  let { hp, handled, missed, activeIrq, activeRemaining, pending, processedWaves } = state;
  pending = [...pending];

  // 入队新到达的 IRQ
  while (processedWaves < waves.length) {
    const w = waves[processedWaves]!;
    if (w.atSec > elapsed) break;
    pending.push(w);
    processedWaves++;
  }

  // 处理当前活跃 IRQ
  if (activeIrq) {
    activeRemaining -= dt / 1000;
    if (activeRemaining <= 0) {
      handled++;
      activeIrq = null;
      activeRemaining = 0;
    }
  }

  // 从 pending 中选优先级最高的（数值最小）
  if (!activeIrq && pending.length > 0) {
    pending.sort((a, b) => {
      const pa = state.config.get(a.tag) ?? a.priority;
      const pb = state.config.get(b.tag) ?? b.priority;
      return pa - pb;
    });
    const next = pending.shift()!;
    const configPri = state.config.get(next.tag);
    // 如果玩家没配置该 IRQ 的优先级 → 错配，扣 HP
    if (configPri === undefined) {
      hp = Math.max(0, hp - 10);
      missed++;
    } else {
      activeIrq = next.tag;
      activeRemaining = next.handleDuration;
    }
  }

  // 抢占检查：pending 中有比 active 更高优先级的
  if (activeIrq && pending.length > 0) {
    const activePri = state.config.get(activeIrq) ?? 15;
    const highestPending = pending.reduce((best, w) => {
      const p = state.config.get(w.tag) ?? w.priority;
      return p < best.pri ? { tag: w.tag, pri: p, wave: w } : best;
    }, { tag: '', pri: 16, wave: null as IrqWave | null });
    if (highestPending.wave && highestPending.pri < activePri) {
      // 抢占：当前 IRQ 回到 pending，新 IRQ 接管
      const currentWave = waves.find(w => w.tag === activeIrq);
      if (currentWave) {
        pending.push({ ...currentWave, handleDuration: activeRemaining });
      }
      pending = pending.filter(w => w !== highestPending.wave);
      activeIrq = highestPending.wave.tag;
      activeRemaining = highestPending.wave.handleDuration;
    }
  }

  const finished = hp <= 0;

  return {
    ...state,
    elapsed, hp, handled, missed, activeIrq, activeRemaining,
    pending, processedWaves, finished,
  };
}

/** 最终评分 0..100 */
export function computeFinalScore(state: InterruptDefenderState, totalWaves: number): number {
  if (totalWaves === 0) return 100;
  const survivalBonus = (state.hp / 100) * 40;
  const handleBonus = (state.handled / totalWaves) * 60;
  return Math.min(100, Math.round(survivalBonus + handleBonus));
}
