/**
 * signal-surfer · 纯逻辑层
 *
 * 波形冲浪：玩家调整频率匹配目标波形，按节拍冲浪避障。
 * 核心机制：频率匹配度 → 分数；障碍物命中 → 扣血。
 */

export type Waveform = 'sine' | 'square' | 'triangle';

export interface Obstacle {
  /** 出现时间（秒） */
  atSec: number;
  /** 需要的频率范围 [min, max] Hz 才能避开 */
  safeFreqMin: number;
  safeFreqMax: number;
}

export interface SignalSurferState {
  /** 玩家当前频率 Hz */
  playerFreq: number;
  /** 目标频率 Hz */
  targetFreq: number;
  /** 当前时间（秒） */
  elapsed: number;
  /** 血量 0..100 */
  hp: number;
  /** 累计匹配分 */
  matchScore: number;
  /** 连续完美匹配帧数 */
  perfectStreak: number;
  /** 最大连续完美 */
  maxPerfectStreak: number;
  /** 已处理的障碍索引 */
  processedObstacles: number;
  /** 是否结束 */
  finished: boolean;
}

export function createInitialState(targetFreq: number): SignalSurferState {
  return {
    playerFreq: targetFreq,
    targetFreq,
    elapsed: 0,
    hp: 100,
    matchScore: 0,
    perfectStreak: 0,
    maxPerfectStreak: 0,
    processedObstacles: 0,
    finished: false,
  };
}

/** 频率匹配度：0..1，误差 ≤ 5% 算完美 */
export function freqMatchRatio(player: number, target: number): number {
  if (target === 0) return player === 0 ? 1 : 0;
  const error = Math.abs(player - target) / target;
  if (error <= 0.05) return 1;
  if (error >= 0.5) return 0;
  return 1 - (error - 0.05) / 0.45;
}

/**
 * 每帧 tick：更新时间、检查障碍、累计匹配分。
 * @param dt 毫秒
 */
export function tick(
  state: SignalSurferState,
  obstacles: ReadonlyArray<Obstacle>,
  dt: number,
): SignalSurferState {
  if (state.finished) return state;

  const elapsed = state.elapsed + dt / 1000;
  let { hp, matchScore, perfectStreak, maxPerfectStreak, processedObstacles } = state;

  // 检查新到达的障碍
  while (processedObstacles < obstacles.length) {
    const obs = obstacles[processedObstacles]!;
    if (obs.atSec > elapsed) break;
    // 判定：玩家频率是否在安全范围
    if (state.playerFreq < obs.safeFreqMin || state.playerFreq > obs.safeFreqMax) {
      hp = Math.max(0, hp - 15);
      perfectStreak = 0;
    }
    processedObstacles++;
  }

  // 频率匹配累计
  const match = freqMatchRatio(state.playerFreq, state.targetFreq);
  matchScore += match * (dt / 1000) * 10; // 每秒满匹配 +10 分
  if (match >= 1) {
    perfectStreak++;
    if (perfectStreak > maxPerfectStreak) maxPerfectStreak = perfectStreak;
  } else {
    perfectStreak = 0;
  }

  const finished = hp <= 0;

  return {
    ...state,
    elapsed,
    hp,
    matchScore,
    perfectStreak,
    maxPerfectStreak,
    processedObstacles,
    finished,
  };
}

/** 玩家调频 */
export function adjustFreq(state: SignalSurferState, delta: number): SignalSurferState {
  return { ...state, playerFreq: Math.max(0, state.playerFreq + delta) };
}

/** 最终评分 0..100 */
export function computeFinalScore(state: SignalSurferState, timeLimit: number): number {
  if (timeLimit <= 0) return Math.min(100, Math.round(state.matchScore));
  // 归一化：满分 = timeLimit * 10（每秒 10 分）
  const maxPossible = timeLimit * 10;
  const raw = (state.matchScore / maxPossible) * 80 + (state.hp / 100) * 20;
  return Math.min(100, Math.round(raw));
}
