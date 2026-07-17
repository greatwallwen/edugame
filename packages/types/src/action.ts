/**
 * Page-level action orchestration (v4.5 · 设计中，运行时未实现)
 *
 * 状态：DESIGN-ONLY · 类型骨架
 * 实现路线图：见 docs/architecture/openmaic-benchmark.md §3.1
 *
 * 设计目标：
 *   把 page 内多 block 之间的"演讲流"显式化为 PageAction[]，
 *   补足 OpenMAIC PlaybackEngine 的能力差距，但保持 DGBook 的强类型 + zod 校验风格。
 *
 * 兼容策略（重要）：
 *   - PageAction[] 全部 OPTIONAL，旧 manifest 不需要任何改动；
 *   - 当 page.actions 缺省或为空数组时，播放器走原 block 顺播路径，行为完全不变；
 *   - 当 page.actions 非空时，由未来的 ActionRunner 子模块接管（本轮不实现）。
 *
 * 与 OpenMAIC 对应关系：
 *   - DGBook PageAction.speak     ← OpenMAIC SpeechAction
 *   - DGBook PageAction.spotlight ← OpenMAIC SpotlightAction
 *   - DGBook PageAction.laser     ← OpenMAIC LaserAction
 *   - DGBook PageAction.reveal    ← OpenMAIC（无对应；DGBook 设计补足）
 *   - DGBook PageAction.wait      ← OpenMAIC（无对应；DGBook 设计补足）
 *   - DGBook PageAction.pause-for-discussion ← OpenMAIC DiscussionAction（简化版）
 *
 * 不引入的（边界）：
 *   - OpenMAIC wb_* 12 个白板 action 不在本骨架内（DGBook §3.4 是 P2 项，按需再加）；
 *   - OpenMAIC widget_* 互动 action 暂不引入（widget block 自己的 teacher 字段已够用）。
 */

import { z } from 'zod';

const ActionIdSchema = z
  .string()
  .min(1)
  .max(64)
  .regex(/^[a-zA-Z0-9_-]+$/, 'action id must be [a-zA-Z0-9_-]');

const TargetIdSchema = z.string().min(1).max(128);

/**
 * speak · 朗读型 action（同步，等 TTS 结束后下一步）
 *
 * SPEAKABLE 红线：text 也计入 step 朗读源。
 * 与 commentary.script 的区别：speak 跨 block 编排，commentary 绑定单 block。
 */
export const SpeakActionSchema = z.object({
  id: ActionIdSchema,
  type: z.literal('speak'),
  /** 该 action 触发时聚焦的 block id（可选） */
  blockId: z.string().optional(),
  /** 朗读文本（必填）。带 markdown 时由 textNormalize 预处理。 */
  text: z.string().min(1),
  /** 音色覆盖；缺省继承 page/course 默认 */
  voiceId: z.string().optional(),
  /** 语速 0.5-2.0；缺省取播放器全局速度 */
  rate: z.number().min(0.5).max(2.0).optional(),
});
export type SpeakAction = z.infer<typeof SpeakActionSchema>;

/**
 * spotlight · 元素聚焦（fire-and-forget，立即下一步）
 *
 * 渲染：在 targetId 对应的 DOM 上叠加镂空 mask。
 * 约定：被聚焦元素需有 data-spotlight-id="<id>" 属性，或 id 等同于 block.id。
 */
export const SpotlightActionSchema = z.object({
  id: ActionIdSchema,
  type: z.literal('spotlight'),
  targetId: TargetIdSchema,
  /** 暗化背景透明度 0..1，缺省 0.55 */
  dimOpacity: z.number().min(0).max(1).optional(),
});
export type SpotlightAction = z.infer<typeof SpotlightActionSchema>;

/**
 * laser · 激光指引（fire-and-forget）
 */
export const LaserActionSchema = z.object({
  id: ActionIdSchema,
  type: z.literal('laser'),
  targetId: TargetIdSchema,
  /** CSS 颜色，缺省 '#ff3b30' */
  color: z.string().optional(),
});
export type LaserAction = z.infer<typeof LaserActionSchema>;

/**
 * reveal · 元素揭示（同步，等动画完成）
 *
 * 与 spotlight 的区别：reveal 是入场动画，spotlight 是聚焦遮罩。
 */
export const RevealActionSchema = z.object({
  id: ActionIdSchema,
  type: z.literal('reveal'),
  targetId: TargetIdSchema,
  mode: z.enum(['fade', 'slide', 'draw']).optional(),
  /** 动画时长 ms，缺省 400 */
  durationMs: z.number().int().min(0).max(10000).optional(),
});
export type RevealAction = z.infer<typeof RevealActionSchema>;

/**
 * wait · 显式等待（同步）
 *
 * 用于让讲解节奏松一点，常见于公式停顿、图示停留。
 */
export const WaitActionSchema = z.object({
  id: ActionIdSchema,
  type: z.literal('wait'),
  ms: z.number().int().min(0).max(60000),
});
export type WaitAction = z.infer<typeof WaitActionSchema>;

/**
 * pause-for-discussion · 暂停进入 live 模式（同步）
 *
 * 触发：播放器进入 EngineMode='live'，AI 助教面板被聚焦。
 * 恢复：用户点击「继续讲解」时回到 EngineMode='playing'，从下一个 action 开始。
 */
