/**
 * @dgbook/types · Finale Challenge schema（M10 / Iter-35 拆分自 manifest.ts）
 *
 * 全屏游戏化挑战 block：闯关 + Boss 战。
 *
 * 结构：FinaleChallenge → stages[] → questions[] → spec(InteractiveSpec | QuizSpec)
 *
 * 关键点：
 *   - 复用 InteractiveSpecSchema（9 题型）+ QuizSpecSchema（4 题型）
 *   - bossStageIndex 标记的 stage 走 Boss 流程（双倍计分 / 心跳 BGM）
 *   - HP / combo / timer 三件套是组件级状态，schema 里只保留 hpMax / timeLimitSec / passThreshold
 *   - 公式见 .dgbook/design/finale-challenge-game-spec.md §5.1
 *
 * Iter-35 拆分注：
 *   原 manifest.ts 在同一文件内通过 z.lazy(() => QuizSpecSchema) 解决前向引用；
 *   T-2 拆分后 QuizSpecSchema 已在另一文件，改为直接 import 即可（不再前向）。
 *   保留 z.lazy(...) 是为了让 zod 在序列化 / generate JSON Schema 时仍走懒求值路径，
 *   行为完全等价，但避免触发"discriminatedUnion 在 module evaluation 阶段读取 undefined"陷阱。
 */

import { z } from 'zod';
import { BlockBase, IdSchema } from './manifest-core';
import { InteractiveSpecSchema } from './manifest-interactive';
import { QuizSpecSchema } from './manifest-quiz';

export const FinaleQuestionSpecSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('interactive'),
    /** 复用现有 9 种 interactive 题型 */
    data: InteractiveSpecSchema,
  }),
  z.object({
    type: z.literal('quiz'),
    /** 复用现有 4 种 quiz 题型；仍走 z.lazy 形态保持与原 manifest 行为一致 */
    data: z.lazy(() => QuizSpecSchema),
  }),
]);
export type FinaleQuestionSpec = z.infer<typeof FinaleQuestionSpecSchema>;

export const FinaleQuestionSchema = z.object({
  id: IdSchema,
  spec: FinaleQuestionSpecSchema,
  /** 题目基础分（计分公式 questionScore） */
  scoreBase: z.number().int().positive().default(100),
  difficulty: z.enum(['easy', 'medium', 'hard']).default('easy'),
  /** 提示文案（可选；答错若干次后弹出） */
  hint: z.string().max(200).optional(),
});
export type FinaleQuestion = z.infer<typeof FinaleQuestionSchema>;

export const FinaleStageSchema = z.object({
  id: IdSchema,
  title: z.string().min(1).max(60),
  subtitle: z.string().max(120).optional(),
  questions: z.array(FinaleQuestionSchema).min(1).max(8),
  /** 单关倒计时（秒） */
  timeLimitSec: z.number().int().positive().default(60),
  /** 0~1，过关分数比例（达不到也不强制阻断，只影响段位） */
  passThreshold: z.number().min(0).max(1).default(0.6),
});
export type FinaleStage = z.infer<typeof FinaleStageSchema>;

export const FinaleChallengeBlockSchema = BlockBase.extend({
  kind: z.literal('finale-challenge'),
  /** 挑战标题（HUD + 入口卡显示） */
  title: z.string().min(1).max(80),
  /** 入场旁白 / 副标题 */
  intro: z.string().max(240).optional(),
  /** 关卡序列（建议 3-5 关；最后一关默认为 Boss） */
  stages: z.array(FinaleStageSchema).min(1).max(8),
  /** Boss 关索引；缺省 = stages.length - 1（最后一关） */
  bossStageIndex: z.number().int().nonnegative().optional(),
  /** HP 上限；缺省 3 */
  hpMax: z.number().int().positive().max(10).default(3),
  /** BGM 主题；缺省 'tense' */
  bgmTrack: z.enum(['tense', 'epic', 'calm']).default('tense'),
  /** 入口卡文案（点击展开全屏挑战） */
  triggerLabel: z.string().max(40).optional(),
  /** 入口卡图标 emoji；缺省 🏆 */
  triggerIcon: z.string().max(8).optional(),
  /**
   * 课后总结合并方案 B
   *   summaryPoints：原 page-level summary 的 4 条要点（中文短句，每条 ≤120）
   *   summaryUnlockMap：stageId → 该关通关时解锁的 summary index 列表
   *   - 玩家完成普通 stage 后进入 stage-debrief 卡，按 unlockMap 渐进显现要点
   *   - 进 Boss 前累计 review 已解锁要点；result 页一次性展示完整 summaryPoints
   *   - 缺省时 finale 仍可正常工作（兼容现有不传 summary 的页面）
   */
  summaryPoints: z.array(z.string().min(1).max(160)).max(8).optional(),
  summaryUnlockMap: z.record(z.string(), z.array(z.number().int().nonnegative())).optional(),
});
export type FinaleChallengeBlock = z.infer<typeof FinaleChallengeBlockSchema>;
