import { useEffect, useRef, useState, useCallback } from 'react';
import './DigitalHumanBlock.css';
import { TeacherAvatar } from './TeacherAvatar';

export interface DigitalHumanBlockProps {
  script: string;
  avatarState?: 'idle' | 'explaining' | 'encouraging' | 'questioning' | 'correcting';
  faq?: { q: string; a: string }[];
  ttsEnabled?: boolean;
  welcomeMessage?: string;
  audioSrc?: string;
  autoPlay?: boolean;
  /** 紧凑模式（默认）— 所有嵌入式使用都走这个。 */
  compact?: boolean;
  /** 场景模式（动画右栏/下方）— 开启上部讲师头像区。 */
  sceneMode?: boolean;
  onSpeechEnd?: () => void;
  stepScripts?: string[];
  currentStep?: number;
  autoPlayOnStepChange?: boolean;
  /** 上一步 / 下一步 控制（由 AnimationHtmlBlock 注入，整合到讲师栏）。 */
  onPrevStep?: () => void;
  onNextStep?: () => void;
  /** 总步数（用于 1/N 指示器）。 */
  totalSteps?: number;
}

/** AI 讲师原语：OpenMAIC 风格紧凑讲师卡 —— 头像 + 状态 + TTS 控制 + 讲稿。
 *  不依赖 Live2D/Pixi，全 SVG 渲染，零运行时包。 */
