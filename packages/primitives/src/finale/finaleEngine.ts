/**
 * Finale Challenge · 状态机 + 计分公式
 *
 * - 纯函数：calcQuestionScore / calcRank / calcMaxBaseScore / classifyVerdict
 * - reducer: finaleReducer (action -> state)
 * - hook: useFinaleEngine（state + dispatch + onResult 回调）
 *
 * 公式与段位见 .dgbook/design/finale-challenge-game-spec.md §5。
 *
 * 教学场景温和化（spec §5.3）：
 *   - 答错：combo 清零、扣 1 HP、继续本关
 *   - TIMEOUT：扣 1 HP、跳到下一关
 *   - HP=0：进入 result-fail（不弹"GAME OVER"，文案温和）
 */
import { useCallback, useEffect, useMemo, useReducer, useRef } from 'react';
import type {
  FinaleAction,
  FinaleChallengeBlock,
  FinaleEngineCallbacks,
  FinaleEngineState,
  FinaleHistoryEntry,
  FinalePhase,
  FinaleQuestion,
  FinaleRank,
  FinaleStage,
  FinaleVerdict,
} from './types';

/* ─────────────────────────── 常量 ─────────────────────────── */

const DIFFICULTY_FACTOR = { easy: 1, medium: 1.2, hard: 1.5 } as const;
const COMBO_CAP = 10;
const COMBO_STEP = 0.1;
const SPEED_WEIGHT = 0.5;
/** Boss 关分数加成（使最后一关比普通关更"重"） */
const BOSS_SCORE_MULTIPLIER = 1.5;

/* ─────────────────────── 纯函数 ─────────────────────── */

/**
 * 当前题目得分公式
 *   score = scoreBase × difficultyFactor × comboMultiplier × speedBonus × bossMul
 *   comboMultiplier = 1 + 0.1 × min(combo, 10)
 *   speedBonus      = 1 + 0.5 × (1 - timeUsed/timeLimit)^2
 */
export function calcQuestionScore(opts: {
  scoreBase: number;
  difficulty: 'easy' | 'medium' | 'hard';
  comboBefore: number;
  timeUsedMs: number;
  timeLimitMs: number;
  isBoss: boolean;
}): number {
  const { scoreBase, difficulty, comboBefore, timeUsedMs, timeLimitMs, isBoss } = opts;
  const df = DIFFICULTY_FACTOR[difficulty] ?? 1;
  const combo = Math.max(0, Math.min(comboBefore, COMBO_CAP));
  const cm = 1 + COMBO_STEP * combo;
  const ratio = Math.max(0, Math.min(1, timeUsedMs / Math.max(1, timeLimitMs)));
  const sb = 1 + SPEED_WEIGHT * Math.pow(1 - ratio, 2);
  const bossMul = isBoss ? BOSS_SCORE_MULTIPLIER : 1;
  return Math.round(scoreBase * df * cm * sb * bossMul);
}

/** 判定档（用于飞字 "Perfect / Great / Good / Miss"） */
export function classifyVerdict(opts: {
  correct: boolean;
  timeUsedMs: number;
  timeLimitMs: number;
  comboBefore: number;
}): FinaleVerdict {
  if (!opts.correct) return 'miss';
  const ratio = opts.timeUsedMs / Math.max(1, opts.timeLimitMs);
  if (ratio < 0.3 && opts.comboBefore >= 3) return 'perfect';
  if (ratio < 0.5) return 'great';
  return 'good';
}

/** 全挑战的"基础分上限"（每题打满 base × difficulty，但无 combo/speed/boss 加成） */
export function calcMaxBaseScore(challenge: FinaleChallengeBlock): number {
  let total = 0;
  challenge.stages.forEach((s, idx) => {
    const isBoss = getBossStageIndex(challenge) === idx;
    s.questions.forEach((q) => {
      const df = DIFFICULTY_FACTOR[q.difficulty] ?? 1;
      total += q.scoreBase * df * (isBoss ? BOSS_SCORE_MULTIPLIER : 1);
    });
  });
  return Math.max(1, total);
}

