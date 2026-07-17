/**
 * match-3 · 三消分类 · 纯逻辑层
 *
 * N×M 网格，相邻同类知识点三连消除得分。
 */

/** 一个格子存储的分类 ID（null = 空洞） */
export type Cell = string | null;

export interface Match3State {
  grid: Cell[][];
  rows: number;
  cols: number;
  score: number;
  moves: number;
  maxMoves: number;
  totalMatched: number;
  finished: boolean;
}

/** 创建初始网格，随机填充 categories，保证无初始三连 */
export function createState(
  rows: number,
  cols: number,
  categories: ReadonlyArray<string>,
  maxMoves: number,
): Match3State {
  const grid: Cell[][] = [];
  for (let r = 0; r < rows; r++) {
    grid[r] = [];
    for (let c = 0; c < cols; c++) {
      grid[r]![c] = pickNoMatch(grid, r, c, categories);
    }
  }
  return { grid, rows, cols, score: 0, moves: 0, maxMoves, totalMatched: 0, finished: false };
}

/** 交换两个相邻格子，触发消除 + 重力 + 连锁 */
export function swap(
  state: Match3State,
  r1: number,
  c1: number,
  r2: number,
  c2: number,
  categories: ReadonlyArray<string>,
): Match3State {
  if (state.finished) return state;
  if (!isAdjacent(r1, c1, r2, c2)) return state;
  if (!inBounds(state, r1, c1) || !inBounds(state, r2, c2)) return state;

  // swap
  let grid = cloneGrid(state.grid);
  [grid[r1]![c1], grid[r2]![c2]] = [grid[r2]![c2]!, grid[r1]![c1]!];

  // check for matches
  let matches = findMatches(grid, state.rows, state.cols);
  if (matches.length === 0) {
    // no matches → revert swap
    [grid[r1]![c1], grid[r2]![c2]] = [grid[r2]![c2]!, grid[r1]![c1]!];
    return state;
  }

  let { score, totalMatched, moves } = state;
  moves++;
  let chainMultiplier = 1;

  while (matches.length > 0) {
    const matched = matches.length;
    totalMatched += matched;
    score += matched * 10 * chainMultiplier;
    grid = removeMatches(grid, matches);
    grid = applyGravity(grid, state.rows, state.cols);
    grid = fillEmpty(grid, state.rows, state.cols, categories);
    matches = findMatches(grid, state.rows, state.cols);
    chainMultiplier++;
  }

  const finished = moves >= state.maxMoves;
  return { ...state, grid, score, moves, totalMatched, finished };
}

/** 查找所有横向/纵向三连+ */
export function findMatches(grid: Cell[][], rows: number, cols: number): Array<[number, number]> {
  const matched = new Set<string>();

  // 横向
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c <= cols - 3; c++) {
      const val = grid[r]![c];
      if (val && val === grid[r]![c + 1] && val === grid[r]![c + 2]) {
        let end = c + 2;
        while (end + 1 < cols && grid[r]![end + 1] === val) end++;
        for (let k = c; k <= end; k++) matched.add(`${r},${k}`);
      }
    }
  }

  // 纵向
  for (let c = 0; c < cols; c++) {
    for (let r = 0; r <= rows - 3; r++) {
      const val = grid[r]![c];
      if (val && val === grid[r + 1]![c] && val === grid[r + 2]![c]) {
        let end = r + 2;
        while (end + 1 < rows && grid[end + 1]![c] === val) end++;
        for (let k = r; k <= end; k++) matched.add(`${k},${c}`);
      }
    }
  }

  return [...matched].map((s) => {
    const [r, c] = s.split(',').map(Number);
    return [r!, c!] as [number, number];
  });
}

export function finalScore(state: Match3State): number {
  if (state.maxMoves === 0) return 0;
  // 每步平均消除 3 个为基准满分
  const expected = state.maxMoves * 3;
  return Math.min(100, Math.round((state.totalMatched / expected) * 100));
}

/* ---- helpers ---- */

function cloneGrid(grid: Cell[][]): Cell[][] {
  return grid.map((row) => [...row]);
}

function isAdjacent(r1: number, c1: number, r2: number, c2: number): boolean {
  return Math.abs(r1 - r2) + Math.abs(c1 - c2) === 1;
}

function inBounds(state: Match3State, r: number, c: number): boolean {
  return r >= 0 && r < state.rows && c >= 0 && c < state.cols;
}

function removeMatches(grid: Cell[][], positions: Array<[number, number]>): Cell[][] {
  const g = cloneGrid(grid);
  for (const [r, c] of positions) g[r]![c] = null;
  return g;
}

function applyGravity(grid: Cell[][], rows: number, cols: number): Cell[][] {
  const g = cloneGrid(grid);
  for (let c = 0; c < cols; c++) {
    let writeRow = rows - 1;
    for (let r = rows - 1; r >= 0; r--) {
      if (g[r]![c] !== null) {
        g[writeRow]![c] = g[r]![c]!;
        if (writeRow !== r) g[r]![c] = null;
        writeRow--;
      }
    }
    for (let r = writeRow; r >= 0; r--) g[r]![c] = null;
  }
  return g;
}

function fillEmpty(grid: Cell[][], rows: number, cols: number, categories: ReadonlyArray<string>): Cell[][] {
  const g = cloneGrid(grid);
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      if (g[r]![c] === null) {
        g[r]![c] = categories[Math.floor(Math.random() * categories.length)]!;
      }
    }
  }
  return g;
}

/** 随机选一个不会形成三连的 category */
function pickNoMatch(
  grid: Cell[][],
  r: number,
  c: number,
  categories: ReadonlyArray<string>,
): string {
  const avoid = new Set<string>();
  // 横向：如果左边两个一样，避免同色
  if (c >= 2 && grid[r]![c - 1] && grid[r]![c - 1] === grid[r]![c - 2]) {
    avoid.add(grid[r]![c - 1]!);
  }
  // 纵向：如果上面两个一样，避免同色
  if (r >= 2 && grid[r - 1]?.[c] && grid[r - 1]![c] === grid[r - 2]?.[c]) {
    avoid.add(grid[r - 1]![c]!);
  }
  const available = categories.filter((cat) => !avoid.has(cat));
  const pool = available.length > 0 ? available : categories;
  return pool[Math.floor(Math.random() * pool.length)]!;
}
