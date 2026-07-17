/**
 * @dgbook/types · manifest schema 共享底座（Iter-35 / T-2 拆分）
 *
 * 这一层是其他 manifest-*.ts 模块的"无依赖叶子"：
 *   - PrimitiveKind 枚举（23 种 block kind 的"白名单"）
 *   - PageTemplate 枚举（4 种页面模板）
 *   - IdSchema / BlockBase（id 与 kind 字段的类型契约）
 *   - CommentarySpecSchema（v6 通用讲解条配置，被 text/code/animation 共用）
 *
 * 红线：新增 block kind 时，**先在此文件 enum 加值**，再去 manifest-block.ts
 * 写对应 BlockSchema 子类，最后把它加入 BlockSchema 的 discriminatedUnion。
 * 三步缺一不可——少做任意一步会让 PageRenderer 默默走兜底，看似工作但白名单失效。
 */

import { z } from 'zod';

export const MANIFEST_VERSION = 4 as const;

export const PrimitiveKind = z.enum([
  'text',
  'graphics',
  'quiz',
  'digital-human',
  'animation',
  'video',
  'interactive',
  // v4 · 新增 block kind
  'code',
  'mindmap',
  'experiment',
  'summary',
  'table',
  'waveform',
  // v4.1 · 测验开场动画
  'quiz-intro-animation',
  // v4.4 · OpenMAIC 互动 Widget（对标 OpenMAIC WidgetType）
  'widget',
  // v5 · 教材化 block（纸质教材风：侧边提示 / 信息表 / 原则卡 / 双图）
  'callout',
  'info-table',
  'principles',
  'figure-pair',
  // v6 / Phase G1 · 流程图 first-class（程序设计教学核心可视化）
  //   与 mindmap 的关键差异：mermaid 表达"流程 / 状态机 / 时序"，节点可寻址 id；
  //   mindmap 表达"概念分解"，是树形 root，无时间轴语义。
  //   schema 详见 MermaidBlockSchema 注释。
  'mermaid',
  // M10 · Finale Challenge 全屏游戏化挑战（闯关 + Boss 战）
  //   与 quiz / interactive 的关键差异：finale-challenge 表达"多关递进 + HP/combo/计时
  //   + 视听反馈 + 全屏沉浸"的复合挑战外壳，内部题目复用 InteractiveSpec | QuizSpec。
  //   schema 详见 FinaleChallengeBlockSchema 注释。
  'finale-challenge',

  //   理工科课程的公式展示，如"V = N × Vref / 2^bits"分压公式 / "f = f_clk/(PSC×CCR)"频率公式等
  //   schema 详见 MathBlockSchema 注释。
  'math',

  //   与 graphics 的关键差异：wokwi-element 是"参数化电路元件"，
  //   按 spec.kind + spec.color/value/pressed 等参数化数据驱动渲染（非 src URL 静态图片）。
  //   schema 详见 WokwiElementBlockSchema 注释。
  'wokwi-element',
]);
export type PrimitiveKind = z.infer<typeof PrimitiveKind>;

export const PageTemplate = z.enum([
  'T-concept',
  'T-mindmap',
  'T-demo',
  'T-practice',
]);
export type PageTemplate = z.infer<typeof PageTemplate>;


export const IdSchema = z
  .string()
  .min(1)
  .max(64)
  .regex(/^[a-zA-Z0-9_-]+$/, 'id must be [a-zA-Z0-9_-]');

export const BlockBase = z.object({
  id: IdSchema,
  kind: PrimitiveKind,
});

/**
 * v6 · 通用讲解条配置（CommentaryBar 原语共用）
 * 用于 text / code 块挂"文字讲解 / 代码讲解"字幕条；
 * animation 块仍走 metadata.teacher（结构兼容）。
 *
 * sourceType 决定 CommentaryBar 的 badge 文字与配色：
 *   text（暖褐）/ code（深蓝）/ animation（墨绿）
 */
export const CommentarySpecSchema = z.object({
  /** 讲解来源；缺省 'text' */
  sourceType: z.enum(['animation', 'code', 'text']).optional(),
  /** 单段讲稿（与 stepScripts 二选一即可，stepScripts 优先）*/
  script: z.string().max(1200).optional(),
  /** 多段讲稿；代码常按"段落/行块"切分，文字按"小节"切分 */
  stepScripts: z.array(z.string().min(1)).max(20).optional(),
  /**
   * v6.1 · 每段讲稿对应的"关注行号"（仅 code 有意义）。
   * 长度应与 stepScripts 一致；切换到该段时，CodeBlock 将高亮这些行。
   * 行号 1-based（与 CodeBlock.highlightLines 一致）。
   */
  highlightLines: z.array(z.array(z.number().int().positive()).min(1)).max(20).optional(),
  /** 是否进入页面后自动朗读（默认 false，避免噪音）*/
  autoPlay: z.boolean().optional(),
  /** TTS 声音；缺省 Cherry */
  voice: z.string().optional(),
  /** 显示用讲师名；缺省"AI 讲师" */
  speaker: z.string().max(16).optional(),
});
export type CommentarySpec = z.infer<typeof CommentarySpecSchema>;