/** Boss 关索引：缺省取最后一关 */
export function getBossStageIndex(challenge: FinaleChallengeBlock): number {
  if (typeof challenge.bossStageIndex === 'number') {
    return Math.max(
      0,
      Math.min(challenge.bossStageIndex, challenge.stages.length - 1),
    );
  }
  return Math.max(0, challenge.stages.length - 1);
}

/**
 * 段位计算（spec §5.2）：基于 score / maxBaseScore 比值
 *   ≥1.8 S+ / ≥1.5 S / ≥1.2 A / ≥1.0 B / 其它 C
 *   失败（HP=0）兜底为 C，由调用方传 forceFail
 */
export function calcRank(opts: {
  score: number;
  maxBaseScore: number;
  forceFail?: boolean;
}): FinaleRank {
  if (opts.forceFail) return 'C';
  const r = opts.score / Math.max(1, opts.maxBaseScore);
  if (r >= 1.8) return 'S+';
  if (r >= 1.5) return 'S';
  if (r >= 1.2) return 'A';
  if (r >= 1.0) return 'B';
  return 'C';
}


/* ─────────────────────── 内部 helpers ─────────────────────── */

interface FinaleInternal extends FinaleEngineState {
  /** 缓存当前 challenge（reducer 闭包内访问 stages / hpMax 等） */
  __challenge: FinaleChallengeBlock | null;
}

function getStage(state: FinaleInternal): FinaleStage | null {
  if (!state.__challenge) return null;
  return state.__challenge.stages[state.stageIndex] ?? null;
}

function getQuestion(state: FinaleInternal): FinaleQuestion | null {
  const stage = getStage(state);
  if (!stage) return null;
  return stage.questions[state.questionIndex] ?? null;
}

function isBossStage(state: FinaleInternal): boolean {
  if (!state.__challenge) return false;
  return getBossStageIndex(state.__challenge) === state.stageIndex;
}

/** 计算下一个 phase（不修改其他字段）。供 ADVANCE_PHASE 使用。 */
function nextPhaseFor(state: FinaleInternal): FinalePhase {
  switch (state.phase) {
    case 'idle':
      return 'intro';
    case 'intro':
      return 'stage-card';
    case 'stage-card':
      return 'playing';
    case 'feedback':
      return 'playing';
    case 'stage-clear':
    case 'boss-intro':
      return 'stage-card';
    default:
      return state.phase;
  }
}

function createInitialState(challenge: FinaleChallengeBlock | null): FinaleInternal {
  const hpMax = challenge?.hpMax ?? 3;
  const firstStage = challenge?.stages[0];
  const now = Date.now();
  return {
    __challenge: challenge,
    phase: 'idle',
    stageIndex: 0,
    questionIndex: 0,
    hp: hpMax,
    hpMax,
    score: 0,
    combo: 0,
    comboPeak: 0,
    timeRemainingMs: (firstStage?.timeLimitSec ?? 60) * 1000,
    stageStartedAt: now,
    questionStartedAt: now,
    muted: false,
    history: [],
    unlockedSummary: [],
  };
}

/** 按 summaryUnlockMap 计算累加后的 unlockedSummary */
function unlockSummaryForStage(
  state: FinaleInternal,
  stageId: string,
): number[] {
  const map = state.__challenge?.summaryUnlockMap;
  const points = state.__challenge?.summaryPoints;
  if (!map || !points || !points.length) return state.unlockedSummary;
  const add = map[stageId];
  if (!add || !add.length) return state.unlockedSummary;
  const seen = new Set(state.unlockedSummary);
  add.forEach((i) => {
    if (i >= 0 && i < points.length) seen.add(i);
  });
  return Array.from(seen).sort((a, b) => a - b);
}

/* ─────────────────────── reducer ─────────────────────── */

