/**
 * drag-match · 拖拽匹配 · 纯逻辑层
 *
 * 拖拽连线/归类：左侧 items 拖到右侧 targets，正确配对得分。
 */
export interface DragPair {
  itemId: string;
  itemLabel: string;
  targetId: string;
  targetLabel: string;
}

export interface DragMatchState {
  /** 玩家已提交的配对 */
  submitted: Map<string, string>; // itemId → targetId
  total: number;
  correct: number;
  finished: boolean;
}

export function createState(pairs: ReadonlyArray<DragPair>): DragMatchState {
  return { submitted: new Map(), total: pairs.length, correct: 0, finished: false };
}

export function submitPair(state: DragMatchState, itemId: string, targetId: string): DragMatchState {
  if (state.finished) return state;
  const submitted = new Map(state.submitted);
  submitted.set(itemId, targetId);
  return { ...state, submitted };
}

export function undoPair(state: DragMatchState, itemId: string): DragMatchState {
  const submitted = new Map(state.submitted);
  submitted.delete(itemId);
  return { ...state, submitted };
}

export function evaluate(state: DragMatchState, pairs: ReadonlyArray<DragPair>): DragMatchState {
  let correct = 0;
  for (const p of pairs) {
    if (state.submitted.get(p.itemId) === p.targetId) correct++;
  }
  return { ...state, correct, finished: true };
}

export function finalScore(state: DragMatchState): number {
  if (state.total === 0) return 0;
  return Math.round((state.correct / state.total) * 100);
}
