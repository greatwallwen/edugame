import { describe, it, expect } from 'vitest';
import { generateFollowUps, derivePageFaq } from '../src/follow-up-templates';
import { DEFAULT_AI_TUTOR } from '../src/ai-tutor-config';
import type { DomainTerm, FollowUpTemplate } from '../src/domain-terms';
import type { Page } from '@dgbook/types';

// 测试用术语数据（模拟 manifest.domainTerms 注入）
const TEST_TERMS: DomainTerm[] = [
  { term: 'GPIO', kind: 'periph' },
  { term: 'NVIC', kind: 'irq' },
  { term: 'PWM', kind: 'timing' },
  { term: 'STM32', kind: 'core' },
];

const TEST_TEMPLATES: FollowUpTemplate[] = [
  { kind: 'periph', template: '{term} 在 STM32F103 上常见的初始化坑有哪些？' },
  { kind: 'irq', template: '{term} 触发后 ISR 里最容易写错的是什么？' },
  { kind: 'timing', template: '{term} 的频率和占空比怎么算才不溢出？' },
  { kind: 'core', template: '{term} 和 AT32 在外设寄存器层面有哪些差异？' },
];

describe('generateFollowUps', () => {
  it('命中 GPIO（periph）→ 生成 periph 模板问句', () => {
    const out = generateFollowUps('GPIO 怎么配置？', 'GPIO 是通用输入输出。', 'LED 闪烁', TEST_TERMS, TEST_TEMPLATES);
    expect(out.length).toBe(3);
    expect(out[0]).toContain('GPIO');
    expect(out[0]).toMatch(/初始化/);
  });

  it('命中 NVIC（irq）→ 生成 irq 模板问句', () => {
    const out = generateFollowUps('NVIC 优先级', 'NVIC 是嵌套向量中断控制器。', undefined, TEST_TERMS, TEST_TEMPLATES);
    expect(out[0]).toContain('NVIC');
    expect(out[0]).toMatch(/ISR/);
  });

  it('完全无命中 → 用 pageTopic 兜底', () => {
    const out = generateFollowUps('这是什么', '答案', '通用页', TEST_TERMS, TEST_TEMPLATES);
    expect(out.length).toBeGreaterThanOrEqual(2);
    const all = out.join(' ');
    expect(all).toContain('通用页');
  });

  it('无 terms 参数 → 不崩溃，返回兜底', () => {
    const out = generateFollowUps('hello', 'world', '页面');
    expect(out.length).toBeGreaterThanOrEqual(2);
  });

  it('去重：相同问句不重复', () => {
    const out = generateFollowUps('test', 'test', 'test', TEST_TERMS, TEST_TEMPLATES);
    expect(new Set(out).size).toBe(out.length);
  });
});

describe('derivePageFaq', () => {
  it('从 commentary stepScripts 派生命中 GPIO + NVIC', () => {
    const page: Page = {
      id: 'p1',
      title: 'GPIO 入门',
      blocks: [
        {
          id: 'b1',
          kind: 'text',
          commentary: { stepScripts: ['GPIO 初始化', 'NVIC 配置中断', 'PWM 输出'] },
        },
      ],
    } as unknown as Page;
    const faq = derivePageFaq(page, TEST_TERMS);
    expect(faq.length).toBeGreaterThanOrEqual(2);
    expect(faq[0]?.q).toContain('GPIO 入门');
    const all = faq.map((f) => f.q).join(' ');
    expect(all).toMatch(/GPIO|NVIC|PWM/);
  });

  it('零命中也能产出 1 条核心要点 FAQ', () => {
    const page: Page = {
      id: 'p2',
      title: '空白页',
      blocks: [],
    } as unknown as Page;
    const faq = derivePageFaq(page, TEST_TERMS);
    expect(faq.length).toBe(1);
    expect(faq[0]?.q).toContain('空白页');
  });

  it('无 terms → 不崩溃，返回核心要点', () => {
    const page: Page = { id: 'p3', title: '测试', blocks: [] } as unknown as Page;
    const faq = derivePageFaq(page);
    expect(faq.length).toBe(1);
  });
});

describe('DEFAULT_AI_TUTOR sanity', () => {
  it('DEFAULT_AI_TUTOR 三字段非空', () => {
    expect(DEFAULT_AI_TUTOR.name).toBeTruthy();
    expect(DEFAULT_AI_TUTOR.subtitle).toBeTruthy();
    expect(DEFAULT_AI_TUTOR.welcome).toBeTruthy();
  });
});
