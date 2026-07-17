import { useState, useEffect, useRef } from 'react';
import type { InteractiveSpec } from '@dgbook/types';
import { useGameScore, GameStat, GameWinBanner } from '../game-kit';
import './games-iter53.css';

/** 计时快答：限时内连续作答单选小题 */
export function TimedQuizBlock({ spec }: { spec: Extract<InteractiveSpec, { kind: 'timed-quiz' }> }) {
  const [started, setStarted] = useState(false);
  const [qi, setQi] = useState(0);
  const [left, setLeft] = useState(spec.seconds);
  const [done, setDone] = useState(false);
  const { score, combo, register, reset, stars, playWin } = useGameScore();
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    if (!started || done) return;
    timer.current = setInterval(() => {
      setLeft((t) => {
        if (t <= 1) { clearInterval(timer.current!); setDone(true); return 0; }
        return t - 1;
      });
    }, 1000);
    return () => { if (timer.current) clearInterval(timer.current); };
  }, [started, done]);

  const q = spec.questions[qi];
  const pick = (idx: number) => {
    if (!q) return;
    register(idx === q.answer);
    if (qi + 1 >= spec.questions.length) { setDone(true); if (timer.current) clearInterval(timer.current); }
    else setQi(qi + 1);
  };
  const start = () => { setStarted(true); setQi(0); setLeft(spec.seconds); setDone(false); reset(); };
  const finished = done;
  return (
    <div className="dgb-ig">
      <div className="dgb-ig-head">
        <span className="dgb-ig-badge">⏱ 计时快答</span>
        {spec.prompt ? <span className="dgb-ig-prompt">{spec.prompt}</span> : <span className="dgb-ig-prompt">限时连续作答，又快又准！</span>}
        <span className={`dgb-ig-timer ${left <= 5 ? 'low' : ''}`}>⏳ {left}s</span>
        <GameStat score={score} combo={combo} />
      </div>
      {!started ? (
        <div className="dgb-ig-actions"><button type="button" className="dgb-ig-btn" onClick={start}>开始挑战（{spec.seconds}s / {spec.questions.length} 题）</button></div>
      ) : !finished && q ? (
        <>
          <div className="dgb-ig-prompt">第 {qi + 1}/{spec.questions.length} 题：{q.stem}</div>
          <div className="dgb-ig-opts">
            {q.options.map((opt, idx) => (
              <button key={idx} type="button" className="dgb-ig-opt" onClick={() => pick(idx)}>
                <span className="mk">{String.fromCharCode(65 + idx)}</span>{opt}
              </button>
            ))}
          </div>
        </>
      ) : (
        <div className="dgb-ig-actions">
          <span className="dgb-ig-res ok">挑战结束 · 最终得分 {score}</span>
          <button type="button" className="dgb-ig-btn ghost" onClick={start}>再来一次</button>
        </div>
      )}
      <GameWinBanner show={finished && combo >= 2} text={`🎉 计时挑战完成！得分 ${score}`} onReplay={start} stars={stars} onShow={playWin} />
    </div>
  );
}

/** 滑块估值：拖到目标值（容差判定） */
export function SliderEstimateBlock({ spec }: { spec: Extract<InteractiveSpec, { kind: 'slider-estimate' }> }) {
  const mid = (spec.min + spec.max) / 2;
  const [val, setVal] = useState(mid);
  const [done, setDone] = useState(false);
  const { score, combo, register, reset, stars, playWin } = useGameScore();
  const tol = spec.tolerance ?? (spec.max - spec.min) * 0.03;
  const correct = done && Math.abs(val - spec.target) <= tol;
  const submit = () => { register(Math.abs(val - spec.target) <= tol); setDone(true); };
  const replay = () => { setVal(mid); setDone(false); reset(); };
  return (
    <div className="dgb-ig">
      <div className="dgb-ig-head">
        <span className="dgb-ig-badge">🎚 滑块估值</span>
        <span className="dgb-ig-prompt">{spec.prompt}</span>
        <GameStat score={score} combo={combo} />
      </div>
      <div className="dgb-ig-slider">
        <label><span>调到目标值</span><span className="dgb-ig-val">{val}{spec.unit ?? ''}</span></label>
        <input type="range" min={spec.min} max={spec.max} step={spec.step ?? 1} value={val}
          disabled={done} onChange={(e) => setVal(Number(e.target.value))} />
        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, color: '#94a3b8' }}>
          <span>{spec.min}{spec.unit ?? ''}</span><span>{spec.max}{spec.unit ?? ''}</span>
        </div>
      </div>
      <div className="dgb-ig-actions">
        <button type="button" className="dgb-ig-btn" disabled={done} onClick={submit}>提交</button>
        {done && !correct ? <button type="button" className="dgb-ig-btn ghost" onClick={replay}>重试</button> : null}
        {done ? <span className={`dgb-ig-res ${correct ? 'ok' : 'ng'}`}>{correct ? `命中（目标 ${spec.target}${spec.unit ?? ''}）` : `偏差过大（目标 ${spec.target}${spec.unit ?? ''}）`}</span> : null}
      </div>
      {done && spec.explanation ? <div className="dgb-ig-expl">{spec.explanation}</div> : null}
      <GameWinBanner show={correct} text={`🎉 估值命中！得分 ${score}`} onReplay={replay} stars={stars} onShow={playWin} />
    </div>
  );
}
