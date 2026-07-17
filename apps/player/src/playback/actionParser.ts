/**
 * actionParser — 把 LLM 输出的"交错 JSON 数组"解析成 PageAction[]（Iter-37）
 *
 * 与 OpenMAIC `lib/generation/action-parser.ts` 1:1 对齐的 DGBook 版本。
 *
 * 输入格式（与 OpenMAIC prompt 约定一致）：
 *   [
 *     {"type": "action", "name": "spotlight", "params": {"targetId": "gpioA"}},
 *     {"type": "text",   "content": "看 GPIOA"},
 *     {"type": "action", "name": "laser",     "params": {"targetId": "pin5"}},
 *     {"type": "text",   "content": "看 Pin5"}
 *   ]
 *
 * 输出（PageAction[]，类型见 packages/types/src/action.ts）：
 *   [
 *     { id: 'auto-...', type: 'spotlight', targetId: 'gpioA' },
 *     { id: 'auto-...', type: 'speak',     text: '看 GPIOA' },
 *     { id: 'auto-...', type: 'laser',     targetId: 'pin5' },
 *     { id: 'auto-...', type: 'speak',     text: '看 Pin5' },
 *   ]
 *
 * 关键设计（与 OpenMAIC 一致）：
 *   - **保留交错顺序**（这是"先指向、再讲解"被强制的根本机制——见 docs/iter36-openmaic-action-cursor.md §2.2）
 *   - 三级降级 parse：JSON.parse → 修花括号补全 → 失败返回 []
 *   - 旧格式兼容：`tool_name` / `parameters`（OpenMAIC legacy）= `name` / `params`
 *   - 防御 in depth：未知 action type 静默跳过、非数组输入返回 []
 *
 * 与 OpenMAIC 的差异（DGBook 简化）：
 *   - 不做 sceneType 过滤（DGBook page 是单一类型）
 *   - 不引入 `partial-json` / `jsonrepair` npm 包（用自有 stripFences + 双 JSON.parse 路径，留给 Iter-38+ 视情况补）
 *   - LLM action.name → DGBook PageAction.type 的映射在 `OPENMAIC_TO_DGBOOK_ACTION_NAME` 里维护
 *     (这是 DGBook 6 种 PageAction 子集，与 OpenMAIC 12+ Action 全集的"最小翻译表")
 */

import type { PageAction } from '@dgbook/types';

/** 已知 PageAction.type 白名单（防止 LLM hallucinate 新类型） */
const KNOWN_ACTION_TYPES = new Set<PageAction['type']>([
  'speak',
  'spotlight',
  'laser',
  'reveal',
  'wait',
  'pause-for-discussion',
]);

/**
 * OpenMAIC action.name → DGBook PageAction.type 翻译表
 *
 * - OpenMAIC 用 'speech'，DGBook 用 'speak'（语义相同，命名不同）
 * - OpenMAIC 用 'discussion'，DGBook 用 'pause-for-discussion'（DGBook 命名更清晰）
 * - OpenMAIC 的 wb_* / widget_* / play_video 等暂不映射（DGBook 当前无对应 PageAction，
 *   命中后静默跳过；未来扩展时只需在此表加映射即可）
 */
const OPENMAIC_TO_DGBOOK_NAME: Record<string, PageAction['type']> = {
  speech: 'speak', // OpenMAIC 'speech' → DGBook 'speak'
  speak: 'speak',
  spotlight: 'spotlight',
  laser: 'laser',
  reveal: 'reveal',
  wait: 'wait',
  discussion: 'pause-for-discussion', // OpenMAIC 'discussion' → DGBook 'pause-for-discussion'
  'pause-for-discussion': 'pause-for-discussion',
};

/** 自动 id 生成器（PageAction.id 必填，schema 校验：[a-zA-Z0-9_-]，长度 1-64） */
let idCounter = 0;
function autoId(): string {
  idCounter += 1;
  // 用毫秒戳 + 计数器，避免快速调用时重复
  return `auto-${Date.now().toString(36)}-${idCounter}`;
}

