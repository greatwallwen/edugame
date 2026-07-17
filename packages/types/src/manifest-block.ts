/**
 * @dgbook/types · BlockSchema 集合（Iter-35 / T-2 拆分自 manifest.ts）
 *
 * 23 种 block kind 的 schema 定义 + 顶层 BlockSchema discriminated union。
 *
 * 模块依赖：
 *   - manifest-core    : BlockBase / IdSchema / CommentarySpec / PrimitiveKind 枚举
 *   - manifest-interactive : InteractiveBlockSchema 直接复用（不在本文件重定义）
 *   - manifest-finale  : FinaleChallengeBlockSchema 直接复用
 *
 * Block kind 全清单（与 PrimitiveKind 枚举一一对应）：
 *   text / graphics / quiz / digital-human / animation / video / interactive
 *   code / mindmap / experiment / summary / table / waveform
 *   quiz-intro-animation / widget
 *   callout / info-table / principles / figure-pair
 *   mermaid / finale-challenge / math
 *
 * 共 23 种。新增 kind 三步缺一不可：
 *   1. manifest-core.ts PrimitiveKind 加值
 *   2. 本文件加 XxxBlockSchema
 *   3. 本文件 BlockSchema 联合数组里加引用
 */

import { z } from 'zod';
import { BlockBase, IdSchema, CommentarySpecSchema } from './manifest-core';
import { InteractiveBlockSchema } from './manifest-interactive';
import { FinaleChallengeBlockSchema } from './manifest-finale';

// ────────────────────────────────────────────────────────────
// v3 base · text / graphics / quiz / digital-human
// ────────────────────────────────────────────────────────────

export const TextBlockSchema = BlockBase.extend({
  kind: z.literal('text'),
  markdown: z.string(),
  /** v6 · 文字讲解条（可选）*/
  commentary: CommentarySpecSchema.optional(),
});

/**
 * v6 / Phase G3 · GraphicsBlock 节点元数据（schema v2）
 *
 * 让一张教学 SVG 也能"可寻址 + 可朗读"，与 mermaid first-class 的 nodes[] 同款形态：
 *   - selector：在 inline SVG 内定位元素的 CSS 选择器；缺省时按 `#id` 兜底
 *   - label：用户可见名（aria-label / 朗读时的"节点名"）
 *   - description：朗读用一句话讲解；进 SPEAKABLE
 *
 * 渲染层注入：GraphicsBlock 渲染完成后，给目标元素打：
 *   - data-element-id="dgb-graphics-{id}"   ← G3 统一可寻址协议
 *   - data-graphics-node-id="{id}"          ← 业务可读
 *   - aria-label="{label}"                  ← 无障碍
 */
export const GraphicsNodeMetaSchema = z.object({
  id: IdSchema,
  selector: z.string().min(1).max(200).optional(),
  label: z.string().min(1).max(80).optional(),
  description: z.string().min(1).max(400).optional(),
});
export type GraphicsNodeMeta = z.infer<typeof GraphicsNodeMetaSchema>;

export const GraphicsBlockSchema = BlockBase.extend({
  kind: z.literal('graphics'),
  src: z.string().min(1),
  alt: z.string().optional(),
  caption: z.string().optional(),
  /** Phase G3 · 可寻址节点（可选；不填等价于 1.x 扁平 SVG） */
  nodes: z.array(GraphicsNodeMetaSchema).max(40).optional(),
  /** Phase G3 · 与 mermaid 同款讲解条（可选） */
  commentary: CommentarySpecSchema.optional(),
});
export type GraphicsBlock = z.infer<typeof GraphicsBlockSchema>;

export const QuizBlockSchema = BlockBase.extend({
  kind: z.literal('quiz'),
  ref: IdSchema,
});

/** 数字人附带的"常见问题" — UI 用作 FAQ 抽屉的卡片化展示（v3-rich+）。 */
export const FaqItemSchema = z.object({
  q: z.string().min(1),
  a: z.string().min(1),
});
export type FaqItem = z.infer<typeof FaqItemSchema>;

