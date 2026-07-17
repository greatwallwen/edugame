/**
 * AudioBar · Iter-53 块级导航收口
 *
 * 底部播放器浮岛。与 PageActionRunner 协作：
 *   - 播放 / 暂停按钮：runner.togglePause / start
 *   - 停止：runner.stop
 *   - 上一个 / 下一个：本页内容块前进/后退（gotoPrevBlock/gotoNextBlock，首末块溢出相邻页）
 */
import type { CSSProperties, MutableRefObject } from 'react';
import type { CourseManifest, Page } from '@dgbook/types';
import type { PageActionRunner } from '@dgbook/playback';
import { IconPlay, IconPause, IconSkipBack, IconSkipForward, IconVolume, IconStop } from './icons';
import s from './Shell.module.css';

type EngineState = 'idle' | 'playing' | 'paused';

export interface AudioBarProps {
  showActionsHint: boolean;
  engineState: EngineState;
  activePage: Page | undefined;
  activeIdx: number;
  pages: ReadonlyArray<{ id: string }>;
  aiTutor: CourseManifest['aiTutor'];
  aiName: string;
  ttsProgress: number;
  ttsRate: number;
  bubbleDisplayText: string;
  isFollowingSpeech: boolean;
  startPlay: () => void;
  setActive: (id: string) => void;
  actionsRunnerRef: MutableRefObject<PageActionRunner | null>;
  onSpeedClick: () => void;
  speedLabel: string;
  /** 块级导航（与键盘 ←/→ 共用） */
  gotoPrevBlock: () => void;
  gotoNextBlock: () => void;
}

const HINT_STYLE: CSSProperties = {
  position: 'absolute',
  bottom: 'calc(100% + 8px)',
  left: '50%',
  transform: 'translateX(-50%)',
  background: 'rgba(15, 23, 42, 0.92)',
  color: '#fef3c7',
  padding: '8px 14px',
  borderRadius: 10,
  fontSize: 13,
  fontWeight: 500,
  whiteSpace: 'nowrap',
  boxShadow: '0 4px 16px rgba(0, 0, 0, 0.35)',
  border: '1px solid rgba(252, 211, 77, 0.4)',
  pointerEvents: 'none',
  zIndex: 50,
};

export function AudioBar(props: AudioBarProps) {
  const {
    showActionsHint, engineState, activePage, activeIdx, pages, aiTutor, aiName,
    ttsProgress, bubbleDisplayText, isFollowingSpeech,
    startPlay, setActive,
    actionsRunnerRef, onSpeedClick, speedLabel,
    gotoPrevBlock, gotoNextBlock,
  } = props;

  const handlePlayPause = () => {
    if (!activePage) return;
    const runner = actionsRunnerRef.current;
    if (runner) {
      runner.togglePause();
      return;
    }
    // 无 runner（page 没有 actions）→ 启动入口（实际 startPlay 也 no-op，按钮保留交互一致性）
    startPlay();
  };

  const handleStop = () => {
    actionsRunnerRef.current?.stop();
  };

  const hasRunner = !!actionsRunnerRef.current;
  const playDisabled = !activePage || (!hasRunner && engineState === 'idle');

  return (
    <footer className={s.audio}>
      {showActionsHint && (
        <div role="status" aria-live="polite" style={HINT_STYLE}>
          空格 暂停/继续 · ← → 上一段/下一段 · Esc 停止
        </div>
      )}
      <div className={s.audioBar}>
        <AudioAvatar engineState={engineState} aiTutor={aiTutor} aiName={aiName} />
        <AudioBubble
          engineState={engineState}
          ttsProgress={ttsProgress}
          bubbleDisplayText={bubbleDisplayText}
          isFollowingSpeech={isFollowingSpeech}
        />
        <div className={s.audioControls}>
          <button
            className={s.audioBtn}
            aria-label="上一个内容块"
            type="button"
            disabled={!activePage}
            title="上一个内容块（首块溢出到上一页末块）"
            onClick={gotoPrevBlock}
          >
            <IconSkipBack />
          </button>
          <button
            className={`${s.audioBtn} ${s.audioPlay}`}
            aria-label={engineState === 'playing' ? '暂停' : '播放'}
            onClick={handlePlayPause}
            disabled={playDisabled}
            type="button"
          >
            {engineState === 'playing' ? <IconPause /> : <IconPlay />}
          </button>
          <button
            className={s.audioBtn}
            aria-label="下一个内容块"
            type="button"
            disabled={!activePage}
            title="下一个内容块（末块溢出到下一页首块）"
            onClick={gotoNextBlock}
          >
            <IconSkipForward />
          </button>
          <button
            className={`${s.audioBtn} ${s.audioStop}`}
            aria-label="停止"
            type="button"
            disabled={engineState === 'idle'}
            onClick={handleStop}
          >
            <IconStop />
          </button>
          <button
            className={s.audioSpeed}
            type="button"
            onClick={onSpeedClick}
            title="语速（点击循环：0.75× / 1× / 1.25× / 1.5× / 2×）"
          >
            {speedLabel}
          </button>
          <button className={s.audioBtn} aria-label="音量" type="button"><IconVolume /></button>
        </div>
      </div>
    </footer>
  );
}

