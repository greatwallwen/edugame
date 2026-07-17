/**
 * @dgbook/game · 核心类型
 *
 * 所有 GameMode 的输入输出 / 关卡数据 / 通关结果都在这里定义。
 * 故意不在本文件 import pixi.js，方便 GameMode 子类纯逻辑跑测试时不拉 PixiJS。
 */

export type ModeId =

  | 'bit-flip-quest'
  | 'pin-rush'
  | 'signal-surfer'
  | 'circuit-builder'
  | 'interrupt-defender'
  | 'quick-hit'
  | 'memory-card'
  | 'drag-match'
  | 'sort-flow'
  | 'card-battle'
  | 'match-3'
  | 'boss-review'
  | 'quiz-rush'
  | 'pipe-connect'
  | 'device-assemble'
  | 'maze-troubleshoot'
  | 'tower-defense'
  | '2048-merge'
  | 'minesweeper-risk'
  | 'rhythm-tap'
  | 'timeline-build'
  | 'case-detective'
  | 'knowledge-map'
  | 'repair-sim'
  | 'lab-procedure'
  | 'classification-run'
  | 'resource-management'
  | 'scenario-choice'
  | 'checkpoint-adventure'
  | 'godot-game';

export interface LearningObjective {
  /** 知识点 ID（与 manifest.abilityMap 维度对齐） */
  id: string;
  /** 中文短描述 */
  label: string;
}

export interface LevelData<TPayload = unknown> {
  modeId: ModeId;
  levelId: string;
  title: string;
  objective: string;
  /** 1..5 越大越难 */
  difficulty: 1 | 2 | 3 | 4 | 5;
  /** [一星, 二星, 三星] 分数阈值，0..100 */
  starThresholds: [number, number, number];
  /** 单局最长时间（秒），0 表示无限制 */
  timeLimit: number;
  /** 各 mode 自定义关卡数据 */
  data: TPayload;
}

export interface GameResult {
  modeId: ModeId;
  levelId: string;
  /** 0..100 */
  score: number;
  /** 0/1/2/3，0 表示未达一星阈值（未通关） */
  stars: 0 | 1 | 2 | 3;
  /** 完成时间（毫秒） */
  durationMs: number;
  /** 模式自定义统计：连击 / 失误 / 命中等 */
  stats?: Record<string, number>;
}

/**
 * GameMode 与外部 host 的协作通道。
 * 由 EduGameHost 注入；GameMode 子类只需在 init 里持有引用，
 * 在 update / 用户交互回调里按需触发。
 */
export interface GameContext {
  level: LevelData;
  /** 调用 onComplete 后 GameSession 进入终态 */
  onComplete: (result: GameResult) => void;
  /** 进度 0..1，hint 用于 UI 显示"第 3/8 关"等 */
  onProgress: (ratio: number, hint?: string) => void;
}
