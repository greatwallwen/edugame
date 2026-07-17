/**
 * sort-flow · 流程排序 · 纯逻辑层
 *
 * 给定 N 个步骤的乱序列表，玩家拖拽排列正确顺序。
 */
export interface SortFlowItem {
  id: string;
  label: string;
}

export interface SortFlowState {
  /** 当前玩家排列（item id 列表） */
  items: string[];
  /** 总数 */
  total: number;
  /** 正确位置数（evaluate 后填充） */
  correctCount: number;
  score: number;
  finished: boolean;
}

/**
 * 创建初始状态。items 会被 Fisher-Yates 洗牌。
 * 传入 seed 可复现（测试用）。
 */
export function createState(
  correctOrder: ReadonlyArray<SortFlowItem>,
  shuffle = true,
): SortFlowState {
  const ids = correctOrder.map((i) => i.id);
  if (shuffle) {
    // Fisher-Yates
    for (let i = ids.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [ids[i], ids[j]] = [ids[j]!, ids[i]!];
    }
  }
  return { items: ids, total: correctOrder.length, correctCount: 0, score: 0, finished: false };
}

/** 玩家拖拽：将 fromIdx 移到 toIdx */
export function moveItem(state: SortFlowState, fromIdx: number, toIdx: number): SortFlowState {
  if (state.finished) return state;
  if (fromIdx < 0 || fromIdx >= state.items.length) return state;
  if (toIdx < 0 || toIdx >= state.items.length) return state;
  if (fromIdx === toIdx) return state;
  const items = [...state.items];
  const [moved] = items.splice(fromIdx, 1);
  items.splice(toIdx, 0, moved!);
  return { ...state, items };
}

/** 提交评估：比对正确位置数 */
export function evaluate(
  state: SortFlowState,
  correctOrder: ReadonlyArray<SortFlowItem>,
): SortFlowState {
  let correctCount = 0;
  for (let i = 0; i < correctOrder.length; i++) {
    if (state.items[i] === correctOrder[i]!.id) correctCount++;
  }
  const score = state.total === 0 ? 0 : Math.round((correctCount / state.total) * 100);
  return { ...state, correctCount, score, finished: true };
}

/** 最终分数 0..100 */
export function finalScore(state: SortFlowState): number {
  return state.score;
}
