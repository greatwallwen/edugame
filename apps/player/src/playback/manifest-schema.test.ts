/**
 * manifest-schema.test.ts · manifest 全量 zod 校验（构建期守门）
 *
 * 根治 Iter-52/53 踩过的"schema 字段错误致整站 manifest 加载失败"——
 * 把 public/manifest.json 用 @dgbook/types 的 zod schema 完整解析一遍，
 * 任何非法字段（如 hotspot.image 空串、engine 枚举错）在 `pnpm test` 即暴露，
 * 不必等部署后 Playwright 才发现整站白屏。
 *
 * 用 vite 的 JSON import（零 node 内置模块依赖，tsc -b 也能编译）。
 */
import { describe, it, expect } from 'vitest';
import { safeParseCourseManifest } from '@dgbook/types';
import manifest from '../../public/manifest.json';

describe('manifest.json schema', () => {
  it('通过 CourseManifest zod 校验（含全部互动题型 spec）', () => {
    const result = safeParseCourseManifest(manifest);
    if (!result.success) {
      const top = result.error.issues.slice(0, 10)
        .map((i) => `${i.path.join('.')}: ${i.message}`)
        .join('\n');
      throw new Error(`manifest 非法字段（前 10 条）：\n${top}`);
    }
    expect(result.success).toBe(true);
  });
});
