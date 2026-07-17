/**
 * boss-review · Boss 复习战 · 纯逻辑层
 *
 * 多轮答题打 Boss，每答对一题 Boss 扣血，答错自己扣血。
 * 复用 quick-hit 的 question 结构。
 */
import type { QuickHitQuestion } from '../quick-hit/logic';

export type BossQuestion = QuickHitQuestion;

export interface BossReviewState {
  bossHp: number;
  bossMaxHp: number;
  playerHp: number;
  playerMaxHp: number;
  currentIdx: number;
  total: number;
  correct: number;
  wrong: number;
  combo: number;
  maxCombo: number;
  finished: boolean;
  result: 'win' | 'lose' | 'draw' | null;
}

const BOSS_DAMAGE_BASE = 15;
const COMBO_EXTRA = 5;
const PLAYER_DAMAGE = 10;

export function createState(
  bossHp: number,
  playerHp: number,
  questions: ReadonlyArray<BossQuestion>,
): BossReviewState {
  return {
    bossHp,
    bossMaxHp: bossHp,
    playerHp,
    playerMaxHp: playerHp,
    currentIdx: 0,
    total: questions.length,
    correct: 0,
    wrong: 0,
    combo: 0,
    maxCombo: 0,
    finished: false,
    result: null,
  };
}

export function answer(
  state: BossReviewState,
  questions: ReadonlyArray<BossQuestion>,
  selectedIdx: number,
): { state: BossReviewState; correct: boolean } {
  if (state.finished || state.currentIdx >= questions.length) {
    return { state: { ...state, finished: true, result: state.result ?? 'draw' }, correct: false };
  }
  const q = questions[state.currentIdx]!;
  const isCorrect = selectedIdx === q.correctIndex;

  let { bossHp, playerHp, correct, wrong, combo, maxCombo } = state;

  if (isCorrect) {
    correct++;
    combo++;
    if (combo > maxCombo) maxCombo = combo;
    bossHp = Math.max(0, bossHp - (BOSS_DAMAGE_BASE + combo * COMBO_EXTRA));
  } else {
    wrong++;
    combo = 0;
    playerHp = Math.max(0, playerHp - PLAYER_DAMAGE);
  }

  const nextIdx = state.currentIdx + 1;
  let result: BossReviewState['result'] = null;
  let finished = false;

  if (bossHp <= 0) {
    result = 'win';
    finished = true;
  } else if (playerHp <= 0) {
    result = 'lose';
    finished = true;
  } else if (nextIdx >= questions.length) {
    result = playerHp > bossHp ? 'win' : playerHp < bossHp ? 'lose' : 'draw';
    finished = true;
  }

  return {
    state: {
      ...state,
      bossHp,
      playerHp,
      currentIdx: nextIdx,
      correct,
      wrong,
      combo,
      maxCombo,
      finished,
      result,
    },
    correct: isCorrect,
  };
}

export function finalScore(state: BossReviewState): number {
  if (state.result === 'win') {
    const hpRatio = state.playerHp / state.playerMaxHp;
    return Math.round(60 + hpRatio * 40);
  }
  if (state.result === 'draw') return 50;
  // 输了根据对 Boss 造成的伤害打分
  const dmgRatio = 1 - state.bossHp / state.bossMaxHp;
  return Math.round(dmgRatio * 40);
}