export const DigitalHumanBlockSchema = BlockBase.extend({
  kind: z.literal('digital-human'),
  script: z.string().min(1),
  voice: z.string().optional(),
  /** v3-rich · 本节常见问题；UI 优先展示 faq，script 退为口播兜底。
   *  v6.2 · 上限 8，与课程级 AiTutorConfig.faq 对齐（原 max 6 在注入 6+ 条
   *  知识型问答时会触发 schema 校验失败）。*/
  faq: z.array(FaqItemSchema).max(8).optional(),
  /** v4 · 数字人形象状态 */
  avatarState: z.enum(['idle', 'explaining', 'encouraging', 'questioning', 'correcting']).optional(),
  /** v4 · 是否默认开启 TTS */
  ttsEnabled: z.boolean().optional(),
  /** v4 · 问答范围 */
  ragScope: z.enum(['current-lesson', 'current-module', 'full-course']).optional(),
  /** v4 · 首次打开抽屉问候语 */
  welcomeMessage: z.string().optional(),
});

// ────────────────────────────────────────────────────────────
// v4 / Phase G2 · animation / video / quiz-intro-animation
// ────────────────────────────────────────────────────────────

export const AnimationTeacherSchema = z.object({
  script: z.string().min(1),
  voice: z.string().default('Cherry'),
  autoPlay: z.boolean().default(false),
  sceneId: z.string().optional(),
  steps: z.array(z.string().min(1)).optional(),
  stepScripts: z.array(z.string().min(1)).optional(),
});

/**
 * Phase G2 / ADR-0017 · 模板化动画规格（运行时模板路径）
 *
 * 当 AnimationBlock.format === 'html-svg' 且 metadata.template 非空时，
 * 渲染层走 TemplateAnimationRenderer（React 组件，inline SVG），跳过旧 inline HTML iframe 路径。
 *
 * 字段语义：
 *   - name   : 模板注册表中的键。未注册时 ErrorBoundary 退退到 fallback。
 *   - params : 模板专属配置；运行时由各模板组件自校验，schema 层只约束为 record。
 *   - nodes  : 复用 GraphicsNodeMetaSchema（同 G3 协议），渲染时注入
 *              data-element-id="dgb-anim-{id}"，朗读联动免费送（见 ADR-0016）。
 *
 * 红线：本字段全可选；旧 17 个 final 不填 → manifest 字节零变化 → sha256 不变。
 */
export const TemplateAnimationSpecSchema = z.object({
  name: z.enum([
    'signal-wave',     // 信号波形（时钟波、脉宽调制、串行时序等）
    'fsm',             // 有限状态机（协议处理、事件响应、状态转换等）
    // 第二批候选（保留枚举位，待第一批跑通后开实现）：
    'sequence-flow',
    'block-pipeline',
    'register-bitfield',
  ]),
  params: z.record(z.unknown()),
  nodes: z.array(GraphicsNodeMetaSchema).max(40).optional(),
});
export type TemplateAnimationSpec = z.infer<typeof TemplateAnimationSpecSchema>;


export const AnimationMetadataSchema = z.object({
  topic: z.string().min(1),
  coversLessons: z.array(IdSchema).optional(),
  duration: z.number().positive().optional(),
  interactive: z.boolean().default(false),
  engine: z.enum(['svg', 'threejs', 'manim', 'lottie', 'plugin']).optional(),
  teacher: AnimationTeacherSchema.optional(),
  /**
   * v5.x · 动画质量等级：
   *  - 'placeholder' — OpenMAIC 通用占位模板，未承载本节具体知识点（渲染时挂「动画重做中」提示条）
   *  - 'final'       — 已为该章节定制的真动画
   * 缺省视为 'final'（兼容老 manifest）。
   */
  quality: z.enum(['placeholder', 'final']).optional(),
  /**
   * v6 / G2 · ADR-0017 模板化动画规格。非空时渲染层走 TemplateAnimationRenderer。
   * 旧 17 个 final 不填该字段，manifest 字节零变化。
   */
  template: TemplateAnimationSpecSchema.optional(),
});
export type AnimationMetadata = z.infer<typeof AnimationMetadataSchema>;

export const AnimationBlockSchema = BlockBase.extend({
  kind: z.literal('animation'),
  src: z.string().min(1),
  /**
   * 动画来源类型（v4.1 扩展）：
   *  - lottie       : 外部 Lottie JSON
   *  - gif          : 外部 gif 图片
   *  - plugin       : 内置原语，src 形如 `dgb-anim:<name>`
   *  - html-svg     : 单文件 HTML+SVG（iframe sandbox）
   *  - html-threejs : Three.js 3D 场景（iframe + unpkg CDN）
   *  - video-mp4    : Manim 预渲染 MP4
   *  - video-webm   : Manim 预渲染 WebM
   *  - svg-inline   : 直接内联 SVG（无 iframe）
   */
  format: z.enum([
    'lottie', 'gif', 'plugin',
    'html-svg', 'html-threejs', 'html-canvas', 'video-mp4', 'video-webm', 'svg-inline',
  ]).default('lottie'),
  metadata: AnimationMetadataSchema.optional(),
});

