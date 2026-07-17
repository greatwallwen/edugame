import { useCallback, useEffect, useRef, useState } from 'react';
import './CommentaryBar.css';

/**
 * CommentaryBar · 统一"讲解字幕条"原语
 *
 * 设计原则（参考 OpenMAIC presentation-speech-overlay）：
 *  - 轻量、sticky、不喧宾夺主：永远贴在宿主 block 下方，最多占 1/3 视野
 *  - 区分 source：动画讲解 / 代码讲解 / 文字讲解（不同 badge + 语义色）
 *  - 当前段高亮 + 光标动画（继承之前 DigitalHuman 的阅读体验）
 *  - 可外部驱动 currentStep（联动动画步进），也可自主 0→N
 *  - TTS 逻辑复用后端 /api/tts/generate，失败回退 speechSynthesis
 */

export type CommentarySourceType = 'animation' | 'code' | 'text';

export interface CommentaryBarProps {
  /** 讲解来源 —— 决定 badge 文字与配色 */
  sourceType: CommentarySourceType;
  /** 单段讲稿（没有 stepScripts 时使用）*/
  script?: string;
  /** 多段讲稿（代码分行讲 / 动画分步讲）*/
  stepScripts?: string[];
  /** 外部驱动的当前步；未传时 bar 内部自管 */
  currentStep?: number;
  /** 外部步进回调；未传时 bar 提供内部步进按钮 */
  onStepChange?: (step: number) => void;
  /** 总步数（为 stepScripts 提供权威长度，常见于动画 iframe 上报）*/
  totalSteps?: number;
  /** 讲师显示名称 —— 默认"AI 讲师" */
  speaker?: string;
  /** Iter-40-E · 讲师角色副标题（如"5G 网优讲师" / "STM32 教学讲师"），
   *  对标 5G 教材播报截图右侧 commentary bar 双行版式。
   *  缺省时不渲染独立 role 行，与 v3-v6 行为完全兼容。 */
  role?: string;
  /** Iter-40-E · 讲师头像 URL（PNG/SVG）；缺省时不渲染头像，bar 退回旧"badge + speaker"无头像形态。*/
  avatarUrl?: string;
  /** 是否允许 TTS —— 默认 true */
  ttsEnabled?: boolean;
  /** step 变化时是否自动朗读 */
  autoPlayOnStepChange?: boolean;
  /** 指定 TTS 声音（后端 voice 参数），默认 Cherry */
  voice?: string;
}

const SOURCE_META: Record<CommentarySourceType, { label: string; tone: string }> = {
  animation: { label: '动画讲解', tone: 'anim' },
  code:      { label: '代码讲解', tone: 'code' },
  text:      { label: '文字讲解', tone: 'text' },
};

