/**
 * card-battle · 卡牌战斗 · 纯逻辑层
 *
 * 回合制：玩家出知识卡牌 vs AI 出题卡牌，答对伤害 AI，答错自己扣血。
 */
export interface BattleQuestion {
  id: string;
  prompt: string;
  options: string[];
  correctIndex: number;
}

export interface CardBattleState {
  playerHp: number;
  playerMaxHp: number;
  aiHp: number;
  aiMaxHp: number;
  currentIdx: number;
  total: number;
  correct: number;
  wrong: number;
  round: number;
  finished: boolean;
  /** 'win' | 'lose' | 'draw' | null (ongoing) */
  result: 'win' | 'lose' | 'draw' | null;
}

const PLAYER_DAMAGE = 20;
const AI_DAMAGE = 15;

export function createState(
  playerHp: number,
  aiHp: number,
  questions: ReadonlyArray<BattleQuestion>,
): CardBattleState {
  return {
    playerHp,
    playerMaxHp: playerHp,
    aiHp,
    aiMaxHp: aiHp,
    currentIdx: 0,
    total: questions.length,
    correct: 0,
    wrong: 0,
    round: 1,
    finished: false,
    result: null,
  };
}

export function playCard(
  state: CardBattleState,
  questions: ReadonlyArray<BattleQuestion>,
  selectedIdx: number,
): { state: CardBattleState; correct: boolean } {
  if (state.finished || state.currentIdx >= questions.length) {
    return { state: { ...state, finished: true, result: state.result ?? 'draw' }, correct: false };
  }
  const q = questions[state.currentIdx]!;
  const isCorrect = selectedIdx === q.correctIndex;

  let { playerHp, aiHp, correct, wrong, round } = state;

  if (isCorrect) {
    correct++;
    aiHp = Math.max(0, aiHp - PLAYER_DAMAGE);
  } else {
    wrong++;
    playerHp = Math.max(0, playerHp - AI_DAMAGE);
  }

  const nextIdx = state.currentIdx + 1;
  let result: CardBattleState['result'] = null;
  let finished = false;

  if (aiHp <= 0) {
    result = 'win';
    finished = true;
  } else if (playerHp <= 0) {
    result = 'lose';
    finished = true;
  } else if (nextIdx >= questions.length) {
    // 题目用完，比较剩余 HP
    result = playerHp > aiHp ? 'win' : playerHp < aiHp ? 'lose' : 'draw';
    finished = true;
  }

  return {
    state: {
      ...state,
      playerHp,
      aiHp,
      currentIdx: nextIdx,
      correct,
      wrong,
      round: round + 1,
      finished,
      result,
    },
    correct: isCorrect,
  };
}

export function finalScore(state: CardBattleState): number {
  if (state.result === 'win') {
    // 赢了根据剩余血量打分
    const hpRatio = state.playerHp / state.playerMaxHp;
    return Math.round(50 + hpRatio * 50);
  }
  if (state.result === 'draw') return 50;
  // 输了根据对 AI 造成的伤害打分
  const dmgRatio = 1 - state.aiHp / state.aiMaxHp;
  return Math.round(dmgRatio * 40);
}