/** v4.1 · 测验开场动画 */
export const QuizIntroBlockSchema = BlockBase.extend({
  kind: z.literal('quiz-intro-animation'),
  animationSrc: z.string().min(1),
  triggerIcon: z.string().min(1),
  quizRef: IdSchema,
  introType: z.enum(['experiment', 'circuit', 'logic', 'challenge', 'fun']).default('fun'),
});
export type QuizIntroBlock = z.infer<typeof QuizIntroBlockSchema>;

export const VideoBlockSchema = BlockBase.extend({
  kind: z.literal('video'),
  src: z.string().min(1),
  poster: z.string().optional(),
  caption: z.string().optional(),
});

// ────────────────────────────────────────────────────────────
// v4 · code / mindmap / experiment / summary / table / waveform
// ────────────────────────────────────────────────────────────

/** code-flow 单个 step（高亮窗口）*/
export const CodeFlowStepSchema = z.object({
  id: z.string().min(1),
  title: z.string().optional(),
  /** 该 step 激活时覆盖父 CodeBlock.highlightLines（行号 1-based）*/
  highlightLines: z.array(z.number().int().positive()).optional(),
});
export type CodeFlowStep = z.infer<typeof CodeFlowStepSchema>;

/** code-flow 流程图 + step 联动数据。
 *  source 是 mermaid DSL；steps 与 commentary.stepScripts 一一对应（粗 step 级同步）。*/
export const CodeFlowSpecSchema = z.object({
  format: z.literal('mermaid'),
  source: z.string().min(1),
  steps: z.array(CodeFlowStepSchema).max(20).optional(),
});
export type CodeFlowSpec = z.infer<typeof CodeFlowSpecSchema>;

/** v4 · 代码块 */
export const CodeBlockSchema = BlockBase.extend({
  kind: z.literal('code'),
  language: z.string().min(1),
  code: z.string().min(1),
  filename: z.string().optional(),
  highlightLines: z.array(z.number().int().nonnegative()).optional(),
  runnable: z.boolean().optional(),
  explanation: z.string().optional(),
  /** v6 · 代码讲解条（可选）—— 与 explanation 互补：
   *  explanation 是静态长文案（点击展开）；commentary 是字幕条 + TTS 阅读。*/
  commentary: CommentarySpecSchema.optional(),
  /** 可选流程图 + step 联动；存在时 CodeBlock 渲染双列 layout。*/
  flow: CodeFlowSpecSchema.optional(),
});

/** v4 · 思维导图 */
const MindmapNodeSchema: z.ZodType<{ text: string; children?: { text: string }[]; color?: string; icon?: string }> = z.object({
  text: z.string().min(1),
  children: z.lazy(() => z.array(MindmapNodeSchema)).optional(),
  color: z.string().optional(),
  icon: z.string().optional(),
});
export const MindmapBlockSchema = BlockBase.extend({
  kind: z.literal('mindmap'),
  root: MindmapNodeSchema,
});

/** v4 · 实验步骤 */
const ExperimentStepSchema = z.object({
  order: z.number().int().positive(),
  title: z.string().min(1),
  description: z.string().min(1),
  code: z.string().optional(),
  image: z.string().optional(),
  checkpoint: z.boolean().optional(),
});
export const ExperimentBlockSchema = BlockBase.extend({
  kind: z.literal('experiment'),
  title: z.string().min(1),
  steps: z.array(ExperimentStepSchema).min(1),
  expectedResult: z.string().optional(),
  troubleshooting: z.array(z.string()).optional(),
  /**
   * v6.12 · 实验环节的分段讲稿（ADR-0018 / commit 545878c）。
   *
   * extractSpeechFromBlock(experiment) 优先消费 commentary.stepScripts
   * （过滤空段后非空时使用）；缺省/全空时 fallback 为 title + steps + expectedResult
   * 拼成单段长字符串。
   *
   * 推荐形态：head + N steps + tail，长度通常为 steps.length + 2，
   * 不需要等于 steps.length（实验讲稿常多一段开场和总结）。
   *
   * 注意：若不在 schema 显式声明该字段，Zod 默认 .strip() 会在
   *      safeParseCourseManifest(raw) 时把 raw.commentary 移除，
   *      导致 player 实际拿到的 manifest 里 experiment.commentary === undefined，
   *      blockToSpeech.ts 的 v6.12 分段消费分支永远走不到。
   *      该字段必须保留以让 ADR-0018 行为在 player 真实路径生效。
   *
   * experiment 不参与 ADR-0016 节点级 highlight 对齐（experiment 没有 nodes/elementId 协议）。
   */
  commentary: CommentarySpecSchema.optional(),
});

