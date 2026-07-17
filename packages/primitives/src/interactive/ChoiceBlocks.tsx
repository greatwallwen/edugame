import { useState } from 'react';
import type { InteractiveSpec } from '@dgbook/types';
import { useGameScore, GameStat, GameWinBanner } from '../game-kit';
import './games-iter53.css';

/** 单选题 */
export function SingleChoiceBlock({ spec }: { spec: Extract<InteractiveSpec, { kind: 'single-choice' }> }) {
  const [sel, setSel] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const { score, combo, register, reset, stars, playWin } = useGameScore();
  const correct = done && sel === spec.answer;
  const submit = () => { if (sel == null) return; register(sel === spec.answer); setDone(true); };
  const replay = () => { setSel(null); setDone(false); reset(); };
  return (
    <div className="dgb-ig">
      <div className="dgb-ig-head">
        <span className="dgb-ig-badge">◉ 单选题</span>
        <span className="dgb-ig-prompt">{spec.prompt}</span>
        <GameStat score={score} combo={combo} />
      </div>
      <div className="dgb-ig-opts">
        {spec.options.map((o) => {
          const cls = done ? (o.id === spec.answer ? 'ok' : o.id === sel ? 'ng' : '') : (o.id === sel ? 'sel' : '');
          return (
            <button key={o.id} type="button" className={`dgb-ig-opt radio ${cls}`} disabled={done} onClick={() => setSel(o.id)}>
              <span className="mk">{done && o.id === spec.answer ? '✓' : o.id === sel ? '●' : ''}</span>{o.text}
            </button>
          );
        })}
      </div>
      <div className="dgb-ig-actions">
        <button type="button" className="dgb-ig-btn" disabled={done || sel == null} onClick={submit}>提交</button>
        {done && !correct ? <button type="button" className="dgb-ig-btn ghost" onClick={replay}>重做</button> : null}
        {done ? <span className={`dgb-ig-res ${correct ? 'ok' : 'ng'}`}>{correct ? '回答正确' : '再想想'}</span> : null}
      </div>
      {done && spec.explanation ? <div className="dgb-ig-expl">{spec.explanation}</div> : null}
      <GameWinBanner show={correct} text={`🎉 答对了！得分 ${score}`} onReplay={replay} stars={stars} onShow={playWin} />
    </div>
  );
}

/** 多选题：全部命中才算对 */
export function MultipleChoiceBlock({ spec }: { spec: Extract<InteractiveSpec, { kind: 'multiple-choice' }> }) {
  const [sel, setSel] = useState<Set<string>>(new Set());
  const [done, setDone] = useState(false);
  const { score, combo, register, reset, stars, playWin } = useGameScore();
  const ans = new Set(spec.answers);
  const correct = done && sel.size === ans.size && [...sel].every((id) => ans.has(id));
  const toggle = (id: string) => setSel((s) => { const n = new Set(s); n.has(id) ? n.delete(id) : n.add(id); return n; });
  const submit = () => { register(sel.size === ans.size && [...sel].every((id) => ans.has(id))); setDone(true); };
  const replay = () => { setSel(new Set()); setDone(false); reset(); };
  return (
    <div className="dgb-ig">
      <div className="dgb-ig-head">
        <span className="dgb-ig-badge">☑ 多选题</span>
        <span className="dgb-ig-prompt">{spec.prompt}</span>
        <GameStat score={score} combo={combo} />
      </div>
      <div className="dgb-ig-opts">
        {spec.options.map((o) => {
          const cls = done ? (ans.has(o.id) ? 'ok' : sel.has(o.id) ? 'ng' : '') : (sel.has(o.id) ? 'sel' : '');
          return (
            <button key={o.id} type="button" className={`dgb-ig-opt ${cls}`} disabled={done} onClick={() => toggle(o.id)}>
              <span className="mk">{(done ? ans.has(o.id) : sel.has(o.id)) ? '✓' : ''}</span>{o.text}
            </button>
          );
        })}
      </div>
      <div className="dgb-ig-actions">
        <button type="button" className="dgb-ig-btn" disabled={done || sel.size === 0} onClick={submit}>提交</button>
        {done && !correct ? <button type="button" className="dgb-ig-btn ghost" onClick={replay}>重做</button> : null}
        {done ? <span className={`dgb-ig-res ${correct ? 'ok' : 'ng'}`}>{correct ? '全部命中' : '有遗漏或多选'}</span> : null}
      </div>
      {done && spec.explanation ? <div className="dgb-ig-expl">{spec.explanation}</div> : null}
      <GameWinBanner show={correct} text={`🎉 多选全对！得分 ${score}`} onReplay={replay} stars={stars} onShow={playWin} />
    </div>
  );
}

/** 判断题：逐条判对错 */
export function TrueFalseBlock({ spec }: { spec: Extract<InteractiveSpec, { kind: 'true-false' }> }) {
  const [picks, setPicks] = useState<Record<string, boolean>>({});
  const [done, setDone] = useState(false);
  const { score, combo, register, reset, stars, playWin } = useGameScore();
  const allAnswered = spec.statements.every((s) => s.id in picks);
  const rightCount = spec.statements.filter((s) => picks[s.id] === s.correct).length;
  const allCorrect = done && rightCount === spec.statements.length;
  const submit = () => { spec.statements.forEach((s) => register(picks[s.id] === s.correct)); setDone(true); };
  const replay = () => { setPicks({}); setDone(false); reset(); };
  return (
    <div className="dgb-ig">
      <div className="dgb-ig-head">
        <span className="dgb-ig-badge">⚖ 判断题</span>
        {spec.prompt ? <span className="dgb-ig-prompt">{spec.prompt}</span> : <span className="dgb-ig-prompt">判断下列说法的对错</span>}
        <GameStat score={score} combo={combo} />
      </div>
      <div className="dgb-ig-opts">
        {spec.statements.map((s) => {
          const picked = picks[s.id];
          const judged = done && picked === s.correct;
          return (
            <div key={s.id} className={`dgb-ig-opt ${done ? (judged ? 'ok' : 'ng') : ''}`} style={{ cursor: 'default', justifyContent: 'space-between' }}>
              <span>{s.text}</span>
              <span style={{ display: 'flex', gap: 6 }}>
                {[true, false].map((v) => (
                  <button key={String(v)} type="button" disabled={done}
                    onClick={() => setPicks((p) => ({ ...p, [s.id]: v }))}
                    className="dgb-ig-btn" style={{
                      padding: '4px 12px',
                      background: picked === v ? (v ? '#16a34a' : '#dc2626') : '#f1f5f9',
                      color: picked === v ? '#fff' : '#475569',
                    }}>{v ? '✓ 对' : '✗ 错'}</button>
                ))}
              </span>
            </div>
          );
        })}
      </div>
      <div className="dgb-ig-actions">
        <button type="button" className="dgb-ig-btn" disabled={done || !allAnswered} onClick={submit}>提交</button>
        {done && !allCorrect ? <button type="button" className="dgb-ig-btn ghost" onClick={replay}>重做</button> : null}
        {done ? <span className={`dgb-ig-res ${allCorrect ? 'ok' : 'ng'}`}>{rightCount}/{spec.statements.length} 正确</span> : null}
      </div>
      <GameWinBanner show={allCorrect} text={`🎉 判断全对！得分 ${score}`} onReplay={replay} stars={stars} onShow={playWin} />
    </div>
  );
}
