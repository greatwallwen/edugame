/**
 * resolveBlockIdFromElementId.test.ts
 */
import { describe, it, expect } from 'vitest';
import type { Page } from '@dgbook/types';
import { resolveBlockIdFromElementId } from './resolveBlockIdFromElementId';

const fakePage: Page = {
  id: 'p3-led',
  title: 'LED 闪烁',
  template: 'overview',
  blocks: [
    { id: 'p3-led-text', kind: 'text', text: 'hi' },
    { id: 'p3-led-svg', kind: 'graphics', src: 'x.svg', nodes: [
      { id: 'gpio', label: '' }, { id: 'r', label: '' },
      { id: 'led', label: '' }, { id: 'gnd', label: '' },
    ] },
    { id: 'p3-wokwi-led', kind: 'wokwi-element', spec: { kind: 'led', label: 'PA5' } },
    { id: 'p3-fsm', kind: 'mermaid', code: 'graph TD', nodes: [{ id: 'IDLE', label: '' }] },
  ],
} as unknown as Page;

describe('resolveBlockIdFromElementId', () => {
  it('dgb-block-X → X', () => {
    expect(resolveBlockIdFromElementId('dgb-block-foo', fakePage)).toBe('foo');
  });

  it('dgb-wokwi-X → X', () => {
    expect(resolveBlockIdFromElementId('dgb-wokwi-p3-wokwi-led', fakePage)).toBe('p3-wokwi-led');
  });

  it('dgb-graphics-{node} → block.id of graphics block containing node', () => {
    expect(resolveBlockIdFromElementId('dgb-graphics-led', fakePage)).toBe('p3-led-svg');
    expect(resolveBlockIdFromElementId('dgb-graphics-gnd', fakePage)).toBe('p3-led-svg');
  });

  it('dgb-mermaid-{node} → block.id of mermaid block containing node', () => {
    expect(resolveBlockIdFromElementId('dgb-mermaid-IDLE', fakePage)).toBe('p3-fsm');
  });

  it('节点不在任何 block：null', () => {
    expect(resolveBlockIdFromElementId('dgb-graphics-nonexistent', fakePage)).toBeNull();
    expect(resolveBlockIdFromElementId('dgb-mermaid-NOT_A_STATE', fakePage)).toBeNull();
  });

  it('null / undefined / 空 elementId / 空 page → null', () => {
    expect(resolveBlockIdFromElementId(null, fakePage)).toBeNull();
    expect(resolveBlockIdFromElementId('', fakePage)).toBeNull();
    expect(resolveBlockIdFromElementId('dgb-block-x', null)).toBeNull();
  });

  it('未知 prefix → null（不影响主路径）', () => {
    expect(resolveBlockIdFromElementId('unknown-prefix-x', fakePage)).toBeNull();
  });

  it('dgb-anim-{node} → block.id of animation block', () => {
    const pageWithAnim: Page = {
      ...fakePage,
      blocks: [
        ...fakePage.blocks,
        { id: 'p3-anim', kind: 'animation', src: 'x.html', nodes: [{ id: 'cpu', label: '' }] },
      ],
    } as unknown as Page;
    expect(resolveBlockIdFromElementId('dgb-anim-cpu', pageWithAnim)).toBe('p3-anim');
  });

  it('dgb-text-{blockId}-s{N} → blockId（段落级 spotlight）', () => {
    expect(resolveBlockIdFromElementId('dgb-text-p1c-text-s0', fakePage)).toBe('p1c-text');
    expect(resolveBlockIdFromElementId('dgb-text-p3-led-blink-text-s5', fakePage)).toBe('p3-led-blink-text');
  });
});