/** v4 · 课后总结 */
export const SummaryBlockSchema = BlockBase.extend({
  kind: z.literal('summary'),
  keyPoints: z.array(z.string().min(1)).min(1),
  nextLessonId: z.union([IdSchema, z.literal('')]).optional(),
  reviewQuestions: z.array(z.string()).optional(),
});

/** v4 · 数据表格 */
export const TableBlockSchema = BlockBase.extend({
  kind: z.literal('table'),
  headers: z.array(z.string()).min(1),
  rows: z.array(z.array(z.string())),
  caption: z.string().optional(),
});

/** v4 · 时序/波形图 */
const SignalTraceSchema = z.object({
  name: z.string().min(1),
  color: z.string().min(1),
  data: z.array(z.union([z.literal(0), z.literal(1), z.number()])),
  type: z.enum(['digital', 'analog']),
});
export const WaveformBlockSchema = BlockBase.extend({
  kind: z.literal('waveform'),
  signals: z.array(SignalTraceSchema).min(1),
  timeScale: z.string().optional(),
  title: z.string().optional(),
});

// ────────────────────────────────────────────────────────────
// v4.4 · widget（OpenMAIC 互动 Widget 对标）
// ────────────────────────────────────────────────────────────

/**
 * v4.4 · 教师互动 Action（对标 OpenMAIC TeacherAction）
 * 用于 Widget 内部的互动控制：高亮元素、添加注解、揭示隐藏、设置状态
 */
export const WidgetTeacherActionSchema = z.object({
  id: z.string().min(1),
  type: z.enum(['speech', 'highlight', 'annotation', 'reveal', 'setState']),
  target: z.string().optional(),
  content: z.string().optional(),
  state: z.record(z.unknown()).optional(),
  label: z.string().optional(),
});
export type WidgetTeacherAction = z.infer<typeof WidgetTeacherActionSchema>;

/**
 * v4.4 · 互动 Widget Block（对标 OpenMAIC 5 种 WidgetType）
 * 自包含 HTML 在 iframe sandbox 中运行，通过 postMessage 与教师 Action 联动
 */
export const WidgetBlockSchema = BlockBase.extend({
  kind: z.literal('widget'),
  widgetType: z.enum(['simulation', 'diagram', 'code', 'game', 'visualization3d']),
  /** 自包含 HTML（直接嵌入 iframe srcDoc） */
  html: z.string().min(1),
  /** Widget 简短描述 */
  description: z.string().optional(),
  /** Widget 配置 JSON（嵌入 HTML 的 script#widget-config） */
  config: z.record(z.unknown()).optional(),
  /** 教师 Action 序列 */
  teacherActions: z.array(WidgetTeacherActionSchema).optional(),
});
export type WidgetBlock = z.infer<typeof WidgetBlockSchema>;

/* ============================================================
 * v5 · 文档风格组件套件
 * ──────────────────────────────────────────────────────────
 * 文档风格组件，用于提升内容呈现的专业性和可读性：
 *  - callout       : 侧边提示 / 注意框（信息/警告/成功/讲解）
 *  - info-table    : 两列信息表（引脚说明、寄存器位、名词对照）
 *  - principles    : 原则 / 要点卡片组（带序号）
 *  - figure-pair   : 并排双图（电路 vs 实物、波形 vs 代码）
 * 渲染器将其识别为 'content' zone，保持内容主区顺序。
 * =========================================================== */

