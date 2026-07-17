/**
 * SceneViewer — DGBook 版 OpenMAIC ScreenCanvas + SpotlightOverlay
 *
 * 深度对标 OpenMAIC 实现：
 * - SpotlightOverlay：SVG mask + 暗化背景 + 白色边框动画（对标 SpotlightOverlay.tsx）
 * - HighlightOverlay：彩色边框 + glow 光晕（对标 HighlightOverlay.tsx）
 * - 逐步入场：spotlight 时 item 才入场（revealedItemIds 追踪）
 * - getBoundingClientRect 测量 active item，转换为 0-100 百分比坐标
 * N1 安全：纯 UI 组件，无课程特定逻辑
 */
import { useEffect, useLayoutEffect, useRef, useState, useCallback } from 'react';
import type { TeachingScene, TeachingSceneItem } from '@dgbook/types';
import s from './SceneViewer.module.css';

interface SceneViewerProps {
  scene: TeachingScene;
  /** 当前 spotlight 的 item ID */
  activeItemId?: string | null;
  /** 已入场的 item IDs（undefined = 全部显示） */
  revealedItemIds?: Set<string>;
  /** 当前正在朗读的文字（用于 Notes 注解面板） */
  currentSpeechText?: string;
}

/** SVG spotlight 几何（百分比坐标 0-100） */
interface SpotRect { x: number; y: number; w: number; h: number; }

/** 单要点卡片（对标 OpenMAIC ScreenElement） */
function SceneItem({ item, isActive, isRevealed, dimmed }: {
  item: TeachingSceneItem;
  isActive: boolean;
  isRevealed: boolean;
  dimmed: boolean;
}) {
  let cls = `${s.item} ${s[`type-${item.type}`]}`;
  if (!isRevealed) cls += ` ${s.hidden}`;
  else if (isActive) cls += ` ${s.active}`;
  else if (dimmed) cls += ` ${s.dimmed}`;

  return (
    <div
      className={cls}
      data-item-id={item.id}
      style={item.color ? { '--accent': item.color } as React.CSSProperties : undefined}
    >
      {item.type === 'code' ? (
        <pre className={s.code}><code>{item.text}</code></pre>
      ) : (
        <span className={s.text}>{item.text}</span>
      )}
    </div>
  );
}

/**
 * SVG Spotlight Overlay — 完全对标 OpenMAIC SpotlightOverlay.tsx
 * 用 SVG mask 实现暗化背景 + 镂空聚焦区域 + 白色边框动画
 */
function SpotlightLayer({ activeItemId, containerRef }: {
  activeItemId: string | null | undefined;
  containerRef: React.RefObject<HTMLDivElement | null>;
}) {
  const [rect, setRect] = useState<SpotRect | null>(null);
  const [prevRect, setPrevRect] = useState<SpotRect | null>(null);
  const animFrameRef = useRef<number>(0);

  const measure = useCallback(() => {
    if (!activeItemId || !containerRef.current) {
      setRect(null);
      return;
    }
    const el = containerRef.current.querySelector(`[data-item-id="${activeItemId}"]`);
    if (!el) { setRect(null); return; }

    const cR = containerRef.current.getBoundingClientRect();
    const eR = el.getBoundingClientRect();
    if (cR.width === 0 || cR.height === 0) return;

    setRect({
      x: ((eR.left - cR.left) / cR.width) * 100,
      y: ((eR.top - cR.top) / cR.height) * 100,
      w: (eR.width / cR.width) * 100,
      h: (eR.height / cR.height) * 100,
    });
  }, [activeItemId, containerRef]);

  useLayoutEffect(() => {
    if (activeItemId) {
      animFrameRef.current = requestAnimationFrame(() => {
        setTimeout(measure, 60);
      });
    } else {
      setPrevRect(rect);
      setRect(null);
    }
    return () => cancelAnimationFrame(animFrameRef.current);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeItemId, measure]);

  useEffect(() => {
    if (rect) setPrevRect(rect);
  }, [rect]);

  const show = !!activeItemId && !!rect;
  const r = rect ?? prevRect;
  if (!r) return null;

  const pad = 1.5;
  const rx = r.x - pad, ry = r.y - pad;
  const rw = r.w + pad * 2, rh = r.h + pad * 2;
  const maskId = `spot-mask-${activeItemId ?? 'none'}`;

  return (
    <div className={`${s.spotlightLayer} ${show ? s.spotlightVisible : s.spotlightHidden}`}>
      <svg
        width="100%" height="100%"
        viewBox="0 0 100 100"
        preserveAspectRatio="none"
        className={s.spotlightSvg}
      >
        <defs>
          <mask id={maskId}>
            <rect x="0" y="0" width="100" height="100" fill="white" />
            <rect x={rx} y={ry} width={rw} height={rh} rx="1.5" fill="black" />
          </mask>
        </defs>
        {/* 暗化层 */}
        <rect x="0" y="0" width="100" height="100" fill="rgba(0,0,0,0.6)" mask={`url(#${maskId})`} />
        {/* 白色聚焦边框（对标 OpenMAIC stroke="rgba(255,255,255,0.7)"）*/}
        <rect x={rx} y={ry} width={rw} height={rh} rx="1.5"
          fill="none" stroke="rgba(255,255,255,0.75)" strokeWidth="0.8"
          style={{ vectorEffect: 'non-scaling-stroke' } as React.CSSProperties}
        />
        {/* 品牌色内发光 */}
        <rect x={rx + 0.4} y={ry + 0.4} width={rw - 0.8} height={rh - 0.8} rx="1"
          fill="none" stroke="rgba(14,165,233,0.6)" strokeWidth="0.5"
          style={{ vectorEffect: 'non-scaling-stroke' } as React.CSSProperties}
        />
      </svg>
    </div>
  );
}

