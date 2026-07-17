import { useState } from 'react';
import type { InteractiveSpec } from '@dgbook/types';
import { useGameScore, GameStat, GameWinBanner } from '../game-kit';
import './games-iter53.css';

type ParamSpec = { id: string; label: string; min: number; max: number; step?: number; target: number; tolerance?: number; unit?: string };

function useSliders(params: ParamSpec[]) {
  const [vals, setVals] = useState<Record<string, number>>(() => Object.fromEntries(params.map((p) => [p.id, (p.min + p.max) / 2])));
  const set = (id: string, v: number) => setVals((s) => ({ ...s, [id]: v }));
  const resetVals = () => setVals(Object.fromEntries(params.map((p) => [p.id, (p.min + p.max) / 2])));
  const hit = (p: ParamSpec) => Math.abs((vals[p.id] ?? 0) - p.target) <= (p.tolerance ?? (p.max - p.min) * 0.03);
  return { vals, set, resetVals, hit };
}

function Sliders({ params, vals, set, done, hit }: { params: ParamSpec[]; vals: Record<string, number>; set: (id: string, v: number) => void; done: boolean; hit: (p: ParamSpec) => boolean }) {
  return (
    <>
      {params.map((p) => (
        <div key={p.id} className="dgb-ig-slider">
          <label><span>{p.label}{done ? (hit(p) ? ' ✓' : ' ✗') : ''}</span>
            <span className="dgb-ig-val" style={done ? { color: hit(p) ? '#16a34a' : '#dc2626' } : undefined}>{vals[p.id]}{p.unit ?? ''}</span></label>
          <input type="range" min={p.min} max={p.max} step={p.step ?? 1} value={vals[p.id] ?? 0}
            disabled={done} onChange={(e) => set(p.id, Number(e.target.value))} />
        </div>
      ))}
    </>
  );
}

/** 波形参数调节器：调参使波形匹配目标，带 SVG 实时预览 */
export function WaveformTunerBlock({ spec }: { spec: Extract<InteractiveSpec, { kind: 'waveform-tuner' }> }) {
  const params = spec.params as ParamSpec[];
  const { vals, set, resetVals, hit } = useSliders(params);
  const [done, setDone] = useState(false);
  const { score, combo, register, reset, stars, playWin } = useGameScore();
  const allHit = done && params.every(hit);
  const submit = () => { params.forEach((p) => register(hit(p))); setDone(true); };
  const replay = () => { resetVals(); setDone(false); reset(); };
  // 预览：用第一个参数当频率因子画波形
  const freq = params[0] ? (vals[params[0].id] ?? 1) : 1;
  const duty = params[1] ? (vals[params[1].id] ?? 50) / 100 : 0.5;
  const wf = spec.waveform ?? 'square';
  const pts: string[] = [];
  const W = 320, H = 70, cycles = Math.max(1, Math.min(8, Math.round(freq / Math.max(1, (params[0]?.max ?? 10) / 5))));
  for (let x = 0; x <= W; x += 2) {
    const ph = (x / W) * cycles; const fr = ph - Math.floor(ph); let y: number;
    if (wf === 'square') y = fr < duty ? 0.15 : 0.85;
    else if (wf === 'sine') y = 0.5 - 0.35 * Math.sin(ph * 2 * Math.PI);
    else if (wf === 'sawtooth') y = 0.85 - 0.7 * fr;
    else y = fr < 0.5 ? 0.85 - 0.7 * (fr * 2) : 0.15 + 0.7 * ((fr - 0.5) * 2);
    pts.push(`${x},${(y * H).toFixed(1)}`);
  }
  return (
    <div className="dgb-ig">
      <div className="dgb-ig-head">
        <span className="dgb-ig-badge">〜 波形调节</span>
        <span className="dgb-ig-prompt">{spec.prompt}</span>
        <GameStat score={score} combo={combo} />
      </div>
      <svg className="dgb-ig-wave" viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none">
        <polyline points={pts.join(' ')} fill="none" stroke="#34d399" strokeWidth="2" />
      </svg>
      <Sliders params={params} vals={vals} set={set} done={done} hit={hit} />
      <div className="dgb-ig-actions">
        <button type="button" className="dgb-ig-btn" disabled={done} onClick={submit}>提交</button>
        {done && !allHit ? <button type="button" className="dgb-ig-btn ghost" onClick={replay}>重调</button> : null}
        {done ? <span className={`dgb-ig-res ${allHit ? 'ok' : 'ng'}`}>{params.filter(hit).length}/{params.length} 参数命中</span> : null}
      </div>
      {done && spec.explanation ? <div className="dgb-ig-expl">{spec.explanation}</div> : null}
      <GameWinBanner show={allHit} text={`🎉 波形匹配！得分 ${score}`} onReplay={replay} stars={stars} onShow={playWin} />
    </div>
  );
}

/** 参数匹配：一组滑块同时调到各自目标 */
export function ParameterMatchBlock({ spec }: { spec: Extract<InteractiveSpec, { kind: 'parameter-match' }> }) {
  const params = spec.params as ParamSpec[];
  const { vals, set, resetVals, hit } = useSliders(params);
  const [done, setDone] = useState(false);
  const { score, combo, register, reset, stars, playWin } = useGameScore();
  const allHit = done && params.every(hit);
  const submit = () => { params.forEach((p) => register(hit(p))); setDone(true); };
  const replay = () => { resetVals(); setDone(false); reset(); };
  return (
    <div className="dgb-ig">
      <div className="dgb-ig-head">
        <span className="dgb-ig-badge">🎛 参数匹配</span>
        <span className="dgb-ig-prompt">{spec.prompt}</span>
        <GameStat score={score} combo={combo} />
      </div>
      <Sliders params={params} vals={vals} set={set} done={done} hit={hit} />
      <div className="dgb-ig-actions">
        <button type="button" className="dgb-ig-btn" disabled={done} onClick={submit}>提交</button>
        {done && !allHit ? <button type="button" className="dgb-ig-btn ghost" onClick={replay}>重调</button> : null}
        {done ? <span className={`dgb-ig-res ${allHit ? 'ok' : 'ng'}`}>{params.filter(hit).length}/{params.length} 参数命中</span> : null}
      </div>
      {done && spec.explanation ? <div className="dgb-ig-expl">{spec.explanation}</div> : null}
      <GameWinBanner show={allHit} text={`🎉 全部命中！得分 ${score}`} onReplay={replay} stars={stars} onShow={playWin} />
    </div>
  );
}
