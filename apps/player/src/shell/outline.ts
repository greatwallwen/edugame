/**
 * Outline 类型 + Shell SideNav / RightPanel 共享。
 *
 * 抽离自 Shell.tsx 内部 type，让子组件不必反向依赖 Shell。
 */
import type { CourseManifest } from '@dgbook/types';

export interface OutlineSection {
  id: string;
  title: string;
  pages: { id: string; title: string }[];
}

export interface OutlineNode {
  id: string;
  title: string;
  sections: OutlineSection[];
}

/**
 * 把 manifest 转为 SideNav 所需的 chapter→section→page 三级结构。
 *
 * 过滤 `appendix-*` 章（如元素画廊 appendix-gallery）：
 *   这类附录是开发/测试用的组件目录，不应污染正式课程目录与章节计数。
 *   仍可通过 ?page=gallery 直达，只是不在导航树里出现。
 */
export function manifestToOutline(m: CourseManifest): OutlineNode[] {
  return m.chapters
    .filter((ch) => !ch.id.startsWith('appendix-'))
    .map((ch) => ({
    id: ch.id,
    title: ch.title,
    sections: ch.sections.map((sec) => ({
      id: sec.id,
      title: sec.title,
      pages: sec.pages.map((p) => ({ id: p.id, title: p.title })),
    })),
  }));
}

export const LOADING_OUTLINE: OutlineNode[] = [
  { id: 'loading', title: '加载中…', sections: [{ id: 'loading-s', title: '请稍候', pages: [{ id: 'loading-p', title: '请稍候' }] }] },
];
