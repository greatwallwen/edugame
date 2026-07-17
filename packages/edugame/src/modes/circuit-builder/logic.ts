/**
 * circuit-builder · 纯逻辑层
 *
 * 电路拼装：玩家从元件抽屉拖元件到面包板网格，连线后通电验证。
 * 核心机制：放置正确性 + 连线正确性 → 评分。
 */

export interface ComponentSlot {
  /** 元件 ID */
  id: string;
  /** 元件类型 */
  type: string;
  /** 目标位置 [row, col] */
  targetPos: [number, number];
}

export interface WireConnection {
  from: string; // componentId.pin
  to: string;   // componentId.pin 或 'vcc' / 'gnd'
}

export interface CircuitBuilderState {
  /** 已放置的元件 */
  placed: Map<string, [number, number]>;
  /** 已连线 */
  wires: WireConnection[];
  /** 通电结果：null=未验证, true=通过, false=失败 */
  powered: boolean | null;
  /** 放置正确数 */
  correctPlacements: number;
  /** 连线正确数 */
  correctWires: number;
  finished: boolean;
}

export function createInitialState(): CircuitBuilderState {
  return {
    placed: new Map(),
    wires: [],
    powered: null,
    correctPlacements: 0,
    correctWires: 0,
    finished: false,
  };
}

/** 放置元件 */
export function placeComponent(
  state: CircuitBuilderState,
  componentId: string,
  pos: [number, number],
): CircuitBuilderState {
  const placed = new Map(state.placed);
  placed.set(componentId, pos);
  return { ...state, placed };
}

/** 连线 */
export function addWire(
  state: CircuitBuilderState,
  wire: WireConnection,
): CircuitBuilderState {
  return { ...state, wires: [...state.wires, wire] };
}

/** 撤回最后一根线 */
export function undoWire(state: CircuitBuilderState): CircuitBuilderState {
  return { ...state, wires: state.wires.slice(0, -1) };
}

/**
 * 通电验证：对比放置 + 连线与目标。
 * @returns 更新后的 state（含 correctPlacements / correctWires / powered）
 */
export function powerOn(
  state: CircuitBuilderState,
  targetSlots: ReadonlyArray<ComponentSlot>,
  targetWires: ReadonlyArray<WireConnection>,
): CircuitBuilderState {
  let correctPlacements = 0;
  for (const slot of targetSlots) {
    const pos = state.placed.get(slot.id);
    if (pos && pos[0] === slot.targetPos[0] && pos[1] === slot.targetPos[1]) {
      correctPlacements++;
    }
  }

  let correctWires = 0;
  for (const tw of targetWires) {
    const found = state.wires.some(
      (w) => (w.from === tw.from && w.to === tw.to) || (w.from === tw.to && w.to === tw.from),
    );
    if (found) correctWires++;
  }

  const totalChecks = targetSlots.length + targetWires.length;
  const passed = totalChecks > 0 && (correctPlacements + correctWires) === totalChecks;

  return {
    ...state,
    correctPlacements,
    correctWires,
    powered: passed,
    finished: true,
  };
}

/** 评分 0..100 */
export function computeFinalScore(
  state: CircuitBuilderState,
  targetSlots: ReadonlyArray<ComponentSlot>,
  targetWires: ReadonlyArray<WireConnection>,
): number {
  const total = targetSlots.length + targetWires.length;
  if (total === 0) return 100;
  const correct = state.correctPlacements + state.correctWires;
  return Math.round((correct / total) * 100);
}
