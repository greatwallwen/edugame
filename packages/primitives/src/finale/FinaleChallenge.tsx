/**
 * FinaleChallenge · 全屏游戏化挑战外壳
 *
 * 整合：
 *   - useFinaleEngine（状态机）
 *   - FinaleHud / FinaleStage / FinaleResult（UI）
 *   - finaleAudio（BGM + 音效）
 *   - Fullscreen API + iframe / iOS 伪全屏 fallback
 *   - 三路退出：ESC / 右上 ✕ / 移动端按钮
 *   - 视觉反馈：飞字、屏震、烟花（Boss 击破 / 通关）
 *   - 键盘热键：1/2/3/4 选项、Enter 提交、Esc 退出
 *
 * 与项目集成：
 *   - 入口卡（点击展开全屏挑战）
 *   - 全屏期间通过 onEnter / onExit 通知父级（Player 暂停 AudioBar / TTS）
 */
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { triggerConfetti } from '../utils/confetti';
import { FinaleHud } from './FinaleHud';
import { FinaleStage } from './FinaleStage';
import { FinaleResult } from './FinaleResult';
import { useFinaleEngine } from './finaleEngine';
import { getFinaleAudio } from './finaleAudio';
import type { FinaleChallengeBlock, FinaleVerdict } from './types';
import './FinaleChallenge.css';

export interface FinaleChallengeProps {
  block: FinaleChallengeBlock;
  /** 进入全屏挑战时通知父级（Player 可暂停 AudioBar / TTS） */
  onEnter?: () => void;
  /** 退出挑战时通知父级（恢复 AudioBar / TTS） */
  onExit?: () => void;
  /** 跳回知识点（结算页错题列表点击） */
  onJumpToAnchor?: (anchor: string) => void;
}

export function FinaleChallenge({
  block,
  onEnter,
  onExit,
  onJumpToAnchor,
}: FinaleChallengeProps) {
  const [open, setOpen] = useState(false);
  return open ? (
    <FinaleChallengeRunner
      block={block}
      onClose={() => {
        setOpen(false);
        onExit?.();
      }}
      onJumpToAnchor={onJumpToAnchor}
    />
  ) : (
    <FinaleTrigger
      block={block}
      onStart={() => {
        setOpen(true);
        onEnter?.();
      }}
    />
  );
}

/* ─────────────────────── 入口卡 ─────────────────────── */

function FinaleTrigger({
  block,
  onStart,
}: {
  block: FinaleChallengeBlock;
  onStart: () => void;
}) {
  const icon = block.triggerIcon ?? '🏆';
  const label = block.triggerLabel ?? '挑战测验';
  return (
    <div className="dgb-finale">
      <button
        type="button"
        className="dgb-finale-trigger"
        onClick={onStart}
        aria-label={`${label} · ${block.title}`}
      >
        <span className="dgb-finale-trigger__icon" aria-hidden>
          {icon}
        </span>
        <span className="dgb-finale-trigger__body">
          <span className="dgb-finale-trigger__title">{block.title}</span>
          {block.intro ? (
            <span className="dgb-finale-trigger__subtitle">{block.intro}</span>
          ) : (
            <span className="dgb-finale-trigger__subtitle">
              {block.stages.length} 关挑战 · {label}
            </span>
          )}
        </span>
        <span className="dgb-finale-trigger__chev" aria-hidden>
          ›
        </span>
      </button>
    </div>
  );
}


/* ─────────────────── 全屏检测 / 切换 ─────────────────── */

interface FullscreenAPI {
  request: (el: HTMLElement) => Promise<void>;
  exit: () => Promise<void>;
  element: () => Element | null;
  changeEvent: string;
  supported: boolean;
}

