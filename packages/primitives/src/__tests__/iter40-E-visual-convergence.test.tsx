
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { CommentaryBar } from '../commentary/CommentaryBar';
import { CalloutBlock } from '../lesson-hero/CalloutBlock';
import { PrincipleCardsBlock } from '../lesson-hero/PrincipleCardsBlock';

describe('CommentaryBar · 讲师身份双行版式', () => {
  it('传 role + avatarUrl 时渲染头像 img + 角色文字', () => {
    const { container, getByAltText, getByText } = render(
      <CommentaryBar
        sourceType="text"
        script="测试讲解"
        speaker="张老师"
        role="STM32 教学讲师"
        avatarUrl="/avatars/teacher.png"
      />,
    );
    // 头像 img 存在且 alt 包含 speaker
    expect(getByAltText('张老师 头像')).toBeTruthy();
    // 角色行存在
    expect(getByText('STM32 教学讲师')).toBeTruthy();
    expect(getByText('张老师')).toBeTruthy();
    // CSS hook 验证：speaker-block 双行容器存在
    expect(container.querySelector('.dgb-cbar-speaker-block')).not.toBeNull();
  });

  it('不传 role 时不渲染 role 行（向后兼容旧 v3-v6 调用）', () => {
    const { container } = render(
      <CommentaryBar sourceType="text" script="测试" speaker="AI 讲师" />,
    );
    expect(container.querySelector('.dgb-cbar-role')).toBeNull();
    expect(container.querySelector('.dgb-cbar-avatar')).toBeNull();
    // speaker 文本仍在
    expect(container.textContent).toContain('AI 讲师');
  });
});

describe('CalloutBlock · 嵌套白卡子标题', () => {
  it('传 subtitle 时渲染 subcard + has-subtitle modifier 类', () => {
    const { container, getByText } = render(
      <CalloutBlock kind="intro" title="重点" subtitle="导学摘要">
        <p>讲解资源链</p>
      </CalloutBlock>,
    );
    // modifier 类存在
    expect(container.querySelector('.dgb-callout--has-subtitle')).not.toBeNull();
    // 子卡白盒存在
    expect(container.querySelector('.dgb-callout-subcard')).not.toBeNull();
    // 子标题文本存在
    expect(getByText('导学摘要')).toBeTruthy();
    expect(getByText('讲解资源链')).toBeTruthy();
  });

  it('不传 subtitle 时退回单层版式（无 subcard / 无 modifier 类）', () => {
    const { container } = render(
      <CalloutBlock kind="intro" title="导读">
        <p>段落正文</p>
      </CalloutBlock>,
    );
    expect(container.querySelector('.dgb-callout--has-subtitle')).toBeNull();
    expect(container.querySelector('.dgb-callout-subcard')).toBeNull();
    // 内容仍在 .dgb-callout-content 里
    expect(container.querySelector('.dgb-callout-content')?.textContent).toContain('段落正文');
  });
});

describe('PrincipleCardsBlock · horizontal-numbered 变体', () => {
  const sampleItems = [
    { title: '资源边界', content: '机房先建台账' },
    { title: '设备拓扑', content: '走线关系可追溯' },
    { title: '运行条件', content: '供电接地温控' },
    { title: '现场证据', content: '端口对应设备' },
    { title: '关系校验', content: '链路完整性' },
  ];

  it('layout="horizontal-numbered" 时 grid data-layout=horizontal', () => {
    const { container } = render(
      <PrincipleCardsBlock heading="概念框架" items={sampleItems} layout="horizontal-numbered" />,
    );
    const grid = container.querySelector('.dgb-principle-grid');
    expect(grid?.getAttribute('data-layout')).toBe('horizontal');
    expect(grid?.getAttribute('data-count')).toBe('5');
    // horizontal modifier 类
    expect(container.querySelector('.dgb-principle-cards--horizontal')).not.toBeNull();
  });

  it('layout 缺省时 data-layout=auto（v5 向后兼容）', () => {
    const { container } = render(
      <PrincipleCardsBlock heading="原则" items={sampleItems.slice(0, 2)} />,
    );
    const grid = container.querySelector('.dgb-principle-grid');
    expect(grid?.getAttribute('data-layout')).toBe('auto');
    expect(container.querySelector('.dgb-principle-cards--horizontal')).toBeNull();
  });

  it('6+ 项 horizontal 自动回落 auto（避免溢出）', () => {
    const sixItems = [...sampleItems, { title: '第六项', content: '溢出' }];
    const { container } = render(
      <PrincipleCardsBlock items={sixItems} layout="horizontal-numbered" />,
    );
    const grid = container.querySelector('.dgb-principle-grid');
    // items.length=6 > 5 → horizontal 关闭
    expect(grid?.getAttribute('data-layout')).toBe('auto');
  });

  it('horizontal 模式下每张卡都渲染编号 + 标题 + 内容', () => {
    const { container } = render(
      <PrincipleCardsBlock items={sampleItems} layout="horizontal-numbered" />,
    );
    const cards = container.querySelectorAll('.dgb-principle-card');
    expect(cards.length).toBe(5);
    // 第一张卡的编号默认是 ①（CIRCLED[0]）
    expect(cards[0]?.querySelector('.dgb-principle-numeral')?.textContent).toBe('①');
    // 第一张卡的标题与传入对齐
    expect(cards[0]?.querySelector('.dgb-principle-card-title')?.textContent).toBe('资源边界');
  });
});
