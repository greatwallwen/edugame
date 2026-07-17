/**
 * Finale Challenge · 内部类型与事件定义
 *
 * 与 @dgbook/types 中 FinaleChallengeBlockSchema 的 zod 推导类型对齐：
 *   - FinaleChallengeBlock / FinaleStage / FinaleQuestion / FinaleQuestionSpec
 * 此处只补充 runtime 状态与事件类型，不在 manifest schema 中重复声明。
 *
 * @see .dgbook/design/finale-challenge-game-spec.md
 */
import type {
  FinaleChallengeBlock,
  FinaleStage,
  FinaleQuestion,
  FinaleQuestionSpec,
} from '@dgbook/types';

export type {
  FinaleChallengeBlock,
  FinaleStage,
  FinaleQuestion,
  FinaleQuestionSpec,
};

/** 段位（评级） — 与 spec §5.2 对齐 */
export type FinaleRank = 'S+' | 'S' | 'A' | 'B' | 'C';

/** 答题判定分级 — 与 spec §1.2 对齐 */
export type FinaleVerdict = 'perfect' | 'great' | 'good' | 'miss';

/** 引擎相位 */
export type FinalePhase =
  | 'idle' // 还没进挑战
  | 'intro' // 入场动画
  | 'stage-card' // 关卡卡片展示
  | 'playing' // 答题中
  | 'feedback' // 答完反馈短延迟
  | 'stage-clear' // 关过卡片（短反馈）
  | 'stage-debrief' // 关过后总结要点解锁卡（方式 B）
  | 'boss-intro' // Boss 入场
  | 'result-pass' // 结算 · 通关
  | 'result-fail'; // 结算 · 失败

/** 全屏状态 */
export type FullscreenStatus = 'native' | 'pseudo' | 'closed';

/** 引擎运行时 state（外部只读） */
export interface FinaleEngineState {
  phase: FinalePhase;
  /** 当前关卡索引 */
  stageIndex: number;
  /** 当前题目索引（关内） */
  questionIndex: number;
  /** 当前 HP */
  hp: number;
  /** HP 上限 */
  hpMax: number;
  /** 累计分 */
  score: number;
  /** 当前连击 */
  combo: number;
  /** 历史最高连击（结算用） */
  comboPeak: number;
  /** 当前关剩余倒计时（毫秒，0 = 关失败 / timeout） */
  timeRemainingMs: number;
  /** 当前关启动时刻 epoch ms（用于 speedBonus 计算） */
  stageStartedAt: number;
  /** 当前题启动时刻 epoch ms */
  questionStartedAt: number;
  /** 静音 */
  muted: boolean;
  /** 答题历史（结算 / 跳回错题点用） */
  history: FinaleHistoryEntry[];
  /**
   * 课后总结合并方案 B
   *   累计已解锁的 summaryPoints 索引（升序、唯一）
   *   - 普通 stage 通关后按 summaryUnlockMap 增加
   *   - debrief 卡用此渲染"已解锁要点"
   *   - result 页用此渲染"完整总结"
   */
  unlockedSummary: number[];
}

/** 单题答题历史 */
export interface FinaleHistoryEntry {
  stageId: string;
  questionId: string;
  correct: boolean;
  verdict: FinaleVerdict;
  /** 实际用时 ms */
  timeUsedMs: number;
  /** 该题贡献分 */
  scoreEarned: number;
  /** 答错时的 hint 知识点锚点（block elementId）；通关跳回时用 */
  knowledgeAnchor?: string;
}

/** dispatch 动作类型 */
export type FinaleAction =
  | { type: 'START'; challenge: FinaleChallengeBlock }
  | { type: 'TICK'; deltaMs: number }
  | { type: 'ADVANCE_PHASE' }
  | {
      type: 'ANSWER';
      correct: boolean;
      timeUsedMs: number;
      /** 答题题目 id（与 question.id 对齐，用于历史回查） */
      questionId: string;
      knowledgeAnchor?: string;
    }
  | { type: 'NEXT_QUESTION' }
  | { type: 'NEXT_STAGE' }
  | { type: 'TIMEOUT' }
  | { type: 'TOGGLE_MUTE' }
  | { type: 'CONTINUE_DEBRIEF' } // 玩家点"继续"离开 stage-debrief
  | { type: 'RESET' };

/** 引擎对外回调（业务侧订阅） */
export interface FinaleEngineCallbacks {
  onAnswerCorrect?: (entry: FinaleHistoryEntry) => void;
  onAnswerWrong?: (entry: FinaleHistoryEntry) => void;
  onStageClear?: (stageIndex: number) => void;
  onBossDefeat?: () => void;
  onResult?: (
    phase: 'result-pass' | 'result-fail',
    finalScore: number,
    rank: FinaleRank,
  ) => void;
}

/** FinaleFx 视觉特效层订阅事件 */
export type FinaleFxEvent =
  | { type: 'answer-correct'; verdict: FinaleVerdict; scoreDelta: number }
  | { type: 'answer-wrong' }
  | { type: 'combo-break'; previousCombo: number }
  | { type: 'stage-clear'; stageIndex: number }
  | { type: 'boss-defeat' }
  | { type: 'time-warning' }; // 倒计时 ≤5s
