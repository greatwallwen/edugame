/**
 * resolveBlockIdFromElementId · Iter-42 Step 1a
 *
 * 把 spotlight elementId 反查到所属 block.id，让 PageActionRunner.spotlight
 * 也能驱动 setActiveBlockId → AnimatedBlockWrap CSS spotlight + scrollIntoView。
 *
 * elementId 协议（与 packages/primitives 渲染层一致）：
 *   - dgb-block-{id}      整段 block 兜底
 *   - dgb-wokwi-{id}      Wokwi 元件 block
 *   - dgb-graphics-{node} graphics block 内 SVG 节点
 *   - dgb-mermaid-{node}  mermaid block 内节点
 *   - dgb-anim-{node}     animation block 内 SVG 节点
 *
 * 反查策略：
 *   - dgb-block-X / dgb-wokwi-X：X 直接是 block.id
 *   - dgb-graphics-N / dgb-mermaid-N / dgb-anim-N：扫 page.blocks 找
 *     b.kind===kind && b.nodes 含 nodes.id===N，取 b.id
 *
 * 找不到返回 null，调用方 short-circuit（不动 activeBlockId）。
 */

import type { Page } from '@dgbook/types';

/** 单个 block 内的 nodes 引用（graphics / mermaid / animation 等共用结构） */
interface NodeBearingBlock {
  id: string;
  kind: string;
  nodes?: Array<{ id: string }>;
}

export function resolveBlockIdFromElementId(
  elementId: string | null | undefined,
  page: Page | undefined | null,
): string | null {
  if (!elementId || !page) return null;

  // 整段 block 兜底
  if (elementId.startsWith('dgb-block-')) {
    return elementId.slice('dgb-block-'.length) || null;
  }

  // Wokwi block：dgb-wokwi-{block.id}
  if (elementId.startsWith('dgb-wokwi-')) {
    return elementId.slice('dgb-wokwi-'.length) || null;
  }

  // 节点级：在 page.blocks 中找 nodes 包含目标 id 的 block
  const probes: Array<[string, string]> = [
    ['dgb-graphics-', 'graphics'],
    ['dgb-mermaid-', 'mermaid'],
    ['dgb-anim-', 'animation'],
  ];
  for (const [prefix, kind] of probes) {
    if (!elementId.startsWith(prefix)) continue;
    const nodeId = elementId.slice(prefix.length);
    if (!nodeId) return null;
    for (const b of page.blocks as NodeBearingBlock[]) {
      if (b.kind !== kind) continue;
      if (Array.isArray(b.nodes) && b.nodes.some((n) => n.id === nodeId)) {
        return b.id;
      }
    }
    // 节点找不到所属 block：fail-soft
    return null;
  }

  return null;
}