/** Strip markdown code fences (```json ... ``` 或 ``` ... ```) */
function stripCodeFences(text: string): string {
  return text.replace(/^```(?:json)?\s*\n?/i, '').replace(/\n?\s*```\s*$/i, '');
}

/**
 * 三级 JSON parse（轻量版 OpenMAIC json-repair）：
 *   1. 直接 JSON.parse
 *   2. 失败时尝试补齐截断（找到首 [ 末 ] 子串再 parse）
 *   3. 仍失败返回 null
 */
function parseLooseArray(jsonStr: string): unknown[] | null {
  try {
    const parsed: unknown = JSON.parse(jsonStr);
    return Array.isArray(parsed) ? parsed : null;
  } catch {
    /* fallthrough */
  }
  // 兜底：找首 [ 末 ] 子串
  const startIdx = jsonStr.indexOf('[');
  const endIdx = jsonStr.lastIndexOf(']');
  if (startIdx >= 0 && endIdx > startIdx) {
    try {
      const parsed: unknown = JSON.parse(jsonStr.slice(startIdx, endIdx + 1));
      return Array.isArray(parsed) ? parsed : null;
    } catch {
      /* fallthrough */
    }
  }
  return null;
}

/**
 * 单个 LLM item → PageAction 转换。
 *
 * 三种合法输入形态（对齐 OpenMAIC 设计）：
 *   - {type: 'text', content: '...'}                 → speak
 *   - {type: 'action', name: 'spotlight', params: {…}} → spotlight 等（新格式）
 *   - {type: 'action', tool_name: 'spotlight', parameters: {…}} → spotlight 等（旧格式）
 *
 * 不合法/未知/缺字段：返回 null（caller 会跳过）
 */
function itemToAction(item: unknown): PageAction | null {
  if (!item || typeof item !== 'object') return null;
  const obj = item as Record<string, unknown>;

  // ── 'text' 元素 → speak action
  if (obj.type === 'text') {
    const text = ((obj.content as string) || '').trim();
    if (!text) return null;
    return { id: autoId(), type: 'speak', text };
  }

  // ── 'action' 元素 → typed action
  if (obj.type === 'action') {
    const rawName = (obj.name || obj.tool_name) as string | undefined;
    if (!rawName) return null;
    const dgbookType = OPENMAIC_TO_DGBOOK_NAME[rawName];
    if (!dgbookType || !KNOWN_ACTION_TYPES.has(dgbookType)) return null;

    const params = (obj.params || obj.parameters || {}) as Record<string, unknown>;
    const id = ((obj.action_id || obj.tool_id) as string | undefined) ?? autoId();

    // type-specific 字段映射（这些就是 PageActionSchema 的字段）
    return { id, type: dgbookType, ...params } as PageAction;
  }

  return null;
}

/**
 * 主入口：把 LLM 输出的字符串解析为 PageAction[]。
 *
 * 失败路径（全部返回空数组而非抛错——player 不应因生成端错误而崩）：
 *   - 输入空字符串
 *   - 解析后非数组
 *   - 全部 item 都不合法
 *
 * 注意：本函数**不做 zod 校验**——返回的 PageAction[] 可以直接喂给 PageActionRunner，
 *      但若调用方需要严格 schema 一致性，应在外部用 PageActionsSchema.safeParse 再校验一次。
 */
export function parsePageActionsFromLLM(raw: string): PageAction[] {
  if (!raw || typeof raw !== 'string') return [];
  const cleaned = stripCodeFences(raw.trim());
  if (!cleaned) return [];

  const items = parseLooseArray(cleaned);
  if (!items) return [];

  const actions: PageAction[] = [];
  for (const item of items) {
    const action = itemToAction(item);
    if (action) actions.push(action);
  }
  return actions;
}