export function DigitalHumanBlock({
  script,
  avatarState = 'idle',
  faq,
  ttsEnabled = false,
  welcomeMessage,
  audioSrc,
  autoPlay = false,
  compact = false,
  sceneMode = false,
  onSpeechEnd,
  stepScripts,
  currentStep,
  autoPlayOnStepChange = false,
  onPrevStep,
  onNextStep,
  totalSteps,
}: DigitalHumanBlockProps) {
  const [expandedFaq, setExpandedFaq] = useState<number | null>(null);
  const [speaking, setSpeaking] = useState(false);
  const [ttsError, setTtsError] = useState<string | null>(null);
  const audioRef = useRef<HTMLAudioElement | null>(null);

  const activeScript =
    stepScripts && typeof currentStep === 'number' && stepScripts[currentStep]
      ? stepScripts[currentStep]!
      : script;

  // 播放令牌 + 中止控制
  const playTokenRef = useRef(0);
  const abortRef = useRef<AbortController | null>(null);

  const stopPlayback = useCallback(() => {
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

  const handleTts = useCallback(async (override?: string) => {
    setTtsError(null);
    const text = (override ?? activeScript ?? '').trim();
    if (!text) return;
    if (!override && speaking) { stopPlayback(); return; }
    stopPlayback();
    const token = ++playTokenRef.current;
    const controller = new AbortController();
    abortRef.current = controller;

    const playAudio = (url: string) =>
      new Promise<void>((resolve, reject) => {
        const audio = new Audio(url);
        audioRef.current = audio;
        const cancel = () => { try { audio.pause(); audio.src = ''; } catch {} };
        controller.signal.addEventListener('abort', () => { cancel(); reject(new Error('aborted')); });
        audio.onplay = () => { if (playTokenRef.current !== token) { cancel(); return; } setSpeaking(true); };
        audio.onended = () => { if (playTokenRef.current !== token) return; setSpeaking(false); onSpeechEnd?.(); resolve(); };
        audio.onerror = () => { setSpeaking(false); reject(new Error('audio-error')); };
        audio.play().catch(reject);
      });

    try {
      if (audioSrc && !override) { await playAudio(audioSrc); return; }
      const resp = await fetch('/api/tts/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text, voice: 'Cherry', model: 'qwen3-tts-flash' }),
        signal: controller.signal,
      });
      if (playTokenRef.current !== token) return;
      if (resp.ok) {
        const data = await resp.json();
        if (playTokenRef.current !== token) return;
        if (data?.audioUrl) { await playAudio(data.audioUrl); return; }
      }
    } catch (err: unknown) {
      if ((err as Error)?.message === 'aborted') return;
    }

    if (playTokenRef.current !== token) return;
    if (typeof window === 'undefined' || !('speechSynthesis' in window)) {
      setTtsError('浏览器不支持语音播放');
      return;
    }
    const utter = new SpeechSynthesisUtterance(text);
    utter.lang = 'zh-CN';
    utter.rate = 1.0;
    utter.onstart = () => { if (playTokenRef.current !== token) return; setSpeaking(true); };
    utter.onend = () => { if (playTokenRef.current !== token) return; setSpeaking(false); onSpeechEnd?.(); };
    utter.onerror = () => { setSpeaking(false); setTtsError('浏览器朗读失败'); };
    window.speechSynthesis.speak(utter);
  }, [audioSrc, activeScript, speaking, onSpeechEnd, stopPlayback]);

  useEffect(() => () => { stopPlayback(); }, [stopPlayback]);

  useEffect(() => {
    if (!autoPlay || !ttsEnabled) return;
    const t = window.setTimeout(() => { void handleTts(); }, 500);
    return () => window.clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [autoPlay, ttsEnabled]);

  const lastStepRef = useRef<number | null>(null);
  const stepTimerRef = useRef<number | null>(null);
  useEffect(() => {
    if (!ttsEnabled || !autoPlayOnStepChange) return;
    if (typeof currentStep !== 'number') return;
    if (!stepScripts || !stepScripts[currentStep]) return;
    if (lastStepRef.current === currentStep) return;
    lastStepRef.current = currentStep;
    if (stepTimerRef.current) window.clearTimeout(stepTimerRef.current);
    const line = stepScripts[currentStep]!;
    stepTimerRef.current = window.setTimeout(() => { void handleTts(line); }, 350);
    return () => {
      if (stepTimerRef.current) { window.clearTimeout(stepTimerRef.current); stepTimerRef.current = null; }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentStep, autoPlayOnStepChange, ttsEnabled, stepScripts]);

  const stateLabel: Record<string, string> = {
    idle: '待命中', explaining: '讲解中', encouraging: '鼓励',
    questioning: '提问', correcting: '纠错',
  };
  const total = totalSteps ?? stepScripts?.length ?? 0;
  const hasStepper = total > 1 && (onPrevStep || onNextStep);
  const stepLabel = stepScripts && typeof currentStep === 'number'
    ? `第 ${currentStep + 1} / ${total || stepScripts.length} 步 · ${stateLabel[avatarState] ?? '讲解中'}`
    : (stateLabel[avatarState] ?? '讲解中');

  const renderScriptBody = () => {
    // 多段模式：有 stepScripts 且外部驱动 currentStep，则分段展示 + 当前段高亮
    if (stepScripts && stepScripts.length > 1) {
      return (
        <ol className="dgb-dh-script-list">
          {stepScripts.map((line, i) => (
            <li
              key={i}
              className={
                'dgb-dh-script-item' +
                (i === currentStep ? ' is-current' : '') +
                (i === currentStep && speaking ? ' is-speaking' : '')
              }
              data-step={i + 1}
            >
              <span className="dgb-dh-script-bullet" aria-hidden>{i + 1}</span>
              <span className="dgb-dh-script-line">{line}</span>
            </li>
          ))}
        </ol>
      );
    }
    return <p className="dgb-dh-script-text">{welcomeMessage ?? activeScript}</p>;
  };

  return (
    <div
      className={`dgb-dh${compact ? ' dgb-dh-compact' : ''}${sceneMode ? ' dgb-dh-scene' : ''}`}
      data-state={avatarState}
    >
      {/* 头部工具栏：头像 + 名称/状态 + [◀ 步进 ▶] + 播放/停止 */}
      <header className="dgb-dh-bar">
        <TeacherAvatar speaking={speaking} size={sceneMode ? 40 : 36} />
        <div className="dgb-dh-bar-meta">
          <div className="dgb-dh-bar-name">AI 讲师</div>
          <div className="dgb-dh-bar-status">
            <span className={`dgb-dh-pulse${speaking ? ' on' : ''}`} aria-hidden />
            {stepLabel}
          </div>
        </div>
        <div className="dgb-dh-bar-actions">
          {hasStepper && (
            <>
              <button
                type="button"
                className="dgb-dh-icon-btn dgb-dh-icon-btn--ghost"
                onClick={() => onPrevStep?.()}
                disabled={typeof currentStep === 'number' && currentStep <= 0}
                aria-label="上一步"
                title="上一步"
              >
                <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor" aria-hidden>
                  <path d="M15 5 7 12l8 7V5Z" />
                </svg>
              </button>
              <button
                type="button"
                className="dgb-dh-icon-btn dgb-dh-icon-btn--ghost"
                onClick={() => onNextStep?.()}
                disabled={
                  typeof currentStep === 'number' && total > 0 && currentStep >= total - 1
                }
                aria-label="下一步"
                title="下一步"
              >
                <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor" aria-hidden>
                  <path d="M9 5v14l8-7-8-7Z" />
                </svg>
              </button>
            </>
          )}
          {ttsEnabled && (
            <button
              type="button"
              className={`dgb-dh-icon-btn${speaking ? ' is-on' : ''}`}
              onClick={() => handleTts()}
              aria-label={speaking ? '停止朗读' : '朗读讲稿'}
              title={speaking ? '停止朗读' : '朗读讲稿'}
            >
              {speaking ? (
                <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor" aria-hidden>
                  <rect x="6" y="5" width="4" height="14" rx="1" />
                  <rect x="14" y="5" width="4" height="14" rx="1" />
                </svg>
              ) : (
                <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor" aria-hidden>
                  <path d="M7 5.5v13l11-6.5Z" />
                </svg>
              )}
            </button>
          )}
        </div>
      </header>

      {/* 讲稿区 */}
      <section className="dgb-dh-script">
        {renderScriptBody()}
        {ttsError && <div className="dgb-dh-tts-error">{ttsError}</div>}
      </section>

      {/* FAQ */}
      {faq && faq.length > 0 && (
        <section className="dgb-dh-faq">
          <div className="dgb-dh-faq-title">常见问题</div>
          {faq.map((item, i) => (
            <div key={i} className="dgb-dh-faq-item">
              <button
                className="dgb-dh-faq-q"
                type="button"
                onClick={() => setExpandedFaq(expandedFaq === i ? null : i)}
              >
                <span className={`dgb-dh-faq-chevron${expandedFaq === i ? ' open' : ''}`}>▸</span>
                {item.q}
              </button>
              {expandedFaq === i && <div className="dgb-dh-faq-a">{item.a}</div>}
            </div>
          ))}
        </section>
      )}
    </div>
  );
}
