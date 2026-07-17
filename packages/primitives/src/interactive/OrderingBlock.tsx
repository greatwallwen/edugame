import { useMemo, useState } from 'react';
import { Reorder, motion } from 'framer-motion';
import type { InteractiveSpec } from '@dgbook/types';
import { useGameScore, GameStat, GameWinBanner } from '../game-kit';
import './OrderingBlock.css';

export interface OrderingBlockProps {
  spec: Extract<InteractiveSpec, { kind: 'ordering' }>;
}

export function OrderingBlock({ spec }: OrderingBlockProps) {
  const [order, setOrder] = useState<string[]>(() => spec.items.map((i) => i.id));
  const [submitted, setSubmitted] = useState(false);
  const { score, combo, register, reset: resetScore, stars, playWin } = useGameScore();

  const correctOrder = spec.correctOrder;
  const isCorrect = submitted && order.every((id, i) => id === correctOrder[i]);

  const itemMap = useMemo(() => {
    const m = new Map<string, string>();
    for (const i of spec.items) m.set(i.id, i.text);
    return m;
  }, [spec]);

  function handleSubmit() {
    // 按位置逐项判分：连续答对累计连击
    order.forEach((id, i) => register(id === correctOrder[i]));
    setSubmitted(true);
  }

  function handleReset() {
    setSubmitted(false);
    setOrder(spec.items.map((i) => i.id));
    resetScore();
  }

  return (
    <div className="dgb-order">
      <div className="dgb-order-head">
        <span className="dgb-order-badge">🔢 排序闯关</span>
        {spec.prompt ? <span className="dgb-order-prompt">{spec.prompt}</span> : null}
        {!submitted ? <span className="dgb-order-hint">👆 拖拽调整顺序</span> : null}
        <GameStat score={score} combo={combo} />
      </div>
      <Reorder.Group
        axis="y"
        values={order}
        onReorder={setOrder}
        className="dgb-order-list"
        as="ol"
      >
        {order.map((id, idx) => {
          const text = itemMap.get(id)!;
          const isOk = submitted && id === correctOrder[idx];
          const isNg = submitted && id !== correctOrder[idx];

          return (
            <Reorder.Item
              key={id}
              value={id}
              dragListener={!submitted}
              as="li"
              className={`dgb-order-item ${isOk ? 'ok' : ''} ${isNg ? 'ng' : ''}`}
              whileDrag={{ scale: 1.03, boxShadow: '0 8px 24px rgba(15,23,42,.12)' }}
              transition={{ type: 'spring', stiffness: 400, damping: 30 }}
            >
              <span className="dgb-order-num">{idx + 1}</span>
              <span className="dgb-order-text">{text}</span>
              {!submitted ? (
                <motion.span
                  className="dgb-order-drag-handle"
                  initial={{ opacity: 0.4 }}
                  whileHover={{ opacity: 1 }}
                >
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                    <line x1="8" y1="6" x2="16" y2="6" />
                    <line x1="8" y1="12" x2="16" y2="12" />
                    <line x1="8" y1="18" x2="16" y2="18" />
                  </svg>
                </motion.span>
              ) : isOk ? (
                <span className="dgb-order-check">✓</span>
              ) : (
                <span className="dgb-order-wrong">✗</span>
              )}
            </Reorder.Item>
          );
        })}
      </Reorder.Group>
      <div className="dgb-order-actions">
        <button type="button" className="dgb-order-submit" disabled={submitted} onClick={handleSubmit}>提交</button>
        {submitted && !isCorrect ? (
          <button type="button" className="dgb-order-reset" onClick={handleReset}>重做</button>
        ) : null}
        {submitted ? (
          <span className={`dgb-order-score ${isCorrect ? 'ok' : 'ng'}`}>
            {order.filter((id, i) => id === correctOrder[i]).length} / {order.length} 正确
          </span>
        ) : null}
      </div>
      <GameWinBanner
        show={isCorrect}
        text={`🎉 顺序全对！最终得分 ${score}`}
        onReplay={handleReset}
        stars={stars}
        onShow={playWin}
      />
    </div>
  );
}