function getFullscreenApi(): FullscreenAPI {
  type DocAny = Document & {
    webkitFullscreenElement?: Element;
    msFullscreenElement?: Element;
    mozFullScreenElement?: Element;
    webkitExitFullscreen?: () => Promise<void>;
    msExitFullscreen?: () => Promise<void>;
    mozCancelFullScreen?: () => Promise<void>;
  };
  type ElAny = HTMLElement & {
    webkitRequestFullscreen?: () => Promise<void>;
    msRequestFullscreen?: () => Promise<void>;
    mozRequestFullScreen?: () => Promise<void>;
  };
  const doc = document as DocAny;
  const supported =
    !!document.fullscreenEnabled ||
    !!(doc as { webkitFullscreenEnabled?: boolean }).webkitFullscreenEnabled ||
    !!(doc as { msFullscreenEnabled?: boolean }).msFullscreenEnabled;
  const changeEvent =
    'onfullscreenchange' in document
      ? 'fullscreenchange'
      : 'onwebkitfullscreenchange' in document
      ? 'webkitfullscreenchange'
      : 'msfullscreenchange';
  return {
    supported,
    changeEvent,
    request: (el) => {
      const e = el as ElAny;
      if (e.requestFullscreen) return e.requestFullscreen();
      if (e.webkitRequestFullscreen) return e.webkitRequestFullscreen();
      if (e.msRequestFullscreen) return e.msRequestFullscreen();
      if (e.mozRequestFullScreen) return e.mozRequestFullScreen();
      return Promise.reject(new Error('fullscreen-unsupported'));
    },
    exit: () => {
      if (document.exitFullscreen) return document.exitFullscreen();
      if (doc.webkitExitFullscreen) return doc.webkitExitFullscreen();
      if (doc.msExitFullscreen) return doc.msExitFullscreen();
      if (doc.mozCancelFullScreen) return doc.mozCancelFullScreen();
      return Promise.reject(new Error('fullscreen-unsupported'));
    },
    element: () =>
      document.fullscreenElement ??
      doc.webkitFullscreenElement ??
      doc.msFullscreenElement ??
      doc.mozFullScreenElement ??
      null,
  };
}

/** 检测是否在 iframe 中（很多 LMS 嵌入场景）；iframe 内通常无法触发原生全屏 */
function isInIframe(): boolean {
  try {
    return window.self !== window.top;
  } catch {
    return true;
  }
}

/**
 * 进入 Finale 时暂停页面已有的音视频与 TTS，避免与 BGM 重叠。
 * - <audio> / <video>：调用 .pause()
 * - speechSynthesis：cancel 当前队列
 * - dispatch 自定义事件 'dgb:finale:enter'：让 Shell / AudioBar 自行响应
 */
function pauseExternalMedia() {
  try {
    document.querySelectorAll('audio, video').forEach((el) => {
      const m = el as HTMLMediaElement;
      if (!m.paused) m.pause();
    });
  } catch {
    /* noop */
  }
  try {
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel();
    }
  } catch {
    /* noop */
  }
  try {
    document.dispatchEvent(new CustomEvent('dgb:finale:enter'));
  } catch {
    /* noop */
  }
}

function notifyFinaleExit() {
  try {
    document.dispatchEvent(new CustomEvent('dgb:finale:exit'));
  } catch {
    /* noop */
  }
}


/* ─────────────────── 主 Runner（全屏挑战体验） ─────────────────── */

interface RunnerProps {
  block: FinaleChallengeBlock;
  onClose: () => void;
  onJumpToAnchor?: (anchor: string) => void;
}

interface VerdictFx {
  key: number;
  verdict: FinaleVerdict;
}

