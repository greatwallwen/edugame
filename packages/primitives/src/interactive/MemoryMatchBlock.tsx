import { useMemo, useState, useCallback, useEffect } from 'react';
import type { InteractiveSpec } from '@dgbook/types';
import { motion, AnimatePresence } from 'framer-motion';
import { triggerSmallConfetti } from '../utils/confetti';
import './MemoryMatchBlock.css';

export interface MemoryMatchBlockProps {
  spec: Extract<InteractiveSpec, { kind: 'memory-match' }>;
}

type CardState = 'hidden' | 'revealed' | 'matched';

interface Card {
  id: string;
  side: 'front' | 'back';
  text: string;
  pairId: string;
  state: CardState;
}

export function MemoryMatchBlock({ spec }: MemoryMatchBlockProps) {
  const cards = useMemo(() => {
    const out: Card[] = [];
    for (const p of spec.pairs) {
      out.push({ id: `F-${p.id}`, side: 'front', text: p.front, pairId: p.id, state: 'hidden' });
      out.push({ id: `B-${p.id}`, side: 'back', text: p.back, pairId: p.id, state: 'hidden' });
    }
    // Shuffle
    let s = 0;
    for (let i = 0; i < out.length; i++) s = (s * 31 + out[i]!.text.charCodeAt(0)) >>> 0;
    for (let i = out.length - 1; i > 0; i--) {
      s = (s * 1103515245 + 12345) >>> 0;
      const j = s % (i + 1);
      [out[i], out[j]] = [out[j]!, out[i]!];
    }
    return out;
  }, [spec]);

  const [states, setStates] = useState<Record<string, CardState>>(() => {
    const m: Record<string, CardState> = {};
    for (const c of cards) m[c.id] = 'hidden';
    return m;
  });
  const [revealed, setRevealed] = useState<string[]>([]);
  const [matchedPairs, setMatchedPairs] = useState<Set<string>>(new Set());
  const [moves, setMoves] = useState(0);
  const [lock, setLock] = useState(false);

  const allMatched = matchedPairs.size === spec.pairs.length;

  useEffect(() => {
    if (allMatched) {
      const timer = setTimeout(() => triggerSmallConfetti(), 300);
      return () => clearTimeout(timer);
    }
  }, [allMatched]);

  const reveal = useCallback((cardId: string) => {
    if (lock || states[cardId] !== 'hidden') return;
    if (revealed.length >= 2) return;

    const nextRevealed = [...revealed, cardId];
    setRevealed(nextRevealed);
    setStates((cur) => ({ ...cur, [cardId]: 'revealed' }));

    if (nextRevealed.length === 2) {
      setMoves((m) => m + 1);
      setLock(true);
      const [a, b] = nextRevealed as [string, string];
      const cardA = cards.find((c) => c.id === a)!;
      const cardB = cards.find((c) => c.id === b)!;

      if (cardA.pairId === cardB.pairId) {
        setTimeout(() => {
          setStates((cur) => ({ ...cur, [a]: 'matched' as const, [b]: 'matched' as const }));
          setMatchedPairs((prev) => new Set([...prev, cardA.pairId]));
          setRevealed([]);
          setLock(false);
        }, 600);
      } else {
        setTimeout(() => {
          setStates((cur) => ({ ...cur, [a]: 'hidden' as const, [b]: 'hidden' as const }));
          setRevealed([]);
          setLock(false);
        }, 1000);
      }
    }
  }, [lock, states, revealed, cards]);

  function reset() {
    const m: Record<string, CardState> = {};
    for (const c of cards) m[c.id] = 'hidden';
    setStates(m);
    setRevealed([]);
    setMatchedPairs(new Set());
    setMoves(0);
    setLock(false);
  }

  const cols = cards.length <= 6 ? 3 : cards.length <= 12 ? 4 : 6;

  return (
    <div className="dgb-memory">
      <div className="dgb-memory-head">
        <span className="dgb-memory-badge">互动 · 记忆配对</span>
        {spec.prompt ? <span className="dgb-memory-prompt">{spec.prompt}</span> : null}
        <span className="dgb-memory-stats">步数：{moves} · 配对：{matchedPairs.size}/{spec.pairs.length}</span>
      </div>
      <div className="dgb-memory-grid" style={{ gridTemplateColumns: `repeat(${cols}, 1fr)` }}>
        {cards.map((card) => {
          const st = states[card.id];
          return (
            <motion.button
              key={card.id}
              type="button"
              className={`dgb-memory-card ${st}`}
              disabled={st === 'matched' || lock}
              onClick={() => reveal(card.id)}
              aria-label={st === 'hidden' ? '点击翻牌' : card.text}
              whileHover={st === 'hidden' && !lock ? { scale: 1.03, y: -2 } : undefined}
              whileTap={st === 'hidden' && !lock ? { scale: 0.95 } : undefined}
              animate={
                st === 'matched'
                  ? { scale: [1, 1.08, 1], transition: { duration: 0.4 } }
                  : st === 'revealed'
                    ? { scale: 1, rotateY: 0 }
                    : { scale: 1, rotateY: 0 }
              }
              transition={{ type: 'spring', stiffness: 300, damping: 20 }}
            >
              <span className="dgb-memory-card-text">{st === 'hidden' ? '?' : card.text}</span>
            </motion.button>
          );
        })}
      </div>
      <AnimatePresence>
        {allMatched && (
          <motion.div
            className="dgb-memory-win"
            initial={{ opacity: 0, y: 20, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -10 }}
            transition={{ type: 'spring', stiffness: 200, damping: 18 }}
          >
            🎉 全部配对成功！用了 {moves} 步
            <motion.button
              type="button"
              className="dgb-memory-reset"
              onClick={reset}
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
            >
              再玩一次
            </motion.button>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
