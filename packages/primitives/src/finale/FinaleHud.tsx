/**
 * FinaleHud · 顶部 HUD（HP / Score / Combo / Timer / Stage 进度 + Mute）
 *
 * 数据来自 useFinaleEngine 的 state；纯展示，不修改 state（除 mute toggle 由父级 dispatch）。
 * 性能：所有动画走 transform/opacity；HP / combo 抖动通过 key 切换 + CSS animation 触发。
 */
import { memo, useEffect, useRef, useState } from 'react';
import type { FinaleEngineState, FinaleStage } from './types';

export interface FinaleHudProps {
  state: FinaleEngineState;
  totalStages: number;
  bossStageIndex: number;
  currentStage: FinaleStage | null;
  onToggleMute: () => void;
}

const HEART_PATH =
  'M12 21s-7.5-4.7-9.5-10C1 7.5 3.5 4 7 4c2 0 3.5 1 5 3 1.5-2 3-3 5-3 3.5 0 6 3.5 4.5 7C19.5 16.3 12 21 12 21z';

function HeartIcon({ filled, pulse }: { filled: boolean; pulse: boolean }) {
  return (
    <svg
      className={[
        'dgb-finale-hp__heart',
        filled ? '' : 'is-empty',
        pulse ? 'is-pulse' : '',
      ]
        .filter(Boolean)
        .join(' ')}
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden
    >
      <path d={HEART_PATH} />
    </svg>
  );
}

function TimerRing({
  remainingMs,
  totalMs,
  warn,
}: {
  remainingMs: number;
  totalMs: number;
  warn: boolean;
}) {
  const radius = 28;
  const circumference = 2 * Math.PI * radius;
  const ratio = Math.max(0, Math.min(1, remainingMs / Math.max(1, totalMs)));
  const dashOffset = circumference * (1 - ratio);
  const seconds = Math.ceil(remainingMs / 1000);
  return (
    <div className={`dgb-finale-timer${warn ? ' is-warn' : ''}`}>
      <svg className="dgb-finale-timer__ring" viewBox="0 0 66 66" aria-hidden>
        <circle
          cx="33"
          cy="33"
          r={radius}
          fill="none"
          stroke="rgba(244,246,251,0.14)"
          strokeWidth="4"
        />
        <circle
          cx="33"
          cy="33"
          r={radius}
          fill="none"
          stroke={warn ? '#ef4444' : '#38d9a9'}
          strokeWidth="4"
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={dashOffset}
          style={{ transition: 'stroke-dashoffset 200ms linear' }}
        />
      </svg>
      <span aria-live="polite">{seconds}</span>
    </div>
  );
}

function FinaleHudInner({
  state,
  totalStages,
  bossStageIndex,
  currentStage,
  onToggleMute,
}: FinaleHudProps) {
  // HP 抖动：HP 减少时触发一次心形 pulse（只对刚减少那颗）
  const [hpPulseKey, setHpPulseKey] = useState(0);
  const prevHpRef = useRef(state.hp);
  useEffect(() => {
    if (state.hp < prevHpRef.current) setHpPulseKey((k) => k + 1);
    prevHpRef.current = state.hp;
  }, [state.hp]);

  // combo 弹跳：combo 自增时触发一次
  const [comboBumpKey, setComboBumpKey] = useState(0);
  const prevComboRef = useRef(state.combo);
  useEffect(() => {
    if (state.combo > prevComboRef.current) setComboBumpKey((k) => k + 1);
    prevComboRef.current = state.combo;
  }, [state.combo]);

  const totalMs = (currentStage?.timeLimitSec ?? 60) * 1000;
  const warn = state.timeRemainingMs <= 5000 && state.phase === 'playing';

  const lostHpIndex = state.hpMax - state.hp - 1; // 最近丢的那颗

  return (
    <div className="dgb-finale-hud" role="region" aria-label="挑战 HUD">
      {/* 左：HP + score */}
      <div className="dgb-finale-hud__slot is-left">
        <div className="dgb-finale-hp" aria-label={`HP ${state.hp}/${state.hpMax}`}>
          {Array.from({ length: state.hpMax }).map((_, i) => {
            const filled = i < state.hp;
            const isPulseTarget = !filled && i === lostHpIndex;
            return (
              <HeartIcon
                key={`hp-${i}-${isPulseTarget ? hpPulseKey : 0}`}
                filled={filled}
                pulse={isPulseTarget}
              />
            );
          })}
        </div>
        <div className="dgb-finale-score" aria-live="polite">
          <span className="dgb-finale-score__label">SCORE</span>
          {state.score}
        </div>
      </div>

      {/* 中：timer */}
      <div className="dgb-finale-hud__slot is-mid">
        <TimerRing
          remainingMs={state.timeRemainingMs}
          totalMs={totalMs}
          warn={warn}
        />
      </div>

      {/* 右：combo + stage 进度 + mute */}
      <div className="dgb-finale-hud__slot is-right">
        {state.combo >= 2 ? (
          <span
            key={`combo-${comboBumpKey}`}
            className="dgb-finale-combo is-bump"
            aria-label={`连击 ${state.combo}`}
          >
            ×{state.combo}
            <span className="dgb-finale-combo__suffix">COMBO</span>
          </span>
        ) : null}
        <div
          className="dgb-finale-progress"
          aria-label={`关卡 ${state.stageIndex + 1}/${totalStages}`}
        >
          {Array.from({ length: totalStages }).map((_, i) => {
            const isCurrent = i === state.stageIndex;
            const isDone = i < state.stageIndex;
            const isBoss = i === bossStageIndex;
            const cls = ['dgb-finale-progress__dot'];
            if (isCurrent) cls.push('is-current');
            else if (isDone) cls.push('is-done');
            if (isBoss && !isDone) cls.push('is-boss');
            return <span key={i} className={cls.join(' ')} />;
          })}
        </div>
        <button
          type="button"
          className="dgb-finale-mute"
          onClick={onToggleMute}
          aria-label={state.muted ? '取消静音' : '静音'}
          title={state.muted ? '取消静音' : '静音'}
        >
          {state.muted ? '🔇' : '🔊'}
        </button>
      </div>
    </div>
  );
}

export const FinaleHud = memo(FinaleHudInner);
