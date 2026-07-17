/**
 * @dgbook/types · Page / Chapter / CourseManifest 顶层结构（Iter-35 / T-2 拆分自 manifest.ts）
 *
 * 这一层是 manifest 的"顶层骨架"：
 *   - Page / Section / Chapter / CourseManifest 嵌套树
 *   - Theme / AiTutorConfig / CourseBlueprint / AchievementDef / ReportTemplate
 *   - LessonMeta / PageSource / TeachingScene / LessonHeroBanner
 *   - AbilityMap（教育部"课程能力图谱"政策）
 *   - parseCourseManifest / safeParseCourseManifest 入口
 *
 * 模块依赖：
 *   - manifest-core    : MANIFEST_VERSION / IdSchema
 *   - manifest-block   : BlockSchema（PageSchema.blocks 数组元素类型）
 *   - manifest-quiz    : QuizSpecSchema（CourseManifest.quizzes 题库表元素类型）
 *   - manifest-block   : FaqItemSchema（AiTutorConfig.faq 数组元素类型）
 *   - action           : PageActionsSchema（PageSchema.actions design-only 字段）
 */

import { z } from 'zod';
import { MANIFEST_VERSION, IdSchema, PageTemplate } from './manifest-core';
import { BlockSchema, FaqItemSchema } from './manifest-block';
import { QuizSpecSchema } from './manifest-quiz';
import { PageActionsSchema } from './action';

/** v4 · 进度规则（每课检查点） */
export const ProgressRuleSchema = z.object({
  id: IdSchema,
  type: z.enum(['read', 'experiment-step', 'quiz-pass', 'interactive-complete']),
  description: z.string().min(1),
  threshold: z.number().min(0).max(100).optional(), // quiz-pass 时最低分
});
export type ProgressRule = z.infer<typeof ProgressRuleSchema>;

/** v4 · Lesson 元数据 */
export const LessonMetaSchema = z.object({
  objectives: z.array(z.string().min(1)).min(1),
  prerequisites: z.array(IdSchema).optional(),
  estimatedMinutes: z.number().positive().optional(),
  difficulty: z.enum(['beginner', 'intermediate', 'advanced']).optional(),
  tags: z.array(z.string()).optional(),
  progressRules: z.array(ProgressRuleSchema).optional(),
  achievementHooks: z.array(IdSchema).optional(),
  experimentMaterials: z.array(z.string()).optional(),
});
export type LessonMeta = z.infer<typeof LessonMetaSchema>;

/** Phase B · 页源溯源（N5 可追溯）：让任何 AI 输出可链回原始 chunk。
 *  所有字段可选；旧 manifest 不带此对象时，UI 不显示「源 · pXX」按钮。 */
export const PageSourceSchema = z.object({
  /** 生成器内部使用的 chunk key，例如 'COURSE-ISBN-p012-p015' */
  pageSourceKey: z.string().optional(),
  /** 该 page 引用的原 PDF 物理页码列表 */
  pageNumbers: z.array(z.number().int().positive()).optional(),
  /** 原始 markdown chunk 文本（用于学生/审核者点击「源」按钮查看） */
  markdown: z.string().optional(),
});
export type PageSource = z.infer<typeof PageSourceSchema>;

/**
 * v4.3 · 教学场景（对标 OpenMAIC Scene.actions[] 机制）
 * 每个教学场景包含：
 * - items: 幻灯片式要点列表（对标 OpenMAIC slide elements）
 * - actions: 教学动作序列（对标 OpenMAIC ActionEngine）
 *   - spotlight: 高亮某个要点
 *   - speech: 朗读讲解文字（底栏打字机 + BlockPlaybackEngine）
 * N1安全：纯结构化数据，无课程特定逻辑
 */
export const TeachingSceneItemSchema = z.object({
  id: IdSchema,
  /** 展示类型：标题/要点/高亮结论/代码 */
  type: z.enum(['title', 'point', 'highlight', 'code']),
  /** 主文字（简短，对标 OpenMAIC slide content） */
  text: z.string().min(1),
  /** 补充说明（可选，对标 OpenMAIC notes panel） */
  note: z.string().optional(),
  /** 代码语言（type=code 时使用） */
  lang: z.string().optional(),
  /** 分组标签（可选，用于左右栏布局） */
  group: z.string().optional(),
  /** 颜色标记 */
  color: z.string().optional(),
});
export type TeachingSceneItem = z.infer<typeof TeachingSceneItemSchema>;