function FinaleChallengeRunner({ block, onClose, onJumpToAnchor }: RunnerProps) {
  const rootRef = useRef<HTMLDivElement>(null);
  const fsApi = useMemo(() => getFullscreenApi(), []);
  // pseudo: 进入失败 / iframe / 不支持 时使用 position:fixed 伪全屏
  const [isPseudo, setIsPseudo] = useState(true);
  const [shake, setShake] = useState(0);
  const [verdictFx, setVerdictFx] = useState<VerdictFx | null>(null);
  const audio = useMemo(() => getFinaleAudio(), []);

  // ── 引擎 + 回调 ──
  const engine = useFinaleEngine(block, {
    onAnswerCorrect: (entry) => {
      audio.playCorrect(
        entry.verdict === 'miss' ? 'good' : (entry.verdict as 'perfect' | 'great' | 'good'),
      );
      if (entry.verdict === 'perfect' || entry.verdict === 'great') {
        audio.playCombo(Math.max(1, engine.state.combo + 1));
      }
      setVerdictFx({ key: Date.now(), verdict: entry.verdict });
    },
    onAnswerWrong: () => {
      audio.playWrong();
      setShake((n) => n + 1);
      setVerdictFx({ key: Date.now(), verdict: 'miss' });
      // 移动端轻震动（feature detect）
      if (typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function') {
        try {
          navigator.vibrate(40);
        } catch {
          /* noop */
        }
      }
    },
    onStageClear: () => {
      audio.playStageClear();
    },
    onBossDefeat: () => {
      audio.playBossDefeat();
      triggerConfetti({ particleCount: 220, spread: 100, origin: { y: 0.5 } });
    },
    onResult: (phase) => {
      if (phase === 'result-pass') {
        triggerConfetti({ particleCount: 160, spread: 80, origin: { y: 0.6 } });
      }
    },
  });

  const totalStages = block.stages.length;
  const bossIdx = block.bossStageIndex ?? totalStages - 1;

  // ── 全屏 ──
  useEffect(() => {
    const node = rootRef.current;
    if (!node) return;
    if (!fsApi.supported || isInIframe()) {
      setIsPseudo(true);
      return;
    }
    fsApi
      .request(node)
      .then(() => setIsPseudo(false))
      .catch(() => setIsPseudo(true));
    const sync = () => {
      const inFs = fsApi.element() === node;
      setIsPseudo(!inFs);
      // 用户按 ESC 触发 fullscreenchange 离开全屏 → 顺势关闭挑战
      if (!inFs && document.body.contains(node)) {
        // 走 handleCloseRef 保证停 BGM；初次 effect 时 ref 还未 set，需 setTimeout 兜底
        if (handleCloseRef.current) handleCloseRef.current();
        else onClose();
      }
    };
    document.addEventListener(fsApi.changeEvent, sync);
    return () => {
      document.removeEventListener(fsApi.changeEvent, sync);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ── 启动：用户首次手势已发生（点击 trigger 进入），可安全 init audio + START ──
  useEffect(() => {
    audio.init();
    audio.setMuted(false);
    audio.playBgm(block.bgmTrack);
    engine.dispatch({ type: 'START', challenge: block });
    // 暂停页面内已有 TTS / 音视频，避免与 Finale BGM 冲突
    pauseExternalMedia();
    return () => {
      audio.stopBgm();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ── BGM 主题随 Boss 切换 ──
  useEffect(() => {
    if (engine.isBoss && engine.state.phase !== 'idle') {
      audio.playBgm('epic');
    } else if (
      engine.state.phase !== 'idle' &&
      engine.state.phase !== 'result-pass' &&
      engine.state.phase !== 'result-fail'
    ) {
      audio.playBgm(block.bgmTrack);
    }
  }, [engine.isBoss, engine.state.phase, block.bgmTrack, audio]);

  // ── 静音同步 audio ──
  useEffect(() => {
    audio.setMuted(engine.state.muted);
  }, [engine.state.muted, audio]);

  // ── 时间警告音（≤5s 时每秒响一次） ──
  const lastWarnSecRef = useRef(0);
  useEffect(() => {
    if (engine.state.phase !== 'playing') {
      lastWarnSecRef.current = 0;
      return;
    }
    if (engine.state.timeRemainingMs > 5000) {
      lastWarnSecRef.current = 0;
      return;
    }
    const sec = Math.ceil(engine.state.timeRemainingMs / 1000);
    if (sec !== lastWarnSecRef.current && sec > 0) {
      audio.playTimeWarning();
      lastWarnSecRef.current = sec;
    }
  }, [engine.state.timeRemainingMs, engine.state.phase, audio]);

  // ── 关闭逻辑（先定义，供 keydown 监听用） ──
  const handleClose = useCallback(() => {
    audio.stopBgm();
    if (!isPseudo && fsApi.element() === rootRef.current) {
      fsApi.exit().catch(() => {
        /* noop */
      });
    }
    notifyFinaleExit();
    onClose();
  }, [isPseudo, fsApi, audio, onClose]);

  // 用 ref 让长生命周期 effect 能拿到最新 handleClose
  const handleCloseRef = useRef(handleClose);
  handleCloseRef.current = handleClose;

  // ── 键盘热键 ──
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        handleClose();
      }
      // 题型组件内部已自带键盘可达（button focus + Enter 默认提交）；这里不再拦截 1-4 等
    };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [handleClose]);


  // ── auto-advance：intro / stage-card / boss-intro 显示一段时间后用户按 CTA 才前进 ──
  // 这里把 CTA 行为交给 stage-card 的按钮；intro 自动 1.5s 进 stage-card
  useEffect(() => {
    if (engine.state.phase !== 'intro') return;
    const t = window.setTimeout(
      () => engine.dispatch({ type: 'ADVANCE_PHASE' }),
      1500,
    );
    return () => window.clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [engine.state.phase]);

  // ── 派生：当前阶段 / 题目 / 屏震 class ──
  const cs = engine.currentStage;
  const cq = engine.currentQuestion;
  const phase = engine.state.phase;
  const showResult = phase === 'result-pass' || phase === 'result-fail';
  const locked = phase === 'feedback';

  const rootCls = [
    'dgb-finale',
    'dgb-finale-stage-root',
    isPseudo ? 'is-pseudo' : '',
    engine.isBoss && phase !== 'result-pass' && phase !== 'result-fail'
      ? 'is-boss'
      : '',
    shake > 0 ? 'is-shake' : '',
  ]
    .filter(Boolean)
    .join(' ');

  // 屏震每次 +1 后 320ms 自动复位（key 切换法）
  useEffect(() => {
    if (shake === 0) return;
    const t = window.setTimeout(() => setShake(0), 320);
    return () => window.clearTimeout(t);
  }, [shake]);

  return (
    <div ref={rootRef} className={rootCls} data-finale-id={block.id}>
      <div className="dgb-finale-bosspulse" aria-hidden />
      <button
        type="button"
        className="dgb-finale-close"
        onClick={handleClose}
        aria-label="退出挑战"
        title="退出（ESC）"
      >
        ✕
      </button>

      <FinaleHud
        state={engine.state}
        totalStages={totalStages}
        bossStageIndex={bossIdx}
        currentStage={cs}
        onToggleMute={() => engine.dispatch({ type: 'TOGGLE_MUTE' })}
      />

      <div className="dgb-finale-stage-body">
        {showResult ? (
          <div className="dgb-finale-stage-card">
            <FinaleResult
              phase={phase}
              state={engine.state}
              rank={engine.rank}
              challengeTitle={block.title}
              summaryPoints={block.summaryPoints}
              onReplay={() => engine.dispatch({ type: 'START', challenge: block })}
              onContinue={handleClose}
              onJumpToAnchor={(anchor) => {
                handleClose();
                onJumpToAnchor?.(anchor);
              }}
            />
          </div>
        ) : phase === 'intro' ? (
          <div className="dgb-finale-stage-card is-overlay dgb-finale-enter" key="intro">
            <div className="dgb-finale-stage-card__big">{block.title}</div>
            {block.intro ? (
              <p className="dgb-finale-stage-card__subtitle">{block.intro}</p>
            ) : null}
          </div>
        ) : phase === 'stage-card' && cs ? (
          <div
            className="dgb-finale-stage-card is-overlay dgb-finale-enter"
            key={`sc-${engine.state.stageIndex}`}
          >
            <div className="dgb-finale-stage-card__subtitle">
              第 {engine.state.stageIndex + 1} / {totalStages} 关
            </div>
            <h3 className="dgb-finale-stage-card__title">{cs.title}</h3>
            {cs.subtitle ? (
              <p className="dgb-finale-stage-card__subtitle">{cs.subtitle}</p>
            ) : null}
            <button
              type="button"
              className="dgb-finale-stage-card__cta"
              onClick={() => engine.dispatch({ type: 'ADVANCE_PHASE' })}
              autoFocus
            >
              开始 ▶
            </button>
          </div>
        ) : phase === 'boss-intro' ? (
          <div className="dgb-finale-stage-card is-overlay dgb-finale-enter" key="boss-intro">
            <div className="dgb-finale-stage-card__big">⚔ Boss 关</div>
            <p className="dgb-finale-stage-card__subtitle">最后挑战，全力以赴！</p>
          </div>
        ) : phase === 'stage-debrief' && cs ? (
          <div
            className="dgb-finale-stage-card is-overlay dgb-finale-enter dgb-finale-debrief"
            key={`debrief-${engine.state.stageIndex}`}
          >
            <div className="dgb-finale-stage-card__subtitle">
              第 {engine.state.stageIndex + 1} 关通关 ✓ · 知识点解锁
            </div>
            <h3 className="dgb-finale-stage-card__title">📌 课后总结要点</h3>
            <ul className="dgb-finale-debrief__list">
              {(block.summaryPoints ?? []).map((pt, i) => {
                const unlocked = engine.state.unlockedSummary.includes(i);
                const justNow =
                  unlocked &&
                  (block.summaryUnlockMap?.[cs.id] ?? []).includes(i);
                return (
                  <li
                    key={i}
                    className={[
                      'dgb-finale-debrief__item',
                      unlocked ? 'is-unlocked' : 'is-locked',
                      justNow ? 'is-just-now' : '',
                    ]
                      .filter(Boolean)
                      .join(' ')}
                  >
                    <span className="dgb-finale-debrief__num">
                      {String(i + 1).padStart(2, '0')}
                    </span>
                    <span className="dgb-finale-debrief__text">
                      {unlocked ? pt : '????（继续闯关解锁）'}
                    </span>
                    {justNow ? (
                      <span className="dgb-finale-debrief__badge">NEW</span>
                    ) : null}
                  </li>
                );
              })}
            </ul>
            <button
              type="button"
              className="dgb-finale-stage-card__cta"
              onClick={() => engine.dispatch({ type: 'CONTINUE_DEBRIEF' })}
              autoFocus
            >
              {engine.state.stageIndex + 1 === bossIdx
                ? '迎战 Boss ⚔'
                : '继续下一关 ▶'}
            </button>
          </div>
        ) : phase === 'stage-clear' ? (
          <div
            className="dgb-finale-stage-card is-overlay dgb-finale-enter"
            key={`clear-${engine.state.stageIndex}`}
          >
            <div className="dgb-finale-stage-card__big">关卡通过 ✓</div>
            <p className="dgb-finale-stage-card__subtitle">下一关...</p>
          </div>
        ) : (phase === 'playing' || phase === 'feedback') && cs && cq ? (
          <div
            className="dgb-finale-stage-card dgb-finale-enter"
            key={`q-${engine.state.stageIndex}-${engine.state.questionIndex}`}
          >
            <FinaleStage
              question={cq}
              questionStartedAt={engine.state.questionStartedAt}
              index={engine.state.questionIndex + 1}
              total={cs.questions.length}
              locked={locked}
              onAnswer={(correct, timeUsedMs) =>
                engine.dispatch({
                  type: 'ANSWER',
                  correct,
                  timeUsedMs,
                  questionId: cq.id,
                })
              }
            />
          </div>
        ) : null}
      </div>

      {/* 飞字反馈层 */}
      {verdictFx ? (
        <div className="dgb-finale-fx" aria-hidden>
          <div
            key={verdictFx.key}
            className={`dgb-finale-fx__verdict is-${verdictFx.verdict}`}
            onAnimationEnd={() => setVerdictFx(null)}
          >
            {verdictFx.verdict === 'perfect'
              ? 'PERFECT!'
              : verdictFx.verdict === 'great'
              ? 'GREAT!'
              : verdictFx.verdict === 'good'
              ? 'GOOD'
              : 'MISS'}
          </div>
        </div>
      ) : null}
    </div>
  );
}


