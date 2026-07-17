import { useState, useMemo } from 'react';
import type { InteractiveSpec } from '@dgbook/types';
import { useGameScore, GameStat, GameWinBanner } from '../game-kit';
import './games-iter53.css';

/** 流程拼装：从候选步骤按正确顺序逐个选入流程槽 */
export function SequenceBuilderBlock({ spec }: { spec: Extract<InteractiveSpec, { kind: 'sequence-builder' }> }) {
  const [picked, setPicked] = useState<string[]>([]);
  const [done, setDone] = useState(false);
  const { score, combo, register, reset, stars, playWin } = useGameScore();
  const textOf = useMemo(() => new Map(spec.steps.map((s) => [s.id, s.text])), [spec]);
  const target = spec.correctSequence;
  const correct = done && picked.length === target.length && picked.every((id, i) => id === target[i]);
  const avail = spec.steps.filter((s) => !picked.includes(s.id));
  const choose = (id: string) => { if (done) return; setPicked((p) => [...p, id]); };
  const undo = () => setPicked((p) => p.slice(0, -1));
  const submit = () => { target.forEach((id, i) => register(picked[i] === id)); setDone(true); };
  const replay = () => { setPicked([]); setDone(false); reset(); };
  return (
    <div className="dgb-ig">
      <div className="dgb-ig-head">
        <span className="dgb-ig-badge">🧩 流程拼装</span>
        <span className="dgb-ig-prompt">{spec.prompt}</span>
        <GameStat score={score} combo={combo} />
      </div>
      <div className="dgb-ig-labels">
        {picked.map((id, i) => {
          const ok = done && id === target[i];
          return <span key={id} className={`dgb-ig-label sel ${done ? (ok ? '' : '') : ''}`}
            style={done ? { borderColor: ok ? '#16a34a' : '#dc2626', background: ok ? '#dcfce7' : '#fee2e2' } : undefined}>
            {i + 1}. {textOf.get(id)}</span>;
        })}
        {picked.length === 0 ? <span className="dgb-ig-hint">点击下方步骤，按正确顺序拼装流程 ↓</span> : null}
      </div>
      <div className="dgb-ig-labels">
        {avail.map((s) => <button key={s.id} type="button" className="dgb-ig-label" onClick={() => choose(s.id)}>{s.text}</button>)}
      </div>
      <div className="dgb-ig-actions">
        <button type="button" className="dgb-ig-btn" disabled={done || picked.length !== target.length} onClick={submit}>提交</button>
        {!done && picked.length > 0 ? <button type="button" className="dgb-ig-btn ghost" onClick={undo}>撤销</button> : null}
        {done && !correct ? <button type="button" className="dgb-ig-btn ghost" onClick={replay}>重做</button> : null}
        {done ? <span className={`dgb-ig-res ${correct ? 'ok' : 'ng'}`}>{picked.filter((id, i) => id === target[i]).length}/{target.length} 正确</span> : null}
      </div>
      {done && spec.explanation ? <div className="dgb-ig-expl">{spec.explanation}</div> : null}
      <GameWinBanner show={correct} text={`🎉 流程正确！得分 ${score}`} onReplay={replay} stars={stars} onShow={playWin} />
    </div>
  );
}

/** 真值表填写：给逻辑表达式填每行输出列 */
export function TruthTableBlock({ spec }: { spec: Extract<InteractiveSpec, { kind: 'truth-table' }> }) {
  const [vals, setVals] = useState<Record<string, 0 | 1>>({});
  const [done, setDone] = useState(false);
  const { score, combo, register, reset, stars, playWin } = useGameScore();
  const key = (r: number, c: number) => `${r}-${c}`;
  const toggle = (r: number, c: number) => { if (done) return; setVals((v) => ({ ...v, [key(r, c)]: v[key(r, c)] === 1 ? 0 : 1 })); };
  const total = spec.rows.length * spec.outputs.length;
  const rightCount = spec.rows.reduce((acc, row, r) => acc + row.out.filter((o, c) => (vals[key(r, c)] ?? 0) === o).length, 0);
  const allCorrect = done && rightCount === total;
  const submit = () => { spec.rows.forEach((row, r) => row.out.forEach((o, c) => register((vals[key(r, c)] ?? 0) === o))); setDone(true); };
  const replay = () => { setVals({}); setDone(false); reset(); };
  return (
    <div className="dgb-ig">
      <div className="dgb-ig-head">
        <span className="dgb-ig-badge">🔢 真值表</span>
        <span className="dgb-ig-prompt">{spec.prompt}</span>
        <GameStat score={score} combo={combo} />
      </div>
      <table className="dgb-ig-table">
        <thead><tr>{spec.inputs.map((h) => <th key={h}>{h}</th>)}{spec.outputs.map((h) => <th key={h}>{h}</th>)}</tr></thead>
        <tbody>
          {spec.rows.map((row, r) => (
            <tr key={r}>
              {row.in.map((v, i) => <td key={i}>{v}</td>)}
              {row.out.map((o, c) => {
                const cur = vals[key(r, c)] ?? 0;
                const cls = done ? (cur === o ? 'ok' : 'ng') : '';
                return <td key={c} className={`out-cell ${cls}`}>
                  <button type="button" className={cur === 1 ? 'set' : ''} onClick={() => toggle(r, c)}>{cur}</button>
                </td>;
              })}
            </tr>
          ))}
        </tbody>
      </table>
      <div className="dgb-ig-actions">
        <button type="button" className="dgb-ig-btn" disabled={done} onClick={submit}>提交</button>
        {done && !allCorrect ? <button type="button" className="dgb-ig-btn ghost" onClick={replay}>重做</button> : null}
        {done ? <span className={`dgb-ig-res ${allCorrect ? 'ok' : 'ng'}`}>{rightCount}/{total} 正确</span> : null}
      </div>
      {done && spec.explanation ? <div className="dgb-ig-expl">{spec.explanation}</div> : null}
      <GameWinBanner show={allCorrect} text={`🎉 真值表全对！得分 ${score}`} onReplay={replay} stars={stars} onShow={playWin} />
    </div>
  );
}
