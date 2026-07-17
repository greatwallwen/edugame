/**
 * @dgbook/blocks · 六大内容原语
 *
 * M3 已落地：TextBlock / GraphicsBlock / QuizBlock
 * M7 已落地：VideoBlock / DigitalHumanBlock
 */

export { TextBlock, type TextBlockProps } from './text/TextBlock';
export { GraphicsBlock, type GraphicsBlockProps } from './graphics/GraphicsBlock';
export { QuizBlock, type QuizBlockProps } from './quiz/QuizBlock';
export { QuizIntroBlock } from './quiz/QuizIntroBlock';
export { MatchingBlock, type MatchingBlockProps } from './interactive/MatchingBlock';
export { FillBlankBlock, type FillBlankBlockProps } from './interactive/FillBlankBlock';
export { OrderingBlock, type OrderingBlockProps } from './interactive/OrderingBlock';
export { ClassificationBlock, type ClassificationBlockProps } from './interactive/ClassificationBlock';
export { MemoryMatchBlock, type MemoryMatchBlockProps } from './interactive/MemoryMatchBlock';
export { FlashcardBlock, type FlashcardBlockProps } from './interactive/FlashcardBlock';
export { SpotDifferenceBlock, type SpotDifferenceBlockProps } from './interactive/SpotDifferenceBlock';
export { HotspotBlock, type HotspotBlockProps } from './interactive/HotspotBlock';
export { CodeClozeBlock, type CodeClozeBlockProps } from './interactive/CodeClozeBlock';
export { BitFlipBlock, type BitFlipBlockProps } from './interactive/BitFlipBlock';
export { SingleChoiceBlock, MultipleChoiceBlock, TrueFalseBlock } from './interactive/ChoiceBlocks';
export { TimedQuizBlock, SliderEstimateBlock } from './interactive/TimedSliderBlocks';
export { SequenceBuilderBlock, TruthTableBlock } from './interactive/SequenceTruthBlocks';
export { BaseConverterBlock, RegisterConfigBlock } from './interactive/ConfigBlocks';
export { WaveformTunerBlock, ParameterMatchBlock } from './interactive/TunerBlocks';
export { HotspotSequenceBlock, DragLabelBlock } from './interactive/SpatialBlocks';
export { SignalTraceBlock } from './interactive/SignalTraceBlock';
export { RegisterDecoderBlock } from './interactive/RegisterDecoderBlock';
export { ArcadeRunnerBlock } from './interactive/ArcadeRunnerBlock';
export { MathBlock, type MathBlockProps } from './math/MathBlock';
export { CodeBlock, type CodeBlockProps } from './code/CodeBlock';
export { MindmapBlock, type MindmapBlockProps } from './mindmap/MindmapBlock';
// Phase G1.3 · 流程图 first-class
export {
  MermaidBlock,
  type MermaidBlockProps,
  type MermaidNodeMeta,
} from './mermaid/MermaidBlock';
export { ExperimentBlock, type ExperimentBlockProps } from './experiment/ExperimentBlock';
export { SummaryBlock, type SummaryBlockProps } from './summary/SummaryBlock';
export { TableBlock, type TableBlockProps } from './table/TableBlock';
export { WaveformBlock, type WaveformBlockProps } from './waveform/WaveformBlock';
export { VideoBlock, type VideoBlockProps } from './video/VideoBlock';
export { DigitalHumanBlock, type DigitalHumanBlockProps } from './digital-human/DigitalHumanBlock';
export { LessonHeroBanner, type LessonHeroBannerProps } from './lesson-hero/LessonHeroBanner';
export { InfoTableBlock, type InfoTableBlockProps, type InfoTableRow } from './lesson-hero/InfoTableBlock';
export { CalloutBlock, type CalloutBlockProps, type CalloutKind } from './lesson-hero/CalloutBlock';
export { PrincipleCardsBlock, type PrincipleCardsBlockProps, type PrincipleItem } from './lesson-hero/PrincipleCardsBlock';
export { FigurePairBlock, type FigurePairBlockProps, type FigureItem } from './lesson-hero/FigurePairBlock';
export {
  CommentaryBar,
  type CommentaryBarProps,
  type CommentarySourceType,
} from './commentary/CommentaryBar';
export * from './quiz/schema';

//   1:1 React 端口自 wokwi-elements 1.9.2 MIT 源；视觉一致，零 lit 运行时
//   配套 BlockKind 'wokwi-element'，通过 PageRenderer dispatch 进内容流
export {
  WokwiBlock,
  WokwiLED,
  WokwiResistor,
  WokwiPushbutton,
  type WokwiBlockProps,
  type WokwiElementSpec,
  type WokwiLEDProps,
  type WokwiResistorProps,
  type WokwiPushbuttonProps,
} from './wokwi';

// Phase G3.4 · 统一高亮（OpenMAIC SpotlightOverlay 思路移植）
// Phase G3.7 · ADR-0022 (Y) · 新增 LaserOverlay（激光指引）
export {
  HighlightProvider,
  HighlightOverlay,
  LaserOverlay,
  useHighlight,
  findHighlightTarget,
  type HighlightContextValue,
  type HighlightTarget,
  type HighlightVariant,
  type HighlightOptions,
} from './highlight';

export { triggerConfetti, triggerSmallConfetti } from './utils/confetti';

export { useGameScore, GameStat, GameWinBanner } from './game-kit';
export type { GameScoreState, UseGameScoreOptions, UseGameScoreReturn } from './game-kit';

// M10 · Finale Challenge 全屏游戏化挑战（闯关 + Boss 战）
export {
  FinaleChallenge,
  FinaleHud,
  FinaleStage as FinaleStageView,
  FinaleResult,
  useFinaleEngine,
  finaleReducer,
  calcQuestionScore,
  classifyVerdict,
  calcMaxBaseScore,
  getBossStageIndex,
  calcRank,
  getFinaleAudio,
  type FinaleChallengeProps,
  type FinaleHudProps,
  type FinaleStageProps,
  type FinaleResultProps,
  type UseFinaleEngineOptions,
  type FinaleEngineHandle,
  type FinaleAudioTrack,
  type FinaleAction,
  type FinaleChallengeBlock,
  type FinaleEngineCallbacks,
  type FinaleEngineState,
  type FinaleFxEvent,
  type FinaleHistoryEntry,
  type FinalePhase,
  type FinaleQuestion,
  type FinaleQuestionSpec,
  type FinaleRank,
  type FinaleStageData,
  type FinaleVerdict,
  type FullscreenStatus,
} from './finale';

export const PRIMITIVE_KINDS = [
  'text',
  'graphics',
  'quiz',
  'digital-human',
  'animation',
  'video',
  'interactive',
  'quiz-intro-animation',
  // Phase G1.3 · 流程图 first-class（mermaid block kind 已并入 @dgbook/types）
  'mermaid',
  // M10 · Finale Challenge 全屏游戏化挑战
  'finale-challenge',

  'wokwi-element',
] as const;

export type PrimitiveKind = (typeof PRIMITIVE_KINDS)[number];