export function CommentaryBar({
  sourceType,
  script,
  stepScripts,
  currentStep,
  onStepChange,
  totalSteps,
  speaker = 'AI 讲师',
  role,
  avatarUrl,
  ttsEnabled = true,
  autoPlayOnStepChange = false,
  voice = 'Cherry',
}: CommentaryBarProps) {
  const [internalStep, setInternalStep] = useState(0);
  const step = typeof currentStep === 'number' ? currentStep : internalStep;
  const total = totalSteps ?? stepScripts?.length ?? 0;
  const hasSteps = !!stepScripts && stepScripts.length > 1;
  const activeLine =
    (hasSteps && stepScripts![step]) || stepScripts?.[0] || script || '';

  const setStep = (next: number) => {
    if (onStepChange) onStepChange(next);
    else setInternalStep(next);
  };

  const [speaking, setSpeaking] = useState(false);
  const [ttsError, setTtsError] = useState<string | null>(null);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const tokenRef = useRef(0);
  const abortRef = useRef<AbortController | null>(null);

  const stop = useCallback(() => {
    abortRef.current?.abort();
    abortRef.current = null;
    if (audioRef.current) {
      try { audioRef.current.pause(); audioRef.current.src = ''; } catch {}
      audioRef.current = null;
    }
    if (typeof window !== 'undefined' && 'speechSynthesis' in window) {
      try { window.speechSynthesis.cancel(); } catch {}
    }
    setSpeaking(false);
  }, []);

  const speak = useCallback(async (override?: string) => {
    setTtsError(null);
    const text = (override ?? activeLine ?? '').trim();
    if (!text) return;
    if (!override && speaking) { stop(); return; }
    stop();
    const token = ++tokenRef.current;
    const controller = new AbortController();
    abortRef.current = controller;

    const playAudio = (url: string) => new Promise<void>((resolve, reject) => {
      const audio = new Audio(url);
      audioRef.current = audio;
      controller.signal.addEventListener('abort', () => {
        try { audio.pause(); audio.src = ''; } catch {}
        reject(new Error('aborted'));
      });
      audio.onplay = () => { if (tokenRef.current === token) setSpeaking(true); };
      audio.onended = () => { if (tokenRef.current === token) { setSpeaking(false); resolve(); } };
      audio.onerror = () => { setSpeaking(false); reject(new Error('audio-error')); };
      audio.play().catch(reject);
    });

    try {
      const resp = await fetch('/api/tts/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text, voice, model: 'qwen3-tts-flash' }),
        signal: controller.signal,
      });
      if (tokenRef.current !== token) return;
      if (resp.ok) {
        const data = await resp.json();
        if (tokenRef.current === token && data?.audioUrl) {
          await playAudio(data.audioUrl);
          return;
        }
      }
    } catch (err: unknown) {
      if ((err as Error)?.message === 'aborted') return;
    }

    if (tokenRef.current !== token) return;
    if (typeof window === 'undefined' || !('speechSynthesis' in window)) {
      setTtsError('浏览器不支持语音播放');
      return;
    }
    const utter = new SpeechSynthesisUtterance(text);
    utter.lang = 'zh-CN';
    utter.onstart = () => { if (tokenRef.current === token) setSpeaking(true); };
    utter.onend   = () => { if (tokenRef.current === token) setSpeaking(false); };
    utter.onerror = () => { setSpeaking(false); setTtsError('浏览器朗读失败'); };
    window.speechSynthesis.speak(utter);
  }, [activeLine, speaking, stop, voice]);

  useEffect(() => () => stop(), [stop]);

  // step 切换时自动朗读（可选）
  const lastStepRef = useRef<number>(-1);
  useEffect(() => {
    if (!autoPlayOnStepChange || !ttsEnabled) return;
    if (!hasSteps) return;
    if (lastStepRef.current === step) return;
    lastStepRef.current = step;
    const line = stepScripts?.[step];
    if (!line) return;
    const t = window.setTimeout(() => { void speak(line); }, 320);
    return () => window.clearTimeout(t);
  }, [step, autoPlayOnStepChange, ttsEnabled, hasSteps, stepScripts, speak]);

  const meta = SOURCE_META[sourceType];
  return (
    <aside
      className={`dgb-cbar dgb-cbar--${meta.tone}${speaking ? ' is-speaking' : ''}`}
      aria-live="polite"
      role="complementary"
    >
      <header className="dgb-cbar-head">
        <span className={`dgb-cbar-badge dgb-cbar-badge--${meta.tone}`}>{meta.label}</span>
        {avatarUrl ? (
          <img
            className="dgb-cbar-avatar"
            src={avatarUrl}
            alt={`${speaker} 头像`}
          />
        ) : null}
        <span className="dgb-cbar-speaker-block">
          <span className="dgb-cbar-speaker">{speaker}</span>
          {role ? <span className="dgb-cbar-role">{role}</span> : null}
        </span>
        {hasSteps && total > 0 && (
          <span className="dgb-cbar-step">
            {step + 1} / {total}
          </span>
        )}
        <span className="dgb-cbar-grow" />
        {hasSteps && (
          <>
            <button
              type="button"
              className="dgb-cbar-btn dgb-cbar-btn--ghost"
              onClick={() => setStep(Math.max(0, step - 1))}
              disabled={step <= 0}
              aria-label="上一段"
              title="上一段"
            >‹</button>
            <button
              type="button"
              className="dgb-cbar-btn dgb-cbar-btn--ghost"
              onClick={() => setStep(total > 0 ? Math.min(total - 1, step + 1) : step + 1)}
              disabled={total > 0 && step >= total - 1}
              aria-label="下一段"
              title="下一段"
            >›</button>
          </>
        )}
        {ttsEnabled && (
          <button
            type="button"
            className={`dgb-cbar-btn dgb-cbar-btn--play${speaking ? ' is-on' : ''}`}
            onClick={() => speak()}
            aria-label={speaking ? '停止朗读' : '朗读讲解'}
            title={speaking ? '停止朗读' : '朗读讲解'}
          >
            {speaking ? '■' : '▶'}
          </button>
        )}
      </header>

      <div className="dgb-cbar-body">
        {hasSteps ? (
          <ol className="dgb-cbar-list">
            {stepScripts!.map((line, i) => (
              <li
                key={i}
                className={
                  'dgb-cbar-item' +
                  (i === step ? ' is-current' : '') +
                  (i === step && speaking ? ' is-reading' : '')
                }
                onClick={() => setStep(i)}
                data-idx={i + 1}
              >
                <span className="dgb-cbar-bullet" aria-hidden>{i + 1}</span>
                <span className="dgb-cbar-line">{line}</span>
              </li>
            ))}
          </ol>
        ) : (
          <p className={`dgb-cbar-single${speaking ? ' is-reading' : ''}`}>{activeLine}</p>
        )}
        {ttsError && <div className="dgb-cbar-error">{ttsError}</div>}
      </div>
    </aside>
  );
}