export function SceneViewer({
  scene, activeItemId, revealedItemIds, currentSpeechText
}: SceneViewerProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const hasAnyActive = !!activeItemId;
  const allRevealed = !revealedItemIds;

  const groups = new Map<string, TeachingSceneItem[]>();
  for (const item of scene.items) {
    const g = item.group ?? '__default__';
    if (!groups.has(g)) groups.set(g, []);
    groups.get(g)!.push(item);
  }
  const isMultiGroup = groups.size > 1;

  // 当前 active item（用于 Notes 面板内容差异化）
  const activeItem = activeItemId
    ? scene.items.find((i) => i.id === activeItemId)
    : null;

  // Notes 图标与提示前缀：根据 item 类型区分语气
  const notesConfig = activeItem
    ? {
        title:     { icon: '🎯', prefix: '' },
        highlight: { icon: '⚠️', prefix: '【重点】' },
        code:      { icon: '💻', prefix: '【代码】' },
        point:     { icon: '📌', prefix: '' },
      }[activeItem.type] ?? { icon: '📝', prefix: '' }
    : { icon: '📝', prefix: '' };

  return (
    <div className={s.viewer} ref={containerRef}>
      <SpotlightLayer activeItemId={activeItemId} containerRef={containerRef} />
      <div className={s.title}>{scene.title}</div>
      <div className={`${s.content} ${isMultiGroup ? s.multiCol : ''}`}>
        {Array.from(groups.entries()).map(([groupKey, items]) => (
          <div key={groupKey} className={s.group}>
            {groupKey !== '__default__' && <div className={s.groupLabel}>{groupKey}</div>}
            {items.map((item) => {
              const isRevealed = allRevealed || (revealedItemIds?.has(item.id) ?? false);
              const isActive = activeItemId === item.id;
              const dimmed = hasAnyActive && !isActive && isRevealed;
              return (
                <SceneItem key={item.id} item={item}
                  isActive={isActive} isRevealed={isRevealed} dimmed={dimmed} />
              );
            })}
          </div>
        ))}
      </div>

      {/* Notes 面板：speech 文字 + item.note 联动（对标 OpenMAIC Notes Panel）*/}
      {(currentSpeechText || (activeItem?.note)) && (
        <div className={`${s.notesBar} ${activeItem?.type === 'highlight' ? s.notesHighlight : activeItem?.type === 'code' ? s.notesCode : ''}`}>
          <span className={s.notesIcon}>{notesConfig.icon}</span>
          <span className={s.notesText}>
            {notesConfig.prefix}{currentSpeechText || activeItem?.note || ''}
          </span>
        </div>
      )}
    </div>
  );
}