export const PauseForDiscussionActionSchema = z.object({
  id: ActionIdSchema,
  type: z.literal('pause-for-discussion'),
  /** 讨论话题，注入助教 prompt */
  topic: z.string().min(1).max(200),
  /** 助教推荐提问（可选） */
  prompt: z.string().optional(),
});
export type PauseForDiscussionAction = z.infer<typeof PauseForDiscussionActionSchema>;

/**
 * play-video · 播放视频元素（同步，等视频结束或用户跳过）
 *
 * 视频时间轴字幕同步：subtitles 携带"画面时间点 → 讲解文案"，
 *   播放器按 video.currentTime 在对应时间点切换字幕（并尝试 TTS 伴随朗读），
 *   字幕推进以视频时间轴为准（不依赖 TTS 时长，TTS 不可用也不卡）。
 *   t 单位为秒（视频内时间）；缺省 subtitles 时退化为"静默播完"旧行为。
 */
export const VideoSubtitleSchema = z.object({
  /** 该字幕出现的视频时间点（秒，0-based 累加自各 section duration） */
  t: z.number().min(0),
  /** 该段画面对应的讲解文案 */
  text: z.string().min(1),
});
export type VideoSubtitle = z.infer<typeof VideoSubtitleSchema>;

export const PlayVideoActionSchema = z.object({
  id: ActionIdSchema,
  type: z.literal('play-video'),
  targetId: TargetIdSchema,
  /** 视频时间轴字幕（与 manim sections.json 的 name+duration 对齐） */
  subtitles: z.array(VideoSubtitleSchema).optional(),
});
export type PlayVideoAction = z.infer<typeof PlayVideoActionSchema>;

/**
 * anim-step · 推进动画到第 N 步（fire-and-forget）
 * 取代 Shell.tsx 中手动 postMessage dgb-step 的逻辑。
 */
export const AnimStepActionSchema = z.object({
  id: ActionIdSchema,
  type: z.literal('anim-step'),
  /** 目标步骤（0-based） */
  step: z.number().int().min(0),
});
export type AnimStepAction = z.infer<typeof AnimStepActionSchema>;

/**
 * widget-highlight · 高亮 widget 内元素（同步，含 duration）
 */
export const WidgetHighlightActionSchema = z.object({
  id: ActionIdSchema,
  type: z.literal('widget-highlight'),
  targetId: TargetIdSchema,
  /** 高亮持续时间 ms，缺省 3000 */
  duration: z.number().int().min(0).max(30000).optional(),
  /** 伴随朗读文本（可选） */
  speech: z.string().optional(),
});
export type WidgetHighlightAction = z.infer<typeof WidgetHighlightActionSchema>;

/**
 * widget-set-state · 设置 widget 状态（同步，含过渡动画等待）
 */
export const WidgetSetStateActionSchema = z.object({
  id: ActionIdSchema,
  type: z.literal('widget-set-state'),
  state: z.record(z.unknown()),
  /** 过渡动画时长 ms，缺省 800 */
  transitionMs: z.number().int().min(0).max(10000).optional(),
  /** 伴随朗读文本（可选） */
  speech: z.string().optional(),
});
export type WidgetSetStateAction = z.infer<typeof WidgetSetStateActionSchema>;

/**
 * widget-annotation · 在元素上加浮标注释（同步，含显示时长）
 */
export const WidgetAnnotationActionSchema = z.object({
  id: ActionIdSchema,
  type: z.literal('widget-annotation'),
  targetId: TargetIdSchema,
  content: z.string().min(1),
  /** 注释显示时长 ms，缺省 4000 */
  duration: z.number().int().min(0).max(30000).optional(),
});
export type WidgetAnnotationAction = z.infer<typeof WidgetAnnotationActionSchema>;

/**
 * PageAction · 11 种 action 的 discriminated union
 */
export const PageActionSchema = z.discriminatedUnion('type', [
  SpeakActionSchema,
  SpotlightActionSchema,
  LaserActionSchema,
  RevealActionSchema,
  WaitActionSchema,
  PauseForDiscussionActionSchema,
  PlayVideoActionSchema,
  AnimStepActionSchema,
  WidgetHighlightActionSchema,
  WidgetSetStateActionSchema,
  WidgetAnnotationActionSchema,
]);
export type PageAction = z.infer<typeof PageActionSchema>;

/** PageAction[] 数组 schema（带顺序约束的 wrapper，留作未来扩展） */
export const PageActionsSchema = z.array(PageActionSchema);
export type PageActions = z.infer<typeof PageActionsSchema>;

/**
 * 同步性查询表
 *
 * | type                     | sync? |
 * | ------------------------ | ----- |
 * | speak                    | yes   |
 * | spotlight                | no    |
 * | laser                    | no    |
 * | anim-step                | no    |
 * | reveal                   | yes   |
 * | wait                     | yes   |
 * | pause-for-discussion     | yes   |
 * | play-video               | yes   |
 * | widget-highlight         | yes   |
 * | widget-set-state         | yes   |
 * | widget-annotation        | yes   |
 */
export const SYNC_ACTION_TYPES = new Set([
  'speak',
  'reveal',
  'wait',
  'pause-for-discussion',
  'play-video',
  'widget-highlight',
  'widget-set-state',
  'widget-annotation',
] as const);

export function isSyncAction(action: PageAction): boolean {
  return SYNC_ACTION_TYPES.has(action.type as any);
}
