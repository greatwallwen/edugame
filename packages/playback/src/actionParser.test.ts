/**
 * actionParser.test.ts — Iter-37 验证
 *
 * 测试覆盖（与 docs/iter37-generation-gap.md §4.2 对齐）：
 *   1. happy path：4 元素交错正常解析
 *   2. ```json 围栏剥离
 *   3. 仅 text 元素全部 → speak
 *   4. 仅 action 元素 → spotlight/laser
 *   5. 旧格式 tool_name / parameters 兼容（OpenMAIC legacy）
 *   6. 非数组输入返回 []
 *   7. 空字符串返回 []
 *   8. JSON.parse 失败 → 截断兜底
 *   9. 未知 action.name 静默跳过（防 LLM hallucinate）
 *  10. **保留交错顺序**（核心断言：spotlight → speak → laser → speak 不能被重排）
 *  11. OpenMAIC 'speech' → DGBook 'speak' 命名翻译
 *  12. OpenMAIC 'discussion' → DGBook 'pause-for-discussion' 命名翻译
 */

import { describe, it, expect } from 'vitest';
import { parsePageActionsFromLLM } from './actionParser';
import type { PageAction } from '@dgbook/types';

describe('parsePageActionsFromLLM', () => {
  it('happy path：4 元素交错保留顺序', () => {
    const raw = JSON.stringify([
      { type: 'action', name: 'spotlight', params: { targetId: 'gpioA' } },
      { type: 'text', content: '看 GPIOA' },
      { type: 'action', name: 'laser', params: { targetId: 'pin5' } },
      { type: 'text', content: '看 Pin5' },
    ]);
    const actions = parsePageActionsFromLLM(raw);

    expect(actions).toHaveLength(4);
    expect(actions[0]!.type).toBe('spotlight');
    expect(actions[1]!.type).toBe('speak');
    expect(actions[2]!.type).toBe('laser');
    expect(actions[3]!.type).toBe('speak');

    // 字段透传
    expect((actions[0] as Extract<PageAction, { type: 'spotlight' }>).targetId).toBe('gpioA');
    expect((actions[1] as Extract<PageAction, { type: 'speak' }>).text).toBe('看 GPIOA');
    expect((actions[2] as Extract<PageAction, { type: 'laser' }>).targetId).toBe('pin5');
  });

  it('```json 围栏自动剥离', () => {
    const raw = '```json\n[{"type":"text","content":"hello"}]\n```';
    const actions = parsePageActionsFromLLM(raw);
    expect(actions).toHaveLength(1);
    expect(actions[0]!.type).toBe('speak');
    expect((actions[0] as Extract<PageAction, { type: 'speak' }>).text).toBe('hello');
  });

  it('``` 围栏（无语言标识）也支持', () => {
    const raw = '```\n[{"type":"text","content":"plain"}]\n```';
    const actions = parsePageActionsFromLLM(raw);
    expect(actions).toHaveLength(1);
  });

  it('全部 text 元素 → 全部 speak', () => {
    const raw = JSON.stringify([
      { type: 'text', content: '一' },
      { type: 'text', content: '二' },
      { type: 'text', content: '三' },
    ]);
    const actions = parsePageActionsFromLLM(raw);
    expect(actions.every((a) => a.type === 'speak')).toBe(true);
    expect(actions.map((a) => (a as Extract<PageAction, { type: 'speak' }>).text)).toEqual([
      '一',
      '二',
      '三',
    ]);
  });

  it('旧格式 tool_name / parameters 兼容（OpenMAIC legacy）', () => {
    const raw = JSON.stringify([
      { type: 'action', tool_name: 'spotlight', parameters: { targetId: 'A' } },
      { type: 'action', tool_name: 'laser', parameters: { targetId: 'B', color: '#f00' } },
    ]);
    const actions = parsePageActionsFromLLM(raw);
    expect(actions).toHaveLength(2);
    expect(actions[0]!.type).toBe('spotlight');
    expect((actions[0] as Extract<PageAction, { type: 'spotlight' }>).targetId).toBe('A');
    expect((actions[1] as Extract<PageAction, { type: 'laser' }>).color).toBe('#f00');
  });

  it('非数组输入（对象）返回 []', () => {
    const raw = JSON.stringify({ not: 'an array' });
    expect(parsePageActionsFromLLM(raw)).toEqual([]);
  });

  it('空字符串返回 []', () => {
    expect(parsePageActionsFromLLM('')).toEqual([]);
    expect(parsePageActionsFromLLM('   ')).toEqual([]);
  });

  it('完全无效 JSON 返回 []（不抛错）', () => {
    expect(parsePageActionsFromLLM('this is not json at all')).toEqual([]);
  });

  it('截断 JSON 兜底：从首 [ 到末 ] 截子串重试', () => {
    // LLM 末尾多了一段碎话，但中间是合法数组
    const raw = 'Here is the result:\n[{"type":"text","content":"good"}]\nThanks!';
    const actions = parsePageActionsFromLLM(raw);
    expect(actions).toHaveLength(1);
    expect(actions[0]!.type).toBe('speak');
  });

  it('未知 action.name 静默跳过（防 LLM hallucinate）', () => {
    const raw = JSON.stringify([
      { type: 'action', name: 'spotlight', params: { targetId: 'A' } },
      { type: 'action', name: 'fly_to_moon', params: {} }, // 未知
      { type: 'text', content: 'narration' },
    ]);
    const actions = parsePageActionsFromLLM(raw);
    expect(actions).toHaveLength(2);
    expect(actions[0]!.type).toBe('spotlight');
    expect(actions[1]!.type).toBe('speak');
  });

  it('OpenMAIC 命名翻译：speech → speak', () => {
    // OpenMAIC LLM 可能输出 speech action 显式形式（而不是 text 速记）
    const raw = JSON.stringify([
      { type: 'action', name: 'speech', params: { text: '从 speech action 来的' } },
    ]);
    const actions = parsePageActionsFromLLM(raw);
    expect(actions).toHaveLength(1);
    expect(actions[0]!.type).toBe('speak');
    expect((actions[0] as Extract<PageAction, { type: 'speak' }>).text).toBe('从 speech action 来的');
  });

  it('OpenMAIC 命名翻译：discussion → pause-for-discussion', () => {
    const raw = JSON.stringify([
      {
        type: 'action',
        name: 'discussion',
        params: { topic: '为何拉低', prompt: 'guide' },
      },
    ]);
    const actions = parsePageActionsFromLLM(raw);
    expect(actions).toHaveLength(1);
    expect(actions[0]!.type).toBe('pause-for-discussion');
    expect((actions[0] as Extract<PageAction, { type: 'pause-for-discussion' }>).topic).toBe(
      '为何拉低',
    );
  });

  it('action_id / tool_id 透传到 PageAction.id', () => {
    const raw = JSON.stringify([
      { type: 'action', name: 'spotlight', action_id: 'a-1', params: { targetId: 'A' } },
      { type: 'action', name: 'laser', tool_id: 't-2', params: { targetId: 'B' } },
    ]);
    const actions = parsePageActionsFromLLM(raw);
    expect(actions[0]!.id).toBe('a-1');
    expect(actions[1]!.id).toBe('t-2');
  });

  it('id 缺失时自动生成 auto- 前缀', () => {
    const raw = JSON.stringify([{ type: 'text', content: 'no id provided' }]);
    const actions = parsePageActionsFromLLM(raw);
    expect(actions[0]!.id).toMatch(/^auto-/);
  });

  it('保留交错顺序（核心断言：spotlight → speak → laser → speak 不被重排）', () => {
    const raw = JSON.stringify([
      { type: 'action', name: 'spotlight', params: { targetId: 'X' } },
      { type: 'text', content: 'first speech' },
      { type: 'action', name: 'laser', params: { targetId: 'Y' } },
      { type: 'text', content: 'second speech' },
      { type: 'action', name: 'spotlight', params: { targetId: 'Z' } },
      { type: 'text', content: 'third speech' },
    ]);
    const actions = parsePageActionsFromLLM(raw);
    const types = actions.map((a) => a.type);
    expect(types).toEqual(['spotlight', 'speak', 'laser', 'speak', 'spotlight', 'speak']);
  });

  it('空 text 内容跳过（content 是空白字符串视为无效）', () => {
    const raw = JSON.stringify([
      { type: 'text', content: '' },
      { type: 'text', content: '   ' },
      { type: 'text', content: '有内容' },
    ]);
    const actions = parsePageActionsFromLLM(raw);
    expect(actions).toHaveLength(1);
    expect((actions[0] as Extract<PageAction, { type: 'speak' }>).text).toBe('有内容');
  });

  it('非字符串输入返回 []', () => {
    // @ts-expect-error 测试运行时类型保护
    expect(parsePageActionsFromLLM(null)).toEqual([]);
    // @ts-expect-error 测试运行时类型保护
    expect(parsePageActionsFromLLM(undefined)).toEqual([]);
    // @ts-expect-error 测试运行时类型保护
    expect(parsePageActionsFromLLM(123)).toEqual([]);
  });
});