function AudioAvatar({ engineState, aiTutor, aiName }: {
  engineState: EngineState;
  aiTutor: CourseManifest['aiTutor'];
  aiName: string;
}) {
  return (
    <div className={s.audioAvatar}>
      <div className={`${s.audioAvatarCircle} ${engineState === 'playing' ? s.audioAvatarSpeaking : ''}`}>
        <img
          src="/avatars/teacher.png"
          alt={aiName}
          onError={(e) => {
            const img = e.currentTarget;
            if (img.src.endsWith('.png')) img.src = '/avatars/teacher.svg';
          }}
        />
      </div>
      <div className={s.audioAvatarMeta}>
        <span className={s.audioAvatarRole}>{aiTutor?.subtitle ?? 'AI 讲师'}</span>
        <span className={s.audioAvatarName}>{aiName}</span>
      </div>
    </div>
  );
}

function AudioBubble({ engineState, ttsProgress, bubbleDisplayText, isFollowingSpeech }: {
  engineState: EngineState;
  ttsProgress: number;
  bubbleDisplayText: string;
  isFollowingSpeech: boolean;
}) {
  return (
    <div className={s.audioBubbleWrap}>
      <div className={`${s.audioBubble} ${engineState === 'playing' ? s.audioBubbleActive : ''}`}>
        <AudioWave playing={engineState === 'playing'} />
        <span
          className={`${s.audioBubbleText} ${isFollowingSpeech ? s.audioBubbleTextFollowing : ''}`}
          data-mode={isFollowingSpeech ? 'speech' : 'title'}
        >
          {bubbleDisplayText}
          {isFollowingSpeech && <span className={s.audioBubbleCursor} aria-hidden>▍</span>}
        </span>
      </div>
      {engineState === 'playing' && (
        <div className={s.audioTrack}>
          <div className={s.audioFill} style={{ width: `${Math.round(ttsProgress * 100)}%` }} />
        </div>
      )}
    </div>
  );
}

function AudioWave({ playing }: { playing: boolean }) {
  if (playing) {
    return (
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" className={s.audioBubbleWave}>
        <rect x="2" y="8" width="3" height="8" rx="1.5" fill="currentColor">
          <animate attributeName="height" values="8;14;8" dur="0.8s" repeatCount="indefinite" />
          <animate attributeName="y" values="8;5;8" dur="0.8s" repeatCount="indefinite" />
        </rect>
        <rect x="7" y="5" width="3" height="14" rx="1.5" fill="currentColor">
          <animate attributeName="height" values="14;8;14" dur="0.8s" repeatCount="indefinite" begin="0.1s" />
          <animate attributeName="y" values="5;8;5" dur="0.8s" repeatCount="indefinite" begin="0.1s" />
        </rect>
        <rect x="12" y="9" width="3" height="6" rx="1.5" fill="currentColor">
          <animate attributeName="height" values="6;12;6" dur="0.8s" repeatCount="indefinite" begin="0.2s" />
          <animate attributeName="y" values="9;6;9" dur="0.8s" repeatCount="indefinite" begin="0.2s" />
        </rect>
        <rect x="17" y="6" width="3" height="12" rx="1.5" fill="currentColor">
          <animate attributeName="height" values="12;6;12" dur="0.8s" repeatCount="indefinite" begin="0.15s" />
          <animate attributeName="y" values="6;9;6" dur="0.8s" repeatCount="indefinite" begin="0.15s" />
        </rect>
      </svg>
    );
  }
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" className={s.audioBubbleWave} style={{ opacity: 0.4 }}>
      <rect x="2" y="8" width="3" height="8" rx="1.5" fill="currentColor" />
      <rect x="7" y="5" width="3" height="14" rx="1.5" fill="currentColor" />
      <rect x="12" y="9" width="3" height="6" rx="1.5" fill="currentColor" />
      <rect x="17" y="6" width="3" height="12" rx="1.5" fill="currentColor" />
    </svg>
  );
}

