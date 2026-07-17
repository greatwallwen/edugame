import { useCallback, useMemo, useRef, useState } from 'react';
import { motion, type PanInfo } from 'framer-motion';
import type { InteractiveSpec } from '@dgbook/types';
import { useGameScore, GameStat, GameWinBanner } from '../game-kit';
import './ClassificationBlock.css';

export interface ClassificationBlockProps {
  spec: Extract<InteractiveSpec, { kind: 'classification' }>;
}

const POOL_KEY = '__pool__';

/**
 * ClassificationBlock v2 · framer-motion 拖拽投放。
 * - 拖：拖拽 chip 到目标分类框；onDragEnd 用指针坐标命中 bin / pool 的矩形。
 * - 退化：保留点击选中 + 点击 bin 的两步交互（无指针设备 / 键盘）。
 */
export function ClassificationBlock({ spec }: ClassificationBlockProps) {
  const [placements, setPlacements] = useState<Record<string, string>>({});
  const [activeItem, setActiveItem] = useState<string | null>(null);
  const [hoverBin, setHoverBin] = useState<string | null>(null);
  const [submitted, setSubmitted] = useState(false);
  const { score, combo, register, reset: resetScore, stars, playWin } = useGameScore();

  // bin & pool 的 DOM 引用，命中检测用
  const binRefs = useRef<Map<string, HTMLDivElement | null>>(new Map());
  const poolRef = useRef<HTMLDivElement | null>(null);

  const shuffledItems = useMemo(() => {
    const arr = spec.items.map((i) => ({ ...i }));
    let s = 0;
    for (let k = 0; k < spec.items.length; k++) s = (s * 31 + (spec.items[k]!.text.charCodeAt(0))) >>> 0;
    for (let i = arr.length - 1; i > 0; i--) {
      s = (s * 1103515245 + 12345) >>> 0;
      const j = s % (i + 1);
      [arr[i], arr[j]] = [arr[j]!, arr[i]!];
    }
    return arr;
  }, [spec]);

  const placedItemIds = new Set(Object.keys(placements));
  const allPlaced = placedItemIds.size === spec.items.length;

  const placeItem = useCallback((itemId: string, catId: string) => {
    if (submitted) return;
    setPlacements((cur) => ({ ...cur, [itemId]: catId }));
    setActiveItem(null);
  }, [submitted]);

  const unplace = useCallback((itemId: string) => {
    if (submitted) return;
    setPlacements((cur) => {
      const n = { ...cur };
      delete n[itemId];
      return n;
    });
  }, [submitted]);

  /** 用指针坐标命中目标区域：返回 categoryId 或 POOL_KEY 或 null。 */
  const resolveDropTarget = useCallback((clientX: number, clientY: number): string | null => {
    for (const cat of spec.categories) {
      const el = binRefs.current.get(cat.id);
      if (!el) continue;
      const r = el.getBoundingClientRect();
      if (clientX >= r.left && clientX <= r.right && clientY >= r.top && clientY <= r.bottom) {
        return cat.id;
      }
    }
    const pool = poolRef.current;
    if (pool) {
      const r = pool.getBoundingClientRect();
      if (clientX >= r.left && clientX <= r.right && clientY >= r.top && clientY <= r.bottom) {
        return POOL_KEY;
      }
    }
    return null;
  }, [spec.categories]);

  const onDrag = useCallback((_e: unknown, info: PanInfo) => {
    const t = resolveDropTarget(info.point.x, info.point.y);
    setHoverBin(t === POOL_KEY ? null : t);
  }, [resolveDropTarget]);

  const onDragEndItem = useCallback((itemId: string) => (_e: unknown, info: PanInfo) => {
    const t = resolveDropTarget(info.point.x, info.point.y);
    setHoverBin(null);
    if (!t) return;
    if (t === POOL_KEY) unplace(itemId);
    else placeItem(itemId, t);
  }, [placeItem, unplace, resolveDropTarget]);

  const correctCount = submitted
    ? spec.items.filter((it) => placements[it.id] === it.correctCategory).length
    : 0;
  const allCorrect = submitted && correctCount === spec.items.length;

  function handleSubmit() {
    spec.items.forEach((it) => register(placements[it.id] === it.correctCategory));
    setSubmitted(true);
  }
  function handleReset() {
    setPlacements({}); setSubmitted(false); setActiveItem(null); resetScore();
  }

  return (
    <div className="dgb-classify">
      <div className="dgb-classify-head">
        <span className="dgb-classify-badge">📦 分类归纳</span>
        {spec.prompt ? <span className="dgb-classify-prompt">{spec.prompt}</span> : null}
        {!submitted ? <span className="dgb-classify-hint-tip">拖拽 chip 到分类框，或先点选再点击目标框</span> : null}
        <GameStat score={score} combo={combo} />
      </div>
      <div className="dgb-classify-bins">
        {spec.categories.map((cat) => (
          <div
            key={cat.id}
            ref={(el) => { binRefs.current.set(cat.id, el); }}
            className={`dgb-classify-bin ${hoverBin === cat.id ? 'over' : ''} ${activeItem ? 'awaiting' : ''}`}
            onClick={() => activeItem && !submitted ? placeItem(activeItem, cat.id) : undefined}
            role="button"
            tabIndex={0}
          >
            <div className="dgb-classify-bin-label">{cat.label}</div>
            <div className="dgb-classify-bin-drop">
              {shuffledItems
                .filter((it) => placements[it.id] === cat.id)
                .map((it) => (
                  <motion.button
                    key={it.id}
                    type="button"
                    className={`dgb-classify-chip ${submitted ? (it.correctCategory === cat.id ? 'ok' : 'ng') : ''}`}
                    disabled={submitted}
                    onClick={(e) => { e.stopPropagation(); if (!submitted) unplace(it.id); }}
                    drag={!submitted}
                    dragSnapToOrigin
                    dragElastic={0.6}
                    whileDrag={{ scale: 1.08, zIndex: 10, boxShadow: '0 8px 20px rgba(15,23,42,.18)' }}
                    onDrag={onDrag}
                    onDragEnd={onDragEndItem(it.id)}
                  >
                    {it.text}
                  </motion.button>
                ))}
            </div>
          </div>
        ))}
      </div>
      <div ref={poolRef} className={`dgb-classify-pool ${hoverBin === null && activeItem ? '' : ''}`}>
        <span className="dgb-classify-pool-label">待分类：</span>
        {shuffledItems
          .filter((it) => !placedItemIds.has(it.id))
          .map((it) => (
            <motion.button
              key={it.id}
              type="button"
              className={`dgb-classify-chip ${activeItem === it.id ? 'active' : ''}`}
              disabled={submitted}
              onClick={() => setActiveItem((cur) => (cur === it.id ? null : it.id))}
              drag={!submitted}
              dragSnapToOrigin
              dragElastic={0.6}
              whileDrag={{ scale: 1.08, zIndex: 10, boxShadow: '0 8px 20px rgba(15,23,42,.18)' }}
              onDrag={onDrag}
              onDragEnd={onDragEndItem(it.id)}
            >
              {it.text}
            </motion.button>
          ))}
      </div>
      {activeItem && !submitted ? (
        <div className="dgb-classify-hint">已选「{shuffledItems.find((i) => i.id === activeItem)?.text}」 · 点击上方分类框放入</div>
      ) : null}
      <div className="dgb-classify-actions">
        <button type="button" className="dgb-classify-submit" disabled={!allPlaced || submitted} onClick={handleSubmit}>提交</button>
        {submitted && !allCorrect ? (
          <button type="button" className="dgb-classify-reset" onClick={handleReset}>重做</button>
        ) : null}
        {submitted ? (
          <span className={`dgb-classify-score ${allCorrect ? 'ok' : 'ng'}`}>
            {correctCount} / {spec.items.length} 正确
          </span>
        ) : null}
      </div>
      <GameWinBanner
        show={allCorrect}
        text={`🎉 分类全对！最终得分 ${score}`}
        onReplay={handleReset}
        stars={stars}
        onShow={playWin}
      />
    </div>
  );
}
