/**
 * pin-rush · 纯逻辑层
 *
 * 引脚连线竞速：给定 peripheral → pin 配对题，玩家在限时内拖线连接。
 * 正确 +分 + combo；错误 -分 + 断 combo。时间衰减：越后越快。
 */

export interface PinPair {
  peripheral: string;
  pin: string;
}

export interface PinRushState {
  /** 当前题目索引 */
  currentIdx: number;
  /** 总题数 */
  total: number;
  /** 已答对 */
  correct: number;
  /** 已答错 */
  wrong: number;
  /** 当前连击 */
  combo: number;
  /** 最大连击 */
  maxCombo: number;
  /** 累计分数 */
  score: number;
  /** 是否已结束 */
  finished: boolean;
}

const BASE_SCORE = 10;
const COMBO_BONUS = 2;

export function createInitialState(pairs: ReadonlyArray<PinPair>): PinRushState {
  return {
    currentIdx: 0,
    total: pairs.length,
    correct: 0,
    wrong: 0,
    combo: 0,
    maxCombo: 0,
    score: 0,
    finished: false,
  };
}

/**
 * 玩家提交一次连线答案。
 * @returns 新 state + 本次是否正确
 */
export function submitAnswer(
  state: PinRushState,
  pairs: ReadonlyArray<PinPair>,
  selectedPin: string,
): { state: PinRushState; correct: boolean } {
  if (state.finished || state.currentIdx >= pairs.length) {
    return { state: { ...state, finished: true }, correct: false };
  }

  const expected = pairs[state.currentIdx]!;
  const isCorrect = selectedPin === expected.pin;

  let { score, combo, maxCombo, correct, wrong } = state;

  if (isCorrect) {
    combo += 1;
    if (combo > maxCombo) maxCombo = combo;
    correct += 1;
    score += BASE_SCORE + combo * COMBO_BONUS;
  } else {
    wrong += 1;
    combo = 0;
    score = Math.max(0, score - 5);
  }

  const nextIdx = state.currentIdx + 1;
  const finished = nextIdx >= pairs.length;

  return {
    state: { ...state, currentIdx: nextIdx, correct, wrong, combo, maxCombo, score, finished },
    correct: isCorrect,
  };
}

/**
 * 最终评分：score 归一化到 0..100。
 * 满分 = 全对 + 全连击时的理论最高分。
 */
export function computeFinalScore(state: PinRushState): number {
  if (state.total === 0) return 0;
  // 理论满分：每题 BASE_SCORE + combo * COMBO_BONUS（combo 从 1 递增到 total）
  let maxPossible = 0;
  for (let i = 1; i <= state.total; i++) {
    maxPossible += BASE_SCORE + i * COMBO_BONUS;
  }
  return Math.min(100, Math.round((state.score / maxPossible) * 100));
}
