/**
 * @dgbook/types · Quiz schema（M3 / Iter-35 拆分自 manifest.ts）
 *
 * 4 种 quiz 题型 + 顶层 QuizSpecSchema discriminated union。
 *
 * 与 InteractiveSpec 的边界：
 *   - QuizSpec 是 课程级题库（CourseManifest.quizzes 表），多个 QuizBlock 通过 ref 引用
 *   - InteractiveSpec 是 page 内嵌互动模块，无 ref 机制
 *
 * v3-rich 起 Quiz 的 4 种题型："single-choice" / "multiple-choice" / "fill-blank" / "true-false"。
 */

import { z } from 'zod';
import { IdSchema } from './manifest-core';

export const QuizOptionSchema = z.object({
  id: IdSchema,
  label: z.string().min(1),
});
export type QuizOption = z.infer<typeof QuizOptionSchema>;

export const SingleChoiceQuizSchema = z.object({
  id: IdSchema,
  kind: z.literal('single-choice'),
  stem: z.string().min(1),
  options: z.array(QuizOptionSchema).min(2),
  answer: IdSchema,
  explanation: z.string().optional(),
});

export const MultipleChoiceQuizSchema = z.object({
  id: IdSchema,
  kind: z.literal('multiple-choice'),
  stem: z.string().min(1),
  options: z.array(QuizOptionSchema).min(2),
  answer: z.array(IdSchema).min(1),
  explanation: z.string().optional(),
});

export const FillBlankQuizSchema = z.object({
  id: IdSchema,
  kind: z.literal('fill-blank'),
  stem: z.string().min(1),
  /** 填空占位符，如 "___" 或 "{{blank}}" */
  placeholder: z.string().default('___'),
  /** 正确答案列表（支持多个可接受答案） */
  answers: z.array(z.string().min(1)).min(1),
  /** 是否区分大小写 */
  caseSensitive: z.boolean().default(false),
  explanation: z.string().optional(),
});

export const TrueFalseQuizSchema = z.object({
  id: IdSchema,
  kind: z.literal('true-false'),
  stem: z.string().min(1),
  /** true 或 false */
  answer: z.boolean(),
  explanation: z.string().optional(),
});

export const QuizSpecSchema = z.discriminatedUnion('kind', [
  SingleChoiceQuizSchema,
  MultipleChoiceQuizSchema,
  FillBlankQuizSchema,
  TrueFalseQuizSchema,
]);
export type QuizSpec = z.infer<typeof QuizSpecSchema>;
