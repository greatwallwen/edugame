import { useState } from 'react';
import type { InteractiveSpec } from '@dgbook/types';
import { motion, AnimatePresence } from 'framer-motion';
import './FlashcardBlock.css';

export interface FlashcardBlockProps {
  spec: Extract<InteractiveSpec, { kind: 'flashcard' }>;
}

export function FlashcardBlock({ spec }: FlashcardBlockProps) {
  const [idx, setIdx] = useState(0);
  const [flipped, setFlipped] = useState(false);
  const [known, setKnown] = useState<Set<string>>(new Set());
  const [review, setReview] = useState<Set<string>>(new Set());
  const [direction, setDirection] = useState(1);

  const card = spec.cards[idx]!;
  const total = spec.cards.length;
  const knownCount = known.size;
  const reviewCount = review.size;

  function next() {
    setFlipped(false);
    setDirection(1);
    setIdx((i) => (i + 1) % total);
  }
  function prev() {
    setFlipped(false);
    setDirection(-1);
    setIdx((i) => (i - 1 + total) % total);
  }
  function markKnown() {
    setKnown((k) => new Set([...k, card.id]));
    setReview((r) => { const n = new Set(r); n.delete(card.id); return n; });
    next();
  }
  function markReview() {
    setReview((r) => new Set([...r, card.id]));
    setKnown((k) => { const n = new Set(k); n.delete(card.id); return n; });
    next();
  }

  return (
    <div className="dgb-flashcard">
      <div className="dgb-flashcard-head">
        <span className="dgb-flashcard-badge">互动 · 闪卡</span>
        {spec.prompt ? <span className="dgb-flashcard-prompt">{spec.prompt}</span> : null}
        <span className="dgb-flashcard-count">{idx + 1} / {total}</span>
      </div>

      <div className="dgb-flashcard-deck">
        <AnimatePresence mode="wait" initial={false}>
          <motion.button
            key={idx}
            type="button"
            className="dgb-flashcard-card"
            onClick={() => setFlipped((f) => !f)}
            aria-label={flipped ? '点击翻转回正面' : '点击翻转看答案'}
            initial={{ x: direction * 60, opacity: 0 }}
            animate={{ x: 0, opacity: 1, rotateY: flipped ? 180 : 0 }}
            exit={{ x: direction * -60, opacity: 0, rotateY: flipped ? 180 : 0 }}
            transition={{ type: 'spring', stiffness: 260, damping: 22 }}
            style={{ transformStyle: 'preserve-3d' }}
          >
            <div className="dgb-flashcard-face dgb-flashcard-front" style={{ backfaceVisibility: 'hidden' }}>
              <span className="dgb-flashcard-hint">点击翻转</span>
              <p className="dgb-flashcard-front-text">{card.front}</p>
              {card.hint ? <span className="dgb-flashcard-front-hint">💡 {card.hint}</span> : null}
            </div>
            <div
              className="dgb-flashcard-face dgb-flashcard-back"
              style={{ backfaceVisibility: 'hidden', position: 'absolute', inset: 20, transform: 'rotateY(180deg)' }}
            >
              <p className="dgb-flashcard-back-text">{card.back}</p>
            </div>
          </motion.button>
        </AnimatePresence>
      </div>

      <div className="dgb-flashcard-nav">
        <motion.button type="button" className="dgb-flashcard-navbtn" onClick={prev} aria-label="上一张" whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }}>◀</motion.button>
        <motion.button type="button" className="dgb-flashcard-action dgb-flashcard-review" onClick={markReview} whileHover={{ scale: 1.03, y: -1 }} whileTap={{ scale: 0.97 }}>
          需要复习
        </motion.button>
        <motion.button type="button" className="dgb-flashcard-action dgb-flashcard-known" onClick={markKnown} whileHover={{ scale: 1.03, y: -1 }} whileTap={{ scale: 0.97 }}>
          已掌握
        </motion.button>
        <motion.button type="button" className="dgb-flashcard-navbtn" onClick={next} aria-label="下一张" whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }}>▶</motion.button>
      </div>

      <div className="dgb-flashcard-progress">
        <div className="dgb-flashcard-progress-bar">
          <motion.div className="dgb-flashcard-progress-known" initial={false} animate={{ width: `${(knownCount / total) * 100}%` }} transition={{ type: 'spring', stiffness: 200, damping: 20 }} />
          <motion.div className="dgb-flashcard-progress-review" initial={false} animate={{ width: `${(reviewCount / total) * 100}%`, left: `${(knownCount / total) * 100}%` }} transition={{ type: 'spring', stiffness: 200, damping: 20 }} />
        </div>
        <div className="dgb-flashcard-progress-labels">
          <span className="dgb-flashcard-label-known">已掌握 {knownCount}</span>
          <span className="dgb-flashcard-label-review">需复习 {reviewCount}</span>
          <span className="dgb-flashcard-label-new">新卡片 {total - knownCount - reviewCount}</span>
        </div>
      </div>

      {/* 所有卡片完成后显示参考答案汇总 */}
      {knownCount + reviewCount >= total && total > 0 && (
        <div className="dgb-flashcard-summary">
          <div className="dgb-flashcard-summary-title">📋 全部卡片参考答案</div>
          {spec.cards.map((c, i) => (
            <div key={c.id} className="dgb-flashcard-summary-row">
              <span className="dgb-flashcard-summary-q">Q{i + 1}. {c.front}</span>
              <span className="dgb-flashcard-summary-a">→ {c.back}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
