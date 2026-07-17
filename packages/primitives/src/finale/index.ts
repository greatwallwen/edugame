/**
 * @dgbook/blocks · Finale Challenge 模块入口
 */
export { FinaleChallenge, type FinaleChallengeProps } from './FinaleChallenge';
export { FinaleHud, type FinaleHudProps } from './FinaleHud';
export { FinaleStage, type FinaleStageProps } from './FinaleStage';
export { FinaleResult, type FinaleResultProps } from './FinaleResult';
export {
  useFinaleEngine,
  finaleReducer,
  calcQuestionScore,
  classifyVerdict,
  calcMaxBaseScore,
  getBossStageIndex,
  calcRank,
  type UseFinaleEngineOptions,
  type FinaleEngineHandle,
} from './finaleEngine';
export { getFinaleAudio, type FinaleAudioTrack } from './finaleAudio';
export type {
  FinaleAction,
  FinaleChallengeBlock,
  FinaleEngineCallbacks,
  FinaleEngineState,
  FinaleFxEvent,
  FinaleHistoryEntry,
  FinalePhase,
  FinaleQuestion,
  FinaleQuestionSpec,
  FinaleRank,
  FinaleStage as FinaleStageData,
  FinaleVerdict,
  FullscreenStatus,
} from './types';