export const TeachingSceneActionSchema = z.discriminatedUnion('type', [
  z.object({ type: z.literal('spotlight'), itemId: IdSchema }),
  z.object({ type: z.literal('speech'), text: z.string().min(1) }),
  // v4.4 · Widget 互动 Action（对标 OpenMAIC widget_highlight/setState/annotation/reveal）
  z.object({ type: z.literal('highlight'), target: z.string().min(1), duration: z.number().optional() }),
  z.object({ type: z.literal('annotation'), target: z.string().min(1), content: z.string().min(1) }),
  z.object({ type: z.literal('reveal'), target: z.string().min(1) }),
  z.object({ type: z.literal('setState'), state: z.record(z.unknown()) }),
]);
export type TeachingSceneAction = z.infer<typeof TeachingSceneActionSchema>;

export const TeachingSceneSchema = z.object({
  /** 场景标题（对标 OpenMAIC Scene.title） */
  title: z.string().min(1),
  /** 要点列表（对标 OpenMAIC slide elements） */
  items: z.array(TeachingSceneItemSchema).min(1),
  /** 讲解动作序列（对标 OpenMAIC Scene.actions） */
  actions: z.array(TeachingSceneActionSchema).min(1),
});
export type TeachingScene = z.infer<typeof TeachingSceneSchema>;

/**
 * v5 · 教材页眉条（可选）
 * 用于 T-concept 页头替代默认 LessonBanner，渲染一条"课堂·任务·学时"条幅。
 * brand 是课程/章节品牌短语（例如"STM32F103"）；
 * kind 用来区分导入 / 讲授 / 实训等阶段；
 * duration 是估算学时（分钟/课时，按习惯约定）。
 */
export const LessonHeroBannerSchema = z.object({
  title: z.string().min(1).max(80),
  eyebrow: z.string().max(30).optional(),
  subtitle: z.string().max(160).optional(),
  brand: z.string().max(30).optional(),
  heroImage: z.string().optional(),
  /** 阶段标签文字（'课时' / '导入' / '讲授' / '实训' / '回顾' 等，任意短文本） */
  kind: z.string().max(12).optional(),
  duration: z.string().max(20).optional(),
});
export type LessonHeroBanner = z.infer<typeof LessonHeroBannerSchema>;


export const PageGameModeId = z.enum([

  'bit-flip-quest',
  'pin-rush',
  'signal-surfer',
  'circuit-builder',
  'interrupt-defender',
  'quick-hit',
  'memory-card',
  'drag-match',
  'sort-flow',
  'card-battle',
  'match-3',
  'boss-review',
  'quiz-rush',
  'pipe-connect',
  'device-assemble',
  'maze-troubleshoot',
  'tower-defense',
  '2048-merge',
  'minesweeper-risk',
  'rhythm-tap',
  'timeline-build',
  'case-detective',
  'knowledge-map',
  'repair-sim',
  'lab-procedure',
  'classification-run',
  'resource-management',
  'scenario-choice',
  'checkpoint-adventure',
  'godot-game',
]);
export type PageGameModeId = z.infer<typeof PageGameModeId>;

export const PageGameSpecSchema = z.object({
  modeId: PageGameModeId,
  levelId: z.string().min(1),
  title: z.string().min(1),
  objective: z.string().min(1),
  difficulty: z.union([
    z.literal(1),
    z.literal(2),
    z.literal(3),
    z.literal(4),
    z.literal(5),
  ]),
  starThresholds: z.tuple([
    z.number().min(0).max(100),
    z.number().min(0).max(100),
    z.number().min(0).max(100),
  ]),
  timeLimit: z.number().min(0),
  data: z.record(z.unknown()).default({}),
  /** EduGame 出现在 page 末尾，作为"课后练习"卡片入口（默认 true） */
  gateAfterPageActions: z.boolean().optional(),
  /** 通关后写入学习进度（影响目录的"已学"标记） */
  rewardOnComplete: z
    .object({
      stars: z.union([z.literal(1), z.literal(2), z.literal(3)]),
      visitedFlag: z.boolean(),
    })
    .optional(),
});
export type PageGameSpec = z.infer<typeof PageGameSpecSchema>;

