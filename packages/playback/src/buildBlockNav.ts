/**
 * buildBlockNav · 块级导航索引（平台底座 · 零课程内容）
 *
 * 从 page.actions 推导"内容块导航序列"：把每个 action 归属到一个 blockId，
 * 按 action 出现顺序得到去重的 block 顺序，并记录每个 block 的首个 action 下标。
 *
 * 用途：Shell 的「上一个 / 下一个内容块」与 ←/→ 键据此在 block 间前进后退——
 *   gotoBlock(k) → runner.seekTo(firstActionIndex[k])，从该 block 的首个 action
 *   连续播报（讲解 + 动画 step + 视频联动随之触发）。
 *
 * action → blockId 归属规则（与 generate_page_actions / resolveBlockIdFromElementId 协议一致）：
 *   - speak：优先 action.blockId 字段
 *   - play-video：targetId = dgb-block-{blockId}
 *   - spotlight / laser：targetId 反查（dgb-block-X / dgb-wokwi-X / dgb-anim-step-N / dgb-{kind}-{node}）
 *   - anim-step：归属"当前累积的最后一个 block"（动画 step 紧跟其 block）
 *
 * dgb-anim-step-N 这类"动画内部步进"不携带 blockId，归属到序列中最近的真实 block。
 */

import type { Page, PageAction } from '@dgbook/types';
import { resolveBlockIdFromElementId } from './resolveBlockIdFromElementId';

export interface BlockNavEntry {
  /** 内容块 id（dom 上是 data-element-id="dgb-block-{id}"） */
  blockId: string;
  /** 该 block 的首个 action 下标（seekTo 目标） */
  firstActionIndex: number;
}

export interface BlockNav {
  /** 去重后的 block 导航序列（按 action 顺序） */
  entries: BlockNavEntry[];
  /** blockId → 在 entries 中的下标 */
  indexOfBlock: Map<string, number>;
  /** actionIndex → 该 action 所属 block 在 entries 中的下标（用于反查当前块） */
  blockOfAction: number[];
}

/** 从单条 action 取它对应的 blockId（取不到返回 null）。 */
function blockIdOfAction(action: PageAction, page: Page): string | null {
  switch (action.type) {
    case 'speak':
      return (action as { blockId?: string }).blockId ?? null;
    case 'play-video':
      return resolveBlockIdFromElementId(action.targetId, page);
    case 'spotlight':
    case 'laser': {
      // dgb-anim-step-N 不携带 block 信息 → 交给调用方"继承上一个 block"
      if (/^dgb-anim-step-\d+$/.test(action.targetId)) return null;
      return resolveBlockIdFromElementId(action.targetId, page);
    }
    default:
      return null;
  }
}

export function buildBlockNav(page: Page | null | undefined): BlockNav {
  const entries: BlockNavEntry[] = [];
  const indexOfBlock = new Map<string, number>();
  const blockOfAction: number[] = [];
  const actions = (page?.actions ?? []) as ReadonlyArray<PageAction>;
  if (!page || actions.length === 0) {
    return { entries, indexOfBlock, blockOfAction };
  }

  let lastBlockEntryIdx = -1;
  actions.forEach((action, i) => {
    let bid = blockIdOfAction(action, page);
    if (bid === null) {
      // anim-step / 无归属 action → 继承当前最后一个 block
      blockOfAction[i] = lastBlockEntryIdx;
      return;
    }
    let entryIdx = indexOfBlock.get(bid);
    if (entryIdx === undefined) {
      entryIdx = entries.length;
      entries.push({ blockId: bid, firstActionIndex: i });
      indexOfBlock.set(bid, entryIdx);
    }
    lastBlockEntryIdx = entryIdx;
    blockOfAction[i] = entryIdx;
  });

  // 填补开头未归属的 action（继承其后第一个 block）
  for (let i = 0; i < blockOfAction.length; i++) {
    const v = blockOfAction[i];
    if (v === undefined || v < 0) {
      blockOfAction[i] = entries.length > 0 ? 0 : -1;
    }
  }

  return { entries, indexOfBlock, blockOfAction };
}

/** 给定当前 actionIndex（指向"还没执行的"，正播的是 actionIndex-1），返回当前 block 在 entries 中的下标。 */
export function currentBlockIndex(nav: BlockNav, actionIndex: number): number {
  if (nav.entries.length === 0) return -1;
  const playing = Math.max(0, actionIndex - 1);
  const idx = nav.blockOfAction[Math.min(playing, nav.blockOfAction.length - 1)];
  return idx === undefined ? -1 : idx;
}
