import { useState } from 'react';
import type { InteractiveSpec } from '@dgbook/types';
import { useGameScore, GameStat, GameWinBanner } from '../game-kit';
import './games-iter53.css';

const BASE_LABEL: Record<number, string> = { 2: '二进制', 8: '八进制', 10: '十进制', 16: '十六进制' };

/** 进制转换：把给定数从源进制转到目标进制并输入 */
export function BaseConverterBlock({ spec }: { spec: Extract<InteractiveSpec, { kind: 'base-converter' }> }) {
  const [inputs, setInputs] = useState<Record<string, string>>({});
  const [done, setDone] = useState(false);
  const { score, combo, register, reset, stars, playWin } = useGameScore();
  const norm = (s: string) => s.trim().toLowerCase().replace(/^0x|^0b/, '');
  const rightCount = spec.tasks.filter((t) => norm(inputs[t.id] ?? '') === norm(t.answer)).length;
  const allCorrect = done && rightCount === spec.tasks.length;
  const submit = () => { spec.tasks.forEach((t) => register(norm(inputs[t.id] ?? '') === norm(t.answer))); setDone(true); };
  const replay = () => { setInputs({}); setDone(false); reset(); };
  return (
    <div className="dgb-ig">
      <div className="dgb-ig-head">
        <span className="dgb-ig-badge">⇄ 进制转换</span>
        {spec.prompt ? <span className="dgb-ig-prompt">{spec.prompt}</span> : <span className="dgb-ig-prompt">完成下列进制转换</span>}
        <GameStat score={score} combo={combo} />
      </div>
      <div className="dgb-ig-opts">
        {spec.tasks.map((t) => {
          const ok = done && norm(inputs[t.id] ?? '') === norm(t.answer);
          return (
            <div key={t.id} className="dgb-ig-field">
              <span className="q">把 <b>{t.value}</b>（{BASE_LABEL[t.fromBase]}）转为 {BASE_LABEL[t.toBase]} =</span>
              <input value={inputs[t.id] ?? ''} disabled={done} className={done ? (ok ? 'ok' : 'ng') : ''}
                onChange={(e) => setInputs((p) => ({ ...p, [t.id]: e.target.value }))} placeholder="输入结果" />
              {done && !ok ? <span style={{ color: '#dc2626', fontSize: 13 }}>答案：{t.answer}</span> : null}
            </div>
          );
        })}
      </div>
      <div className="dgb-ig-actions">
        <button type="button" className="dgb-ig-btn" disabled={done} onClick={submit}>提交</button>
        {done && !allCorrect ? <button type="button" className="dgb-ig-btn ghost" onClick={replay}>重做</button> : null}
        {done ? <span className={`dgb-ig-res ${allCorrect ? 'ok' : 'ng'}`}>{rightCount}/{spec.tasks.length} 正确</span> : null}
      </div>
      <GameWinBanner show={allCorrect} text={`🎉 进制全对！得分 ${score}`} onReplay={replay} stars={stars} onShow={playWin} />
    </div>
  );
}

/** 寄存器配置器：用下拉配置多字段使寄存器达到目标 */
export function RegisterConfigBlock({ spec }: { spec: Extract<InteractiveSpec, { kind: 'register-config' }> }) {
  const [picks, setPicks] = useState<Record<string, string>>({});
  const [done, setDone] = useState(false);
  const { score, combo, register, reset, stars, playWin } = useGameScore();
  const rightCount = spec.fields.filter((f) => picks[f.id] === f.answer).length;
  const allCorrect = done && rightCount === spec.fields.length;
  const submit = () => { spec.fields.forEach((f) => register(picks[f.id] === f.answer)); setDone(true); };
  const replay = () => { setPicks({}); setDone(false); reset(); };
  return (
    <div className="dgb-ig">
      <div className="dgb-ig-head">
        <span className="dgb-ig-badge">⚙ 寄存器配置</span>
        <span className="dgb-ig-prompt">{spec.prompt}</span>
        <GameStat score={score} combo={combo} />
      </div>
      {spec.registerName ? <code style={{ fontSize: 13, color: '#0E7C4A', fontWeight: 700 }}>{spec.registerName}</code> : null}
      <div className="dgb-ig-opts">
        {spec.fields.map((f) => {
          const ok = done && picks[f.id] === f.answer;
          return (
            <div key={f.id} className="dgb-ig-field">
              <span className="q">{f.label}</span>
              <select value={picks[f.id] ?? ''} disabled={done} className={done ? (ok ? 'ok' : 'ng') : ''}
                onChange={(e) => setPicks((p) => ({ ...p, [f.id]: e.target.value }))}>
                <option value="">— 选择 —</option>
                {f.options.map((o) => <option key={o} value={o}>{o}</option>)}
              </select>
              {f.hint ? <span className="dgb-ig-hint">{f.hint}</span> : null}
              {done && !ok ? <span style={{ color: '#dc2626', fontSize: 13 }}>应为 {f.answer}</span> : null}
            </div>
          );
        })}
      </div>
      <div className="dgb-ig-actions">
        <button type="button" className="dgb-ig-btn" disabled={done} onClick={submit}>提交配置</button>
        {done && !allCorrect ? <button type="button" className="dgb-ig-btn ghost" onClick={replay}>重做</button> : null}
        {done ? <span className={`dgb-ig-res ${allCorrect ? 'ok' : 'ng'}`}>{rightCount}/{spec.fields.length} 正确</span> : null}
      </div>
      {done && spec.explanation ? <div className="dgb-ig-expl">{spec.explanation}</div> : null}
      <GameWinBanner show={allCorrect} text={`🎉 配置正确！得分 ${score}`} onReplay={replay} stars={stars} onShow={playWin} />
    </div>
  );
}