export const PageSchema = z.object({
  id: IdSchema,
  title: z.string().min(1),
  template: PageTemplate,
  blocks: z.array(BlockSchema).min(1),
  /** v4 · lesson 元数据（可选，旧播放器忽略） */
  lesson: LessonMetaSchema.optional(),
  /** Phase B · 源溯源（N5）。 */
  source: PageSourceSchema.optional(),
  /** v4.3 · OpenMAIC 风格教学场景（可选，有则启用交互动画讲解） */
  scene: TeachingSceneSchema.optional(),
  /** v5 · 教材化页眉条（可选；有则替换默认 LessonBanner） */
  lessonHero: LessonHeroBannerSchema.optional(),
  /** v4.5 · page 级 Action 编排（design-only；运行时未启用） */
  actions: PageActionsSchema.optional(),
  /** EduGame 课后练习挂载（可选） */
  game: PageGameSpecSchema.optional(),
});
export type Page = z.infer<typeof PageSchema>;

export const SectionSchema = z.object({
  id: IdSchema,
  title: z.string().min(1),
  pages: z.array(PageSchema).min(1),
});
export type Section = z.infer<typeof SectionSchema>;

export const ChapterSchema = z.object({
  id: IdSchema,
  title: z.string().min(1),
  sections: z.array(SectionSchema).min(1),
});
export type Chapter = z.infer<typeof ChapterSchema>;

/** 视觉主题变体：
 *  - light       : 默认通用浅色
 *  - chip-light  : 嵌入式浅色（保 PCB 质感、底色亮、护眼）
 *  - chip-dark   : 嵌入式深色（青绿光感、等宽辅字、PCB 网格底纹）
 *  - textbook    : 纸质教材风（墨绿 + 米黄 + 白卡；对齐高职 STM32 教材视觉） */
export const ThemeVariant = z.enum(['light', 'chip-light', 'chip-dark', 'textbook']);
export type ThemeVariant = z.infer<typeof ThemeVariant>;