export function finaleReducer(
  state: FinaleInternal,
  action: FinaleAction,
): FinaleInternal {
  switch (action.type) {
    case 'START': {
      // 重置到初始 state，同时直接进入 intro 相位
      const fresh = createInitialState(action.challenge);
      return { ...fresh, phase: 'intro' };
    }

    case 'TICK': {
      if (state.phase !== 'playing') return state;
      const t = Math.max(0, state.timeRemainingMs - action.deltaMs);
      if (t <= 0) {
        // 自动 timeout：扣 1 HP，跳关
        return finaleReducer(state, { type: 'TIMEOUT' });
      }
      return { ...state, timeRemainingMs: t };
    }

    case 'ADVANCE_PHASE': {
      const next = nextPhaseFor(state);
      if (next === state.phase) return state;
      // 进入 playing 时刷新计时器（首题或反馈后下一题）
      if (next === 'playing') {
        const stage = getStage(state);
        const limit = (stage?.timeLimitSec ?? 60) * 1000;
        const now = Date.now();
        const isStageStart =
          state.phase === 'stage-card' && state.questionIndex === 0;
        return {
          ...state,
          phase: 'playing',
          questionStartedAt: now,
          stageStartedAt: isStageStart ? now : state.stageStartedAt,
          timeRemainingMs: isStageStart ? limit : state.timeRemainingMs,
        };
      }
      return { ...state, phase: next };
    }

    case 'ANSWER': {
      const stage = getStage(state);
      const question = getQuestion(state);
      if (!stage || !question) return state;
      const timeLimitMs = stage.timeLimitSec * 1000;
      const verdict = classifyVerdict({
        correct: action.correct,
        timeUsedMs: action.timeUsedMs,
        timeLimitMs,
        comboBefore: state.combo,
      });
      const isBoss = isBossStage(state);

      let scoreEarned = 0;
      let nextCombo = state.combo;
      let nextHp = state.hp;
      if (action.correct) {
        scoreEarned = calcQuestionScore({
          scoreBase: question.scoreBase,
          difficulty: question.difficulty,
          comboBefore: state.combo,
          timeUsedMs: action.timeUsedMs,
          timeLimitMs,
          isBoss,
        });
        nextCombo = state.combo + 1;
      } else {
        nextCombo = 0;
        nextHp = Math.max(0, state.hp - 1);
      }

      const entry: FinaleHistoryEntry = {
        stageId: stage.id,
        questionId: action.questionId,
        correct: action.correct,
        verdict,
        timeUsedMs: action.timeUsedMs,
        scoreEarned,
        knowledgeAnchor: action.knowledgeAnchor,
      };

      const nextScore = state.score + scoreEarned;
      const nextComboPeak = Math.max(state.comboPeak, nextCombo);
      const nextHistory = [...state.history, entry];

      // HP 归零 → 直接 fail
      if (nextHp <= 0) {
        return {
          ...state,
          phase: 'result-fail',
          score: nextScore,
          combo: nextCombo,
          comboPeak: nextComboPeak,
          hp: 0,
          history: nextHistory,
        };
      }

      // 否则进入 feedback 相位（外层会 setTimeout 触发 NEXT_QUESTION）
      return {
        ...state,
        phase: 'feedback',
        score: nextScore,
        combo: nextCombo,
        comboPeak: nextComboPeak,
        hp: nextHp,
        history: nextHistory,
      };
    }

    case 'NEXT_QUESTION': {
      const stage = getStage(state);
      if (!stage || !state.__challenge) return state;
      const nextQ = state.questionIndex + 1;
      if (nextQ < stage.questions.length) {
        // 同一关下一题
        return {
          ...state,
          phase: 'playing',
          questionIndex: nextQ,
          questionStartedAt: Date.now(),
        };
      }
      // 关结束 → 决定下一相位
      const isLast = state.stageIndex >= state.__challenge.stages.length - 1;
      if (isLast) {
        // 最后一关结束 → 直接进 result
        return { ...state, phase: 'result-pass' };
      }
      const map = state.__challenge.summaryUnlockMap;
      const points = state.__challenge.summaryPoints;
      const hasDebrief =
        !!map && !!points && points.length > 0 &&
        Array.isArray(map[stage.id]) && (map[stage.id]!.length > 0);
      if (hasDebrief) {
        return {
          ...state,
          phase: 'stage-debrief',
          unlockedSummary: unlockSummaryForStage(state, stage.id),
        };
      }
      return { ...state, phase: 'stage-clear' };
    }

    case 'CONTINUE_DEBRIEF': {
      // 玩家点"继续" → 进入 stage-clear（沿用旧路径，再由自动推进 → NEXT_STAGE）
      if (state.phase !== 'stage-debrief') return state;
      return { ...state, phase: 'stage-clear' };
    }

    case 'NEXT_STAGE': {
      if (!state.__challenge) return state;
      const ni = state.stageIndex + 1;
      if (ni >= state.__challenge.stages.length) {
        return { ...state, phase: 'result-pass' };
      }
      const stage = state.__challenge.stages[ni]!;
      const bossIdx = getBossStageIndex(state.__challenge);
      const isBossNext = bossIdx === ni;
      return {
        ...state,
        phase: isBossNext ? 'boss-intro' : 'stage-card',
        stageIndex: ni,
        questionIndex: 0,
        timeRemainingMs: stage.timeLimitSec * 1000,
        stageStartedAt: Date.now(),
      };
    }

    case 'TIMEOUT': {
      const nextHp = Math.max(0, state.hp - 1);
      if (nextHp <= 0) {
        return { ...state, phase: 'result-fail', hp: 0, combo: 0 };
      }
      // 强制跳到下一关
      const stage = getStage(state);
      const stageId = stage?.id ?? '';
      const question = getQuestion(state);
      const timeoutEntry: FinaleHistoryEntry = {
        stageId,
        questionId: question?.id ?? '__timeout',
        correct: false,
        verdict: 'miss',
        timeUsedMs: stage ? stage.timeLimitSec * 1000 : 0,
        scoreEarned: 0,
      };
      const after: FinaleInternal = {
        ...state,
        hp: nextHp,
        combo: 0,
        history: [...state.history, timeoutEntry],
      };
      return finaleReducer(after, { type: 'NEXT_STAGE' });
    }

    case 'TOGGLE_MUTE':
      return { ...state, muted: !state.muted };

    case 'RESET':
      return createInitialState(state.__challenge);

    default:
      return state;
  }
}