/** v5 · 侧边提示框（与 primitives/CalloutBlock 对齐：intro/wrapup/tip/warning） */
export const CalloutBlockSchema = BlockBase.extend({
  kind: z.literal('callout'),
  calloutKind: z.enum(['intro', 'wrapup', 'tip', 'warning']).default('intro'),
  title: z.string().max(40).optional(),
  /** 嵌套白卡子标题（可选）。
   *  非空时渲染层套一层白底子卡片，把 emphasis 提到第二层语义重量。
   *  缺省时退回单层版式。*/
  subtitle: z.string().max(40).optional(),
  markdown: z.string().min(1),
});
export type CalloutBlock = z.infer<typeof CalloutBlockSchema>;

/** v5 · 两列信息表（label / value，tone 与 primitives/InfoTableBlock 对齐） */
export const InfoTableRowSchema = z.object({
  label: z.string().min(1),
  value: z.string().min(1),
  tone: z.enum(['primary', 'warm', 'neutral']).optional(),
});
export const InfoTableBlockSchema = BlockBase.extend({
  kind: z.literal('info-table'),
  title: z.string().max(40).optional(),
  intro: z.string().max(200).optional(),
  rows: z.array(InfoTableRowSchema).min(1).max(12),
});
export type InfoTableBlock = z.infer<typeof InfoTableBlockSchema>;

/** v5 · 原则 / 要点卡片组（带序号 numeral，通常是"三要三不要"之类） */
export const PrincipleItemSchema = z.object({
  numeral: z.string().max(4).optional(),
  title: z.string().min(1).max(40),
  content: z.string().min(1),
});
export const PrinciplesBlockSchema = BlockBase.extend({
  kind: z.literal('principles'),
  heading: z.string().max(40).optional(),
  items: z.array(PrincipleItemSchema).min(2).max(6),
  /** 卡片排版变体。
   *  - 'auto'（缺省）：自适应 grid
   *  - 'horizontal-numbered'：N ≤ 5 时强制 N 列等高编号卡
   *  6+ 项时 horizontal 自动回落 auto，避免文字溢出。*/
  layout: z.enum(['auto', 'horizontal-numbered']).optional(),
});
export type PrinciplesBlock = z.infer<typeof PrinciplesBlockSchema>;

/** v5 · 并排双图（电路 vs 实物、示意 vs 代码） */
export const FigurePairItemSchema = z.object({
  src: z.string().min(1),
  caption: z.string().optional(),
  alt: z.string().optional(),
});
export const FigurePairBlockSchema = BlockBase.extend({
  kind: z.literal('figure-pair'),
  items: z.array(FigurePairItemSchema).min(1).max(2),
});
export type FigurePairBlock = z.infer<typeof FigurePairBlockSchema>;

/* ============================================================
 * Phase G1 · mermaid 流程图 first-class（程序设计教学核心可视化）
 *
 * 设计原则：
 *   1. mermaid 源码原样保存，渲染层（packages/primitives/MermaidBlock）
 *      负责 mermaid.render() + 节点 svg 注入 data-element-id="dgb-mermaid-{nodeId}"
 *   2. nodes[] 是节点级元数据，让朗读串可以精确指向某个流程节点：
 *      - description 进 SPEAKABLE，朗读到节点时 ActionRunner 触发高亮
 *      - 节点 id 必须与 mermaid 源码内的 id 一致（如 graph TD; A[start] --> B[do]; 中的 A/B）
 *   3. 与 PageAction.highlight 联动：当 ActionRunner 走到某 action 时，
 *      可以指 target='dgb-mermaid-A' 触发 G3 SpotlightOverlay
 *
 * 与 mindmap 区别：
 *   - mermaid: 流程 / 状态机 / 时序（有方向、有条件分支、节点可寻址）
 *   - mindmap: 概念分解（树形，根→子，无方向语义）
 *
 * 兼容性：
 *   - 新增 kind，旧 manifest 不含 mermaid 块；MANIFEST_VERSION 不 bump
 *   - 旧播放器遇到此 kind 走 BlockSchema parse 失败的兜底逻辑
 */
export const MermaidNodeMetaSchema = z.object({
  /** mermaid 源码内的节点 id（如 'A' / 'B' / 'state_idle'） */
  id: IdSchema,
  /** 节点显示标签（用于 SPEAKABLE 抽取与 a11y） */
  label: z.string().min(1).max(80).optional(),
  /** 朗读这个节点时说什么；进 SPEAKABLE 红线统计 */
  description: z.string().min(1).max(400).optional(),
});
export type MermaidNodeMeta = z.infer<typeof MermaidNodeMetaSchema>;