export const ThemeSchema = z.object({
  primary: z
    .string()
    .regex(/^#[0-9a-fA-F]{6}$/, 'primary must be a hex color #RRGGBB')
    .default('#4F7DFF'),
  variant: ThemeVariant.default('light'),
  /** v4.1 · 顶栏品牌名（接入方可注入；缺省回退到 'DG · 数字教材'） */
  brandName: z.string().max(32).optional(),
  /** v4.1 · 顶栏品牌副标题（缺省不显示） */
  brandSubtitle: z.string().max(32).optional(),
});
export type Theme = z.infer<typeof ThemeSchema>;

/** v4.1 · AI 助教顶层配置（与 DigitalHumanBlock 内的 faq 区分：此处是课程级常驻 FAQ）。 */
export const AiTutorConfigSchema = z.object({
  /** 助教名称；缺省 '课程助教' */
  name: z.string().max(16).optional(),
  /** v5 · 助教副标题（角色/场景，例如"随堂问答 · 课堂伙伴"） */
  subtitle: z.string().max(24).optional(),
  /** v5 · 助教头像 emoji（例如 📘 / 🎓 / 🤖）；无则回退到姓名首字 */
  avatarEmoji: z.string().max(4).optional(),
  /** 首次打开的欢迎语 */
  welcome: z.string().max(200).optional(),
  /** 课程级快捷提问（数据驱动，无则不渲染快捷区） */
  faq: z.array(FaqItemSchema).max(8).optional(),
});
export type AiTutorConfig = z.infer<typeof AiTutorConfigSchema>;

/** v4 · 课程蓝图 */
const ModuleBlueprintSchema = z.object({
  id: IdSchema,
  title: z.string().min(1),
  description: z.string().min(1),
  lessonIds: z.array(IdSchema).min(1),
  estimatedMinutes: z.number().positive().optional(),
  difficulty: z.enum(['beginner', 'intermediate', 'advanced']).optional(),
  tags: z.array(z.string()).optional(),
});

export const CourseBlueprintSchema = z.object({
  targetAudience: z.string().min(1),
  prerequisites: z.array(z.string()).optional(),
  learningObjectives: z.array(z.string().min(1)).min(1),
  totalEstimatedMinutes: z.number().positive().optional(),
  modules: z.array(ModuleBlueprintSchema).min(1),
});
export type CourseBlueprint = z.infer<typeof CourseBlueprintSchema>;

/** v4 · 成就定义 */
export const AchievementConditionSchema = z.discriminatedUnion('type', [
  z.object({ type: z.literal('lesson-complete'), lessonId: IdSchema }),
  z.object({ type: z.literal('quiz-perfect'), quizId: IdSchema }),
  z.object({ type: z.literal('interactive-complete'), interactiveId: IdSchema }),
  z.object({ type: z.literal('streak-days'), days: z.number().int().positive() }),
  z.object({ type: z.literal('module-complete'), moduleId: IdSchema }),
  z.object({ type: z.literal('custom'), predicate: z.string().min(1) }),
]);

export const AchievementDefSchema = z.object({
  id: IdSchema,
  name: z.string().min(1),
  description: z.string().min(1),
  icon: z.string().min(1),
  condition: AchievementConditionSchema,
});
export type AchievementDef = z.infer<typeof AchievementDefSchema>;

/** v4 · 报告模板 */
export const ReportSectionSchema = z.object({
  type: z.enum(['progress-overview', 'quiz-summary', 'weak-points', 'time-analysis', 'achievement-list', 'recommendation']),
  title: z.string().min(1),
  config: z.record(z.unknown()).optional(),
});

export const ReportTemplateSchema = z.object({
  id: IdSchema,
  name: z.string().min(1),
  sections: z.array(ReportSectionSchema).min(1),
});
export type ReportTemplate = z.infer<typeof ReportTemplateSchema>;

/** v4.2 · 能力图谱 — 对应教育部"课程能力图谱"要求（教职成〔2026〕1号） */
const AbilityDimensionSchema = z.object({
  id: IdSchema,
  name: z.string().min(1),           // 如"GPIO控制能力"
  level: z.enum(['基础', '进阶', '综合']),
  skills: z.array(z.string()),       // 技能指标列表
  knowledge: z.array(z.string()),    // 知识支撑列表
  pageIds: z.array(IdSchema),        // 关联页面 id
});
export type AbilityDimension = z.infer<typeof AbilityDimensionSchema>;

export const AbilityMapSchema = z.object({
  dimensions: z.array(AbilityDimensionSchema),
});
export type AbilityMap = z.infer<typeof AbilityMapSchema>;

export const CourseManifestSchema = z.object({
  manifestVersion: z.literal(MANIFEST_VERSION),
  courseId: IdSchema,
  title: z.string().min(1),
  generatedAt: z.string().datetime(),
  theme: ThemeSchema.default({ primary: '#4F7DFF', variant: 'light' }),
  chapters: z.array(ChapterSchema).min(1),
  /** 题库：QuizBlock.ref 查此表。向前兼容：未带则视为 {}。 */
  quizzes: z.record(IdSchema, QuizSpecSchema).default({}),
  // v4 · 可选顶层扩展
  blueprint: CourseBlueprintSchema.optional(),
  achievements: z.record(IdSchema, AchievementDefSchema).optional(),
  reportTemplates: z.array(ReportTemplateSchema).optional(),
  // v4.1 · AI 助教课程级配置（数据驱动 chrome 区域）
  aiTutor: AiTutorConfigSchema.optional(),
  // v4.2 · 课程能力图谱（政策：教职成〔2026〕1号 第二条（二））
  abilityMap: AbilityMapSchema.optional(),
  /** 领域术语词典（AI 助教追问建议 + FAQ 派生用） */
  domainTerms: z.array(z.object({
    term: z.string().min(1),
    kind: z.string().min(1),
  })).optional(),
  /** 追问模板函数（按 kind 分流的问句模板） */
  followUpTemplates: z.array(z.object({
    kind: z.string().min(1),
    template: z.string().min(1),
  })).optional(),
  /** 代码高亮扩展词（注入到 CodeBlock 的 KEYWORDS/BUILTINS） */
  codeHighlightExtras: z.object({
    keywords: z.record(z.string(), z.array(z.string())).optional(),
    builtins: z.record(z.string(), z.array(z.string())).optional(),
  }).optional(),
});
export type CourseManifest = z.infer<typeof CourseManifestSchema>;

export function parseCourseManifest(raw: unknown): CourseManifest {
  return CourseManifestSchema.parse(raw);
}

export function safeParseCourseManifest(raw: unknown) {
  return CourseManifestSchema.safeParse(raw);
}
