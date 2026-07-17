/**
 * memory-card · 记忆翻牌 · 纯逻辑层
 *
 * 配对翻牌记忆：N 对卡牌面朝下，玩家每次翻两张，匹配则消除。
 */
export interface CardPair {
  id: string;
  front: string;
  match: string;
}

export interface MemoryCardState {
  /** 所有卡牌（已打乱） */
  cards: { id: string; content: string; pairId: string; flipped: boolean; matched: boolean }[];
  /** 当前翻开的卡牌索引（最多 2 张） */
  revealed: number[];
  attempts: number;
  matched: number;
  totalPairs: number;
  score: number;
  finished: boolean;
}

export function createState(pairs: ReadonlyArray<CardPair>): MemoryCardState {
  const cards: MemoryCardState['cards'] = [];
  for (const p of pairs) {
    cards.push({ id: `${p.id}-a`, content: p.front, pairId: p.id, flipped: false, matched: false });
    cards.push({ id: `${p.id}-b`, content: p.match, pairId: p.id, flipped: false, matched: false });
  }
  // Fisher-Yates shuffle
  for (let i = cards.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [cards[i], cards[j]] = [cards[j]!, cards[i]!];
  }
  return { cards, revealed: [], attempts: 0, matched: 0, totalPairs: pairs.length, score: 0, finished: false };
}

export function flipCard(state: MemoryCardState, cardIdx: number): MemoryCardState {
  if (state.finished) return state;
  if (state.revealed.length >= 2) return state;
  const card = state.cards[cardIdx];
  if (!card || card.flipped || card.matched) return state;

  const cards = [...state.cards];
  cards[cardIdx] = { ...card, flipped: true };
  const revealed = [...state.revealed, cardIdx];

  return { ...state, cards, revealed };
}

export function checkMatch(state: MemoryCardState): MemoryCardState {
  if (state.revealed.length !== 2) return state;
  const [i, j] = state.revealed;
  const a = state.cards[i!]!;
  const b = state.cards[j!]!;
  const isMatch = a.pairId === b.pairId;

  const cards = [...state.cards];
  if (isMatch) {
    cards[i!] = { ...a, matched: true };
    cards[j!] = { ...b, matched: true };
  } else {
    cards[i!] = { ...a, flipped: false };
    cards[j!] = { ...b, flipped: false };
  }

  const matched = state.matched + (isMatch ? 1 : 0);
  const attempts = state.attempts + 1;
  const score = isMatch ? state.score + 15 : Math.max(0, state.score - 2);
  const finished = matched >= state.totalPairs;

  return { ...state, cards, revealed: [], attempts, matched, score, finished };
}

export function finalScore(state: MemoryCardState): number {
  if (state.totalPairs === 0) return 0;
  // 满分 = 全对零失误；每多一次失误扣 5%
  const perfectAttempts = state.totalPairs;
  const extraAttempts = Math.max(0, state.attempts - perfectAttempts);
  const penalty = Math.min(0.8, extraAttempts * 0.05);
  return Math.round((1 - penalty) * 100);
}