export const MermaidBlockSchema = BlockBase.extend({
  kind: z.literal('mermaid'),
  /**
   * mermaid 源码（不含 ```mermaid 围栏）。
   * 例：'graph TD\n  A[初始化] --> B{按键?}\n  B -->|Yes| C[亮灯]\n  B -->|No| A'
   */
  source: z.string().min(1).max(8000),
  /**
   * mermaid 图类型（用于渲染层 fallback / 主题适配）。
   * 'auto' = 由 source 首行自动判定（默认）。
   */
  diagramType: z.enum([
    'auto',
    'flowchart',     // graph TD / flowchart LR
    'state',         // stateDiagram-v2
    'sequence',      // sequenceDiagram
    'class',         // classDiagram
    'er',            // erDiagram
    'gantt',         // 甘特图
  ]).default('auto'),
  /** 顶部标题（可选，渲染在图上方） */
  title: z.string().max(80).optional(),
  /** 节点级元数据（用于 SPEAKABLE + ActionRunner 高亮联动） */
  nodes: z.array(MermaidNodeMetaSchema).optional(),
  /** v6 · 通用讲解条（讲整张图的串场） */
  commentary: CommentarySpecSchema.optional(),
});
export type MermaidBlock = z.infer<typeof MermaidBlockSchema>;

/* ─────────────────────────────────────────────────────────────
 * Iter-34 / T3 · 数学公式 Block — KaTeX 渲染 LaTeX 源码
 *
 * 用途：理工科课程的核心公式专区（物理/数学/工程计算等）。
 *   示例：分压公式 V = (N × Vref) / 2^bits
 *         频率公式 f = f_clk / ((PSC+1) × (ARR+1))
 *              PWM 占空比 D = CCR / ARR
 *
 * 与 text 内 `$...$` markdown 数学的差异：
 *   - text 是文本流里的小公式
 *   - math block 是独立块级公式（display 模式）+ 标题 + 解释
 * ───────────────────────────────────────────────────────────── */

export const MathBlockSchema = BlockBase.extend({
  kind: z.literal('math'),
  /** LaTeX 源码（不含 $$ 围栏；display 模式渲染） */
  latex: z.string().min(1).max(2000),
  /** 公式标题（如"采样分压公式"） */
  title: z.string().max(80).optional(),
  /** 公式下方解释（如"N=采样读数 / Vref=参考电压 / bits=分辨率位数"） */
  caption: z.string().max(400).optional(),
  /** 是否行内（false=display 块级 / 默认 false） */
  inline: z.boolean().default(false),
});
export type MathBlock = z.infer<typeof MathBlockSchema>;

/* ─────────────────────────────────────────────────────────────
 * Iter-40 / D · Wokwi 元件 Block — 参数化电路三件套
 *
 * 与 graphics 的关键差异：
 *   - graphics  : src URL 指向静态 SVG 文件；可选 nodes[] 让 CSS 选择器定位
 *   - wokwi-element : 参数化数据驱动 React 组件渲染（color / value / pressed）
 *     不需要外部图片资源；运行时即时生成；视觉与 wokwi-elements 1.9.2 完全一致
 *
 * spec discriminated union（按 kind 区分）：
 *   - led        : value(发光) / brightness / color / lightColor / label / flip
 *   - resistor   : value（Ω 字符串或数字） / 自动按电子色码计算 3 色环
 *   - pushbutton : color / pressed / label / xray
 *
 * 三件套是 Iter-40 起步集；Iter-41+ 计划补：
 *   - oscilloscope（示波器，配合 waveform 块讲信号）
 *   - breadboard-mini（小面包板，配合 T-CL CircuitWiring 互动）
 *   - arduino-uno / esp32-devkit-v1（开发板示意图）
 *
 * 与 highlight 联动：渲染层注入 data-element-id="dgb-wokwi-{block.id}"，
 * 与 G3 SpotlightOverlay 协议一致（与 graphics / mermaid / animation 同款）。
 * ───────────────────────────────────────────────────────────── */

const WokwiLedSpecSchema = z.object({
  kind: z.literal('led'),
  value: z.boolean().optional(),
  brightness: z.number().min(0).max(1).optional(),
  color: z.string().min(1).max(20).optional(),
  lightColor: z.string().min(1).max(20).optional().nullable(),
  label: z.string().max(40).optional(),
  flip: z.boolean().optional(),
});