/* ─────────────────────── hook ─────────────────────── */

export interface UseFinaleEngineOptions extends FinaleEngineCallbacks {
  /** TICK 间隔，默认 200ms */
  tickIntervalMs?: number;
  /** answer-feedback 后等待多久自动 NEXT_QUESTION，默认 900ms */
  feedbackDelayMs?: number;
  /** stage-clear 后等待多久自动 NEXT_STAGE，默认 1500ms */
  stageClearDelayMs?: number;
  /** boss-intro 后等待多久自动 ADVANCE_PHASE → stage-card，默认 1800ms */
  bossIntroDelayMs?: number;
}

export interface FinaleEngineHandle {
  state: FinaleEngineState;
  dispatch: (action: FinaleAction) => void;
  /** 当前题（便于组件直接渲染） */
  currentStage: FinaleStage | null;
  currentQuestion: FinaleQuestion | null;
  isBoss: boolean;
  /** 段位（仅 result 相位有意义） */
  rank: FinaleRank;
  maxBaseScore: number;
}

export function useFinaleEngine(
  challenge: FinaleChallengeBlock | null,
  opts: UseFinaleEngineOptions = {},
): FinaleEngineHandle {
  const {
    tickIntervalMs = 200,
    feedbackDelayMs = 900,
    stageClearDelayMs = 1500,
    bossIntroDelayMs = 1800,
  } = opts;

  const [state, dispatch] = useReducer(
    finaleReducer,
    challenge,
    createInitialState,
  );

  // 持续保留最新 callbacks（避免每次 re-render 触发依赖变化）
  const cbRef = useRef<FinaleEngineCallbacks>(opts);
  cbRef.current = opts;

  // TICK 循环
  useEffect(() => {
    if (state.phase !== 'playing') return;
    const handle = window.setInterval(() => {
      dispatch({ type: 'TICK', deltaMs: tickIntervalMs });
    }, tickIntervalMs);
    return () => window.clearInterval(handle);
  }, [state.phase, tickIntervalMs]);

  // feedback / stage-clear / boss-intro 自动推进
  useEffect(() => {
    let h: number | null = null;
    if (state.phase === 'feedback') {
      h = window.setTimeout(
        () => dispatch({ type: 'NEXT_QUESTION' }),
        feedbackDelayMs,
      );
    } else if (state.phase === 'stage-clear') {
      cbRef.current.onStageClear?.(state.stageIndex);
      h = window.setTimeout(
        () => dispatch({ type: 'NEXT_STAGE' }),
        stageClearDelayMs,
      );
    } else if (state.phase === 'boss-intro') {
      h = window.setTimeout(
        () => dispatch({ type: 'ADVANCE_PHASE' }),
        bossIntroDelayMs,
      );
    }
    return () => {
      if (h !== null) window.clearTimeout(h);
    };
  }, [
    state.phase,
    state.stageIndex,
    feedbackDelayMs,
    stageClearDelayMs,
    bossIntroDelayMs,
  ]);

  // history.length 增长 → 触发 onAnswerCorrect/Wrong 回调
  const lastHistLenRef = useRef(0);
  useEffect(() => {
    const arr = state.history;
    if (arr.length > lastHistLenRef.current) {
      const last = arr[arr.length - 1]!;
      if (last.correct) cbRef.current.onAnswerCorrect?.(last);
      else cbRef.current.onAnswerWrong?.(last);
    }
    lastHistLenRef.current = arr.length;
  }, [state.history]);

  // result 相位回调（一次性触发）
  const reportedResultRef = useRef<FinalePhase | null>(null);
  const challengeRef = useRef<FinaleChallengeBlock | null>(challenge);
  challengeRef.current = challenge;

  const maxBaseScore = useMemo(
    () => (challenge ? calcMaxBaseScore(challenge) : 1),
    [challenge],
  );

  const rank = useMemo(
    () =>
      calcRank({
        score: state.score,
        maxBaseScore,
        forceFail: state.phase === 'result-fail',
      }),
    [state.score, maxBaseScore, state.phase],
  );

  useEffect(() => {
    if (
      (state.phase === 'result-pass' || state.phase === 'result-fail') &&
      reportedResultRef.current !== state.phase
    ) {
      reportedResultRef.current = state.phase;
      cbRef.current.onResult?.(state.phase, state.score, rank);
      // Boss 击破 callback（仅 result-pass 且最后一关 == bossIdx）
      if (state.phase === 'result-pass' && challengeRef.current) {
        const bossIdx = getBossStageIndex(challengeRef.current);
        if (bossIdx === state.stageIndex) {
          cbRef.current.onBossDefeat?.();
        }
      }
    }
  }, [state.phase, state.score, state.stageIndex, rank]);

  // RESET 时重置 result 哨兵
  useEffect(() => {
    if (state.phase === 'idle' || state.phase === 'intro') {
      reportedResultRef.current = null;
      lastHistLenRef.current = state.history.length;
    }
  }, [state.phase, state.history.length]);

  const dispatchSafe = useCallback((action: FinaleAction) => dispatch(action), []);

  // 派生字段
  const challengeForDerive = state.__challenge;
  const currentStage =
    challengeForDerive?.stages[state.stageIndex] ?? null;
  const currentQuestion = currentStage?.questions[state.questionIndex] ?? null;
  const isBoss = challengeForDerive
    ? getBossStageIndex(challengeForDerive) === state.stageIndex
    : false;

  // 把 internal state 中的 __challenge 隐藏，对外只暴露 FinaleEngineState
  const externalState: FinaleEngineState = useMemo(
    () => ({
      phase: state.phase,
      stageIndex: state.stageIndex,
      questionIndex: state.questionIndex,
      hp: state.hp,
      hpMax: state.hpMax,
      score: state.score,
      combo: state.combo,
      comboPeak: state.comboPeak,
      timeRemainingMs: state.timeRemainingMs,
      stageStartedAt: state.stageStartedAt,
      questionStartedAt: state.questionStartedAt,
      muted: state.muted,
      history: state.history,
      unlockedSummary: state.unlockedSummary,
    }),
    [
      state.phase,
      state.stageIndex,
      state.questionIndex,
      state.hp,
      state.hpMax,
      state.score,
      state.combo,
      state.comboPeak,
      state.timeRemainingMs,
      state.stageStartedAt,
      state.questionStartedAt,
      state.muted,
      state.history,
      state.unlockedSummary,
    ],
  );

  return {
    state: externalState,
    dispatch: dispatchSafe,
    currentStage,
    currentQuestion,
    isBoss,
    rank,
    maxBaseScore,
  };
}
