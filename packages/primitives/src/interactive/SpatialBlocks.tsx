import { useState } from 'react';
import type { InteractiveSpec } from '@dgbook/types';
import { useGameScore, GameStat, GameWinBanner } from '../game-kit';
import './games-iter53.css';

/** 按序点击热点：在图上按正确顺序依次点击 */
export function HotspotSequenceBlock({ spec }: { spec: Extract<InteractiveSpec, { kind: 'hotspot-sequence' }> }) {
  const [clicked, setClicked] = useState<string[]>([]);
  const [done, setDone] = useState(false);
  const { score, combo, register, reset, stars, playWin } = useGameScore();
  const target = spec.correctOrder;
  const correct = done && clicked.length === target.length && clicked.every((id, i) => id === target[i]);
  const onClickSpot = (id: string) => {
    if (done || clicked.includes(id)) return;
    const next = [...clicked, id];
    setClicked(next);
    if (next.length === target.length) { target.forEach((tid, i) => register(next[i] === tid)); setDone(true); }
  };
  const replay = () => { setClicked([]); setDone(false); reset(); };
  return (
    <div className="dgb-ig">
      <div className="dgb-ig-head">
        <span className="dgb-ig-badge">①②③ 顺序点击</span>
        <span className="dgb-ig-prompt">{spec.prompt}</span>
        <GameStat score={score} combo={combo} />
      </div>
      <div className="dgb-ig-canvas" style={{ aspectRatio: '2 / 1', backgroundImage: spec.image ? `url(${spec.image})` : undefined, backgroundSize: 'cover' }}>
        {spec.hotspots.map((h) => {
          const order = clicked.indexOf(h.id);
          const hit = order >= 0;
          const r = h.radius ?? 26;
          return (
            <button key={h.id} type="button" className={`dgb-ig-spot ${hit ? 'hit' : ''}`}
              style={{ left: `${h.x}%`, top: `${h.y}%`, width: r * 2, height: r * 2 }}
              disabled={done} onClick={() => onClickSpot(h.id)} title={h.label}>
              {hit ? order + 1 : '?'}
            </button>
          );
        })}
      </div>
      <div className="dgb-ig-actions">
        {!done ? <span className="dgb-ig-hint">已点 {clicked.length}/{target.length}</span> : null}
        {done && !correct ? <button type="button" className="dgb-ig-btn ghost" onClick={replay}>重试</button> : null}
        {done ? <span className={`dgb-ig-res ${correct ? 'ok' : 'ng'}`}>{clicked.filter((id, i) => id === target[i]).length}/{target.length} 顺序正确</span> : null}
      </div>
      {done && spec.explanation ? <div className="dgb-ig-expl">{spec.explanation}</div> : null}
      <GameWinBanner show={correct} text={`🎉 顺序全对！得分 ${score}`} onReplay={replay} stars={stars} onShow={playWin} />
    </div>
  );
}

/** 拖标签到目标位：点选标签 → 点锚点放置（兼容触屏的"点-点"配对） */
export function DragLabelBlock({ spec }: { spec: Extract<InteractiveSpec, { kind: 'drag-label' }> }) {
  const [placed, setPlaced] = useState<Record<string, string>>({}); // targetId -> labelId
  const [sel, setSel] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const { score, combo, register, reset, stars, playWin } = useGameScore();
  const usedLabels = new Set(Object.values(placed));
  const labelText = new Map(spec.labels.map((l) => [l.id, l.text]));
  const rightCount = spec.targets.filter((t) => placed[t.id] === t.answer).length;
  const allCorrect = done && rightCount === spec.targets.length;
  const placeAt = (targetId: string) => {
    if (done || !sel) return;
    setPlaced((p) => {
      const n = { ...p };
      for (const k of Object.keys(n)) if (n[k] === sel) delete n[k];
      n[targetId] = sel; return n;
    });
    setSel(null);
  };
  const submit = () => { spec.targets.forEach((t) => register(placed[t.id] === t.answer)); setDone(true); };
  const replay = () => { setPlaced({}); setSel(null); setDone(false); reset(); };
  return (
    <div className="dgb-ig">
      <div className="dgb-ig-head">
        <span className="dgb-ig-badge">🏷 标签配位</span>
        <span className="dgb-ig-prompt">{spec.prompt}</span>
        <GameStat score={score} combo={combo} />
      </div>
      <div className="dgb-ig-canvas" style={{ aspectRatio: '2 / 1', backgroundImage: spec.image ? `url(${spec.image})` : undefined, backgroundSize: 'cover' }}>
        {spec.targets.map((t) => {
          const lid = placed[t.id];
          const cls = done ? (lid === t.answer ? 'ok' : 'ng') : (lid ? 'filled' : '');
          return (
            <button key={t.id} type="button" className={`dgb-ig-anchor ${cls}`}
              style={{ left: `${t.x}%`, top: `${t.y}%` }} disabled={done} onClick={() => placeAt(t.id)}>
              {lid ? labelText.get(lid) : '放这里'}
            </button>
          );
        })}
      </div>
      <div className="dgb-ig-labels">
        {spec.labels.map((l) => (
          <button key={l.id} type="button" disabled={done || usedLabels.has(l.id)}
            className={`dgb-ig-label ${usedLabels.has(l.id) ? 'used' : ''} ${sel === l.id ? 'sel' : ''}`}
            onClick={() => setSel(l.id)}>{l.text}</button>
        ))}
      </div>
      <div className="dgb-ig-actions">
        <span className="dgb-ig-hint">{sel ? '已选标签，点上方锚点放置' : '先点一个标签'}</span>
        <button type="button" className="dgb-ig-btn" disabled={done || Object.keys(placed).length !== spec.targets.length} onClick={submit}>提交</button>
        {done && !allCorrect ? <button type="button" className="dgb-ig-btn ghost" onClick={replay}>重做</button> : null}
        {done ? <span className={`dgb-ig-res ${allCorrect ? 'ok' : 'ng'}`}>{rightCount}/{spec.targets.length} 正确</span> : null}
      </div>
      {done && spec.explanation ? <div className="dgb-ig-expl">{spec.explanation}</div> : null}
      <GameWinBanner show={allCorrect} text={`🎉 全部配对！得分 ${score}`} onReplay={replay} stars={stars} onShow={playWin} />
    </div>
  );
}