const WokwiResistorSpecSchema = z.object({
  kind: z.literal('resistor'),
  /** 电阻值（Ω）；可传字符串如 '4.7k' 解析失败时退回数值，或纯数字 */
  value: z.union([z.string().min(1).max(20), z.number().nonnegative()]).optional(),
});

const WokwiPushbuttonSpecSchema = z.object({
  kind: z.literal('pushbutton'),
  color: z.string().min(1).max(20).optional(),
  pressed: z.boolean().optional(),
  label: z.string().max(40).optional(),
  xray: z.boolean().optional(),
});

const WokwiBuzzerSpecSchema = z.object({
  kind: z.literal('buzzer'),
  hasSignal: z.boolean().optional(),
  frequency: z.number().int().min(0).max(20000).optional(),
  label: z.string().max(40).optional(),
});

const Wokwi7SegmentSpecSchema = z.object({
  kind: z.literal('7segment'),
  /** 显示字符（0-9 / A-F / '-' / ' '） */
  value: z.string().max(2).optional(),
  /** 是否点亮小数点 */
  dp: z.boolean().optional(),
  /** 颜色：red / green / blue / yellow / white */
  color: z.string().min(1).max(20).optional(),
});

const WokwiPotentiometerSpecSchema = z.object({
  kind: z.literal('potentiometer'),
  /** 当前转角值 0-100（百分比） */
  value: z.number().min(0).max(100).optional(),
  label: z.string().max(40).optional(),
});

const WokwiBreadboardMiniSpecSchema = z.object({
  kind: z.literal('breadboard-mini'),
  cols: z.number().int().min(5).max(30).optional(),
  rows: z.number().int().min(4).max(20).optional(),
});

const WokwiArduinoUnoSpecSchema = z.object({
  kind: z.literal('arduino-uno'),
  /** 高亮的引脚 ID（D0-D13 / A0-A5 / GND / 5V / 3V3 等） */
  highlightPin: z.string().max(10).optional(),
  label: z.string().max(40).optional(),
});

export const WokwiElementSpecSchema = z.discriminatedUnion('kind', [
  WokwiLedSpecSchema,
  WokwiResistorSpecSchema,
  WokwiPushbuttonSpecSchema,
  WokwiBuzzerSpecSchema,
  Wokwi7SegmentSpecSchema,
  WokwiPotentiometerSpecSchema,
  WokwiBreadboardMiniSpecSchema,
  WokwiArduinoUnoSpecSchema,
]);
export type WokwiElementSpec = z.infer<typeof WokwiElementSpecSchema>;

export const WokwiElementBlockSchema = BlockBase.extend({
  kind: z.literal('wokwi-element'),
  /** 三件套 spec（discriminated union） */
  spec: WokwiElementSpecSchema,
  /** 顶部小标题（可选；如"图 3-2 指示灯"） */
  title: z.string().max(80).optional(),
  /** 底部 caption（可选；功能 / 参数 / 说明） */
  caption: z.string().max(400).optional(),
});
export type WokwiElementBlock = z.infer<typeof WokwiElementBlockSchema>;

// ────────────────────────────────────────────────────────────
// 顶层 BlockSchema discriminated union（23 kind 联合）
// ────────────────────────────────────────────────────────────

export const BlockSchema = z.discriminatedUnion('kind', [
  TextBlockSchema,
  GraphicsBlockSchema,
  QuizBlockSchema,
  DigitalHumanBlockSchema,
  AnimationBlockSchema,
  VideoBlockSchema,
  InteractiveBlockSchema,
  // v4 · 新增 block kinds
  CodeBlockSchema,
  MindmapBlockSchema,
  ExperimentBlockSchema,
  SummaryBlockSchema,
  TableBlockSchema,
  WaveformBlockSchema,
  // v4.1 · 测验开场动画
  QuizIntroBlockSchema,
  // v4.4 · OpenMAIC 互动 Widget
  WidgetBlockSchema,
  // v5 · 文档风格组件（侧边提示 / 信息表 / 原则卡 / 双图）
  CalloutBlockSchema,
  InfoTableBlockSchema,
  PrinciplesBlockSchema,
  FigurePairBlockSchema,
  // Phase G1 · 流程图 first-class
  MermaidBlockSchema,
  // M10 · Finale Challenge 全屏游戏化挑战
  FinaleChallengeBlockSchema,

  MathBlockSchema,

  WokwiElementBlockSchema,
]);
export type Block = z.infer<typeof BlockSchema>;