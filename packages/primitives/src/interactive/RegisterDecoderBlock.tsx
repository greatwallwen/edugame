/**
 * RegisterDecoderBlock — 寄存器位段解码（第 25 种题型）
 *
 * 给定寄存器十六进制值，学生为每个关键位段选择正确含义。
 * 比 bit-flip 进阶：分析整段寄存器语义（如 GPIOx_CRL 的 MODE/CNF 位段）。
 */
import { useState } from 'react';
import type { InteractiveSpec } from '@dgbook/types';
import { useGameScore, GameStat, GameWinBanner } from '../game-kit';
import './games-iter53.css';

type Spec = Extract<InteractiveSpec, { kind: 'register-decoder' }>;

export function RegisterDecoderBlock({ spec }: { spec: Spec }) {
  const [sel, setSel] = useState<Record<string, number>>({});
  const [done, setDone] = useState(false);
  const { score, combo, register, reset, stars, playWin } = useGameScore();

  const allCorrect = spec.fields.every((f) => sel[f.id] === f.answer);
  const correct = done && allCorrect;

  const submit = () => {
    if (Object.keys(sel).length < spec.fields.length) return;
    register(allCorrect);
    setDone(true);
  };
  const replay = () => { setSel({}); setDone(false); reset(); };

  return (
    <div className="dgb-ig">
      <div className="dgb-ig-head">
        <span className="dgb-ig-badge">⬓ 寄存器解码</span>
        <span className="dgb-ig-prompt">{spec.prompt}</span>
        <GameStat score={score} combo={combo} />
      </div>
      <div className="dgb-ig-reg" style={{ fontFamily: 'monospace', fontSize: '1.05rem', margin: '8px 0', padding: '6px 10px', background: 'rgba(99,102,241,0.08)', borderRadius: 6 }}>
        {spec.registerName} = <strong>{spec.registerValue}</strong>
      </div>
      <div className="dgb-ig-opts">
        {spec.fields.map((f) => (
          <div key={f.id} style={{ marginBottom: 10 }}>
            <div style={{ fontWeight: 600, marginBottom: 4 }}>{f.label}</div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {f.options.map((opt, i) => {
                const cls = done
                  ? (i === f.answer ? 'ok' : sel[f.id] === i ? 'ng' : '')
                  : (sel[f.id] === i ? 'sel' : '');
                return (
                  <button
                    key={i}
                    type="button"
                    className={`dgb-ig-opt ${cls}`}
                    disabled={done}
                    onClick={() => setSel((s) => ({ ...s, [f.id]: i }))}
                  >
                    {done && i === f.answer ? '✓ ' : ''}{opt}
                  </button>
                );
              })}
            </div>
          </div>
        ))}
      </div>
      <div className="dgb-ig-actions">
        <button type="button" className="dgb-ig-btn" disabled={done || Object.keys(sel).length < spec.fields.length} onClick={submit}>提交</button>
        {done && !correct ? <button type="button" className="dgb-ig-btn ghost" onClick={replay}>重做</button> : null}
        {done ? <span className={`dgb-ig-res ${correct ? 'ok' : 'ng'}`}>{correct ? '全部解码正确' : '部分位段有误'}</span> : null}
      </div>
      {done && spec.explanation ? <div className="dgb-ig-expl">{spec.explanation}</div> : null}
      <GameWinBanner show={correct} text={`🎉 寄存器解码成功！得分 ${score}`} onReplay={replay} stars={stars} onShow={playWin} />
    </div>
  );
}
