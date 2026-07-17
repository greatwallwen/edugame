/**
 * @dgbook/renderer · 页模板 + 原语分发
 *
 * M3 起实装 PageRenderer（按 page.template 外层 + 按 block.kind 分发原语）。
 * 待补里程碑：
 *   - T-mindmap 真实思维导图（M5+）
 *   - Plugin 沙盒 iframe（给 Animation.kind=plugin 用）
 */

export { PageRenderer, type PageRendererProps } from './PageRenderer';
export { SceneViewer } from './SceneViewer';
export { BlockRegistry, InteractiveRegistry } from './BlockRegistry';
export type { BlockRenderer, InteractiveRenderer, BlockRendererProps, InteractiveRendererProps } from './BlockRegistry';

export const PAGE_TEMPLATES = [
  'T-concept',
  'T-mindmap',
  'T-demo',
  'T-practice',
] as const;

export type PageTemplate = (typeof PAGE_TEMPLATES)[number];
