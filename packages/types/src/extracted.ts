import { z } from 'zod';

/**
 * Extracted 层产物契约（M4 起）。
 *
 * 设计原则：
 * - 与 `CourseManifest` 完全解耦。Manifest 是给 player 看的产物；
 *   ExtractedIndex 是"工厂中间件"——generator / 未来的 RAG 建库器都读它。
 * - 只描述元信息（文件名、页数、markdown 相对路径），不嵌正文；正文落磁盘
 *   `extracted/<file>/markdown.md`，避免 index.json 膨胀。
 * - 版本字段便于上下线兼容；M4 固定为 1。
 */
export const EXTRACTED_INDEX_VERSION = 1 as const;

export const ExtractedSourceType = z.enum(['pdf', 'docx', 'pptx']);
export type ExtractedSourceType = z.infer<typeof ExtractedSourceType>;

export const ExtractedFileSchema = z.object({
  /** 原始文件相对路径，基于 `materials/<id>/`。例如 `raw/pdfs/sample.pdf`。 */
  sourcePath: z.string().min(1),
  /** 抽取源类型（M4 只实现 pdf，docx/pptx 留 schema 位）。 */
  sourceType: ExtractedSourceType,
  /** 人读标题（PDF metadata 或文件名兜底）。 */
  title: z.string().min(1),
  /** 页数；非分页源（未来 docx）可为 1。 */
  pages: z.number().int().min(1),
  /** markdown 产物相对路径（基于 `materials/<id>/`）。每源一份。 */
  markdownPath: z.string().min(1),
  /**
   * M5 起：按页切分的 markdown 相对路径列表（与 pages 对齐，`p01.md`...）。
   * 向前兼容：M4 产的 index 无此字段，generator 侧看到 undefined 则走原
   * `markdownPath` 单文件路径，LLM 分页调用时按 `## 第 N 页` 正则切。
   */
  pageMarkdownPaths: z.array(z.string().min(1)).optional(),
});
export type ExtractedFile = z.infer<typeof ExtractedFileSchema>;

export const ExtractedIndexSchema = z.object({
  indexVersion: z.literal(EXTRACTED_INDEX_VERSION),
  courseId: z.string().min(1),
  extractedAt: z.string().datetime(),
  /** 本次抽取器版本标记（便于排障）。 */
  extractor: z.string().min(1),
  files: z.array(ExtractedFileSchema),
});
export type ExtractedIndex = z.infer<typeof ExtractedIndexSchema>;
