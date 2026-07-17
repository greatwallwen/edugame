import { describe, it, expect } from 'vitest';
import { buildBlockNav, currentBlockIndex } from './buildBlockNav';
import type { Page } from '@dgbook/types';

// 构造一个含 speak / spotlight / play-video / anim-step 的 page
function mkPage(): Page {
  return {
    id: 'p-test',
    title: 'T',
    template: 'T-concept',
    blocks: [
      { id: 'b-anim', kind: 'animation', src: 'inline:x' },
      { id: 'b-video', kind: 'animation', src: './a.mp4', format: 'video-mp4' },
      { id: 'b-text', kind: 'text', markdown: 'hi' },
    ],
    actions: [
      { id: 'a1', type: 'spotlight', targetId: 'dgb-anim-step-1' },
      { id: 'a2', type: 'speak', text: 's1', blockId: 'b-anim' },
      { id: 'a3', type: 'spotlight', targetId: 'dgb-anim-step-2' },
      { id: 'a4', type: 'speak', text: 's2', blockId: 'b-anim' },
      { id: 'a5', type: 'play-video', targetId: 'dgb-block-b-video' },
      { id: 'a6', type: 'speak', text: 's3', blockId: 'b-text' },
    ],
  } as unknown as Page;
}

describe('buildBlockNav', () => {
  it('去重得到 3 个 block，按 action 顺序', () => {
    const nav = buildBlockNav(mkPage());
    expect(nav.entries.map((e) => e.blockId)).toEqual(['b-anim', 'b-video', 'b-text']);
  });

  it('每个 block 记录首个 action 下标', () => {
    const nav = buildBlockNav(mkPage());
    // b-anim 首 action 是 a2(下标1, speak 带 blockId)；anim-step(a1) 无 blockId 继承
    expect(nav.entries[0]!.firstActionIndex).toBe(1);
    // b-video 首 action 是 a5(下标4)
    expect(nav.entries[1]!.firstActionIndex).toBe(4);
    // b-text 首 action 是 a6(下标5)
    expect(nav.entries[2]!.firstActionIndex).toBe(5);
  });

  it('anim-step 归属到最近的真实 block', () => {
    const nav = buildBlockNav(mkPage());
    // a3(anim-step-2) 在 a2 之后 → 继承 b-anim(下标0)
    expect(nav.blockOfAction[2]).toBe(0);
  });

  it('currentBlockIndex 反查正在播的块', () => {
    const nav = buildBlockNav(mkPage());
    // actionIndex=5 表示正在播 actions[4]=play-video → b-video(下标1)
    expect(currentBlockIndex(nav, 5)).toBe(1);
    // actionIndex=2 表示正在播 actions[1]=speak b-anim → 0
    expect(currentBlockIndex(nav, 2)).toBe(0);
  });

  it('空 actions 返回空导航', () => {
    const nav = buildBlockNav({ id: 'x', blocks: [], actions: [] } as unknown as Page);
    expect(nav.entries).toEqual([]);
    expect(currentBlockIndex(nav, 0)).toBe(-1);
  });
});
