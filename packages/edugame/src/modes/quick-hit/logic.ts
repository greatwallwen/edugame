/**
 * quick-hit · 知识快打 · 纯逻辑层
 *
 * 限时点击正确答案：屏幕出现多个选项，玩家在倒计时内点击正确的。
 */
export interface QuickHitQuestion {
  id: string;
  prompt: string;
  options: string[];
  correctIndex: number;
}

export interface QuickHitState {
  currentIdx: number;
  total: number;
  correct: number;
  wrong: number;
  combo: number;
  maxCombo: number;
  score: number;
  timeLeft: number;
  finished: boolean;
}

const PER_CORRECT = 10;
const COMBO_BONUS = 3;
const WRONG_PENALTY = 5;

export function createState(questions: ReadonlyArray<QuickHitQuestion>, timeLimit: number): QuickHitState {
  return { currentIdx: 0, total: questions.length, correct: 0, wrong: 0, combo: 0, maxCombo: 0, score: 0, timeLeft: timeLimit, finished: false };
}

export function answer(state: QuickHitState, questions: ReadonlyArray<QuickHitQuestion>, selectedIdx: number): { state: QuickHitState; correct: boolean } {
  if (state.finished || state.currentIdx >= questions.length) return { state: { ...state, finished: true }, correct: false };
  const q = questions[state.currentIdx]!;
  const isCorrect = selectedIdx === q.correctIndex;
  let { score, combo, maxCombo, correct, wrong } = state;
  if (isCorrect) {
    combo++; correct++;
    if (combo > maxCombo) maxCombo = combo;
    score += PER_CORRECT + combo * COMBO_BONUS;
  } else {
    wrong++; combo = 0;
    score = Math.max(0, score - WRONG_PENALTY);
  }
  const nextIdx = state.currentIdx + 1;
  const finished = nextIdx >= questions.length;
  return { state: { ...state, currentIdx: nextIdx, correct, wrong, combo, maxCombo, score, finished }, correct: isCorrect };
}

export function tick(state: QuickHitState, dtMs: number): QuickHitState {
  if (state.finished) return state;
  const timeLeft = Math.max(0, state.timeLeft - dtMs / 1000);
  if (timeLeft <= 0) return { ...state, timeLeft: 0, finished: true };
  return { ...state, timeLeft };
}

export function finalScore(state: QuickHitState): number {
  if (state.total === 0) return 0;
  let maxPossible = 0;
  for (let i = 1; i <= state.total; i++) maxPossible += PER_CORRECT + i * COMBO_BONUS;
  return Math.min(100, Math.round((state.score / maxPossible) * 100));
}
