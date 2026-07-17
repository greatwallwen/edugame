/**
 * TTSAdapter — 三级降级 TTS 方案
 *
 * 优先级（自动检测）：
 *   1. Qwen TTS（DashScope API，通过 /api/tts 代理）— 最高质量，中文自然语音
 *   2. Web Speech API + Edge 神经音色（Xiaoxiao/Yunxi）— 中等质量，免费
 *   3. Web Speech API 普通音色 — 基本可用，兜底
 *
 * 对标 OpenMAIC AudioPlayer（lib/utils/audio-player.ts）的接口设计。
 * 注：Kokoro-js 仅支持英文，不适合中文课程，故不采用。
 */

import { normalizeTextForSpeech } from './textNormalize';

export type TTSQuality = 'qwen' | 'neural' | 'basic';

interface TTSAdapterOptions {
  /** 速率 0.5 ~ 2.0，默认 1.0 */
  rate?: number;
  /** 音色（Qwen 可用：Cherry/Ethan/Serena，默认 Cherry） */
  voice?: string;
  /** 是否强制使用 Web Speech API（跳过 Qwen 检测） */
  forceWebSpeech?: boolean;
}

/** 判断当前 quality 并缓存（避免每次重复检测） */
let cachedQuality: TTSQuality | null = null;

/** v6.5 · 让 speakQwen 失败时能永久降级（避免每个 chunk 都重试 Qwen 然后 404） */
function downgradeQuality(): void {
  cachedQuality = getWebSpeechQuality();
}

async function detectQuality(forceWebSpeech: boolean): Promise<TTSQuality> {
  if (forceWebSpeech) return getWebSpeechQuality();
  if (cachedQuality) return cachedQuality;
  // v6.5 · 改用 GET /api/tts/ping，要求 configured=true 才启用 Qwen
  // （旧实现 HEAD ping 看 200 即用，但 ping 可能即使 API key 没配也返回 200）
  try {
    const res = await fetch('/api/tts/ping', { signal: AbortSignal.timeout(2000) });
    if (res.ok) {
      const data = (await res.json().catch(() => null)) as { ok?: boolean; configured?: boolean } | null;
      if (data && data.ok && data.configured) {
        cachedQuality = 'qwen';
        return 'qwen';
      }
    }
  } catch { /* 忽略 */ }
  cachedQuality = getWebSpeechQuality();
  return cachedQuality;
}

function getWebSpeechQuality(): TTSQuality {
  if (typeof window === 'undefined' || !window.speechSynthesis) return 'basic';
  const voices = window.speechSynthesis.getVoices();
  const hasNeural = voices.some(
    (v) => v.lang.startsWith('zh') && /Xiaoxiao|Yunxi|XiaoXiao|YunXi|云希|晓晓/i.test(v.name)
  );
  return hasNeural ? 'neural' : 'basic';
}

/**
 * TTS 适配器（对外接口）
 * 统一管理：speak(text) → 自动选最优方案 → onDone 回调
 *
 * v6.3 · 对标 OpenMAIC engine.ts 的 ensureVoicesLoaded + cancel-before-speak +
 *        onerror canceled 三件套，修复以下浏览器 TTS 痼疾：
 *   - Chrome 首次调用 getVoices() 拿到空数组 → 自动等 voiceschanged 事件
 *   - 连续 speak 之间不 cancel 导致第二段糊音 → 每次 utterance.speak 前先 cancel
 *   - 用户暂停/切页时控制台冒一堆 canceled 假错误 → 标记 expectingCancel，onerror 静默
 */
export class TTSAdapter {
  private opts: Required<TTSAdapterOptions>;
  private quality: TTSQuality | null = null;
  private currentAudio: HTMLAudioElement | null = null;
  private disposed = false;
  /** v6.3 · 当外部主动 stop()/pause() 时设为 true，让 utterance.onerror('canceled') 静默。 */
  private expectingCancel = false;
  /** v6.3 · 缓存已加载的 voices（Chrome 异步加载）。 */
  private cachedVoices: SpeechSynthesisVoice[] | null = null;

  constructor(opts: TTSAdapterOptions = {}) {
    this.opts = {
      rate: opts.rate ?? 1.0,
      voice: opts.voice ?? 'Cherry',
      forceWebSpeech: opts.forceWebSpeech ?? false,
    };
  }

  /** 检测并缓存最佳 TTS 方案；同时预热 voices（Chrome 异步加载）。 */
  async init(): Promise<TTSQuality> {
    this.quality = await detectQuality(this.opts.forceWebSpeech);
    // 预热 voices：避免第一次 speak 时还要等 voiceschanged
    void this.ensureVoicesLoaded();
    return this.quality;
  }

  getQuality(): TTSQuality | null { return this.quality; }
  setRate(r: number): void { this.opts.rate = r; }

  /**
   * 朗读文字，完成后调用 onDone。
   * 注：文字已在 BlockPlaybackEngine 中做了句子级分块。
   * v6.3 · 增加 cancel-before-speak 防糊音 + 区分 onerror canceled 不算错误。
   * v6.7 · 朗读前统一走 normalizeTextForSpeech（单位/运算符/上下标 → 中文读法），
   *        bubble 仍显示原文（onSpeechText 在更上游已发），TTS 后端只收规范化版。
   */
  speak(text: string, onDone: () => void, onError?: (e: Error) => void): void {
    if (this.disposed || !text) { onDone(); return; }
    const spoken = normalizeTextForSpeech(text);
    if (!spoken) { onDone(); return; }
    const quality = this.quality ?? 'basic';
    if (quality === 'qwen') {
      this.speakQwen(spoken, onDone, onError ?? (() => void this.speakWebSpeech(spoken, onDone)));
    } else {
      void this.speakWebSpeech(spoken, onDone);
    }
  }

  /**
   * 主动取消（stop / 用户切页时调用）
   * v6.3 · 加上 expectingCancel 标记，让 utterance.onerror 知道这是预期事件。
   */
  stop(): void {
    this.currentAudio?.pause();
    this.currentAudio = null;
    if (typeof window !== 'undefined' && window.speechSynthesis) {
      this.expectingCancel = true;
      window.speechSynthesis.cancel();
      // 200ms 后清掉 expectingCancel——足够 onerror('canceled') 触发完
      setTimeout(() => { this.expectingCancel = false; }, 200);
    }
  }

  /**
   * v6.4 · 暂停 mp3 播放（HTMLAudioElement.pause()）
   * 仅当当前在播预生成 mp3 时有意义；返回 true 表示真的暂停了，false 表示没有活跃 mp3。
   * WebSpeech 路径不在这里处理——上层 BlockPlaybackEngine 走 chunked cancel+save 模式。
   */
  pauseAudio(): boolean {
    if (this.currentAudio && !this.currentAudio.paused && !this.currentAudio.ended) {
      this.currentAudio.pause();
      return true;
    }
    return false;
  }

  /** v6.4 · 恢复 mp3 播放。无活跃 audio 时返回 false。 */
  resumeAudio(): boolean {
    if (this.currentAudio && this.currentAudio.paused && !this.currentAudio.ended) {
      void this.currentAudio.play().catch(() => { /* 忽略：浏览器可能阻止 autoplay */ });
      return true;
    }
    return false;
  }

  /** v6.4 · 是否有活跃的 mp3 正在播放或已暂停（即可恢复）。 */
  hasActiveAudio(): boolean {
    return !!this.currentAudio && !this.currentAudio.ended;
  }

  dispose(): void {
    this.disposed = true;
    this.stop();
  }

  // ── Qwen TTS（通过后端 /api/tts/generate 代理，避免前端 CORS）───────
  // v6.5 · 修复 URL/响应不匹配：
  //   - URL: /api/tts → /api/tts/generate（后端实际路由）
  //   - 响应: blob → JSON {ok, audioUrl} (audioUrl 是 data:audio/...;base64,... 或 https URL)
  //   - 失败时永久降级 cachedQuality 为 webspeech，避免每个 chunk 都重试 404
  private speakQwen(text: string, onDone: () => void, onError: (e: Error) => void): void {
    const fail = (msg: string) => {
      // 永久降级：下次 speak 直接走 webspeech 不再尝试 Qwen
      downgradeQuality();
      this.quality = cachedQuality;
      onError(new Error(msg));
    };
    const body = JSON.stringify({ text, voice: this.opts.voice, rate: this.opts.rate });
    fetch('/api/tts/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
      signal: AbortSignal.timeout(15000),
    })
      .then(async (res) => {
        if (!res.ok) throw new Error(`TTS API ${res.status}`);
        const data = (await res.json()) as { ok?: boolean; audioUrl?: string };
        if (!data.ok || !data.audioUrl) throw new Error('TTS empty audioUrl');
        return data.audioUrl;
      })
      .then((audioUrl) => {
        if (this.disposed) return onDone();
        const audio = new Audio(audioUrl);
        this.currentAudio = audio;
        audio.onended = () => { if (!this.disposed) onDone(); };
        audio.onerror = () => fail('audio decode error');
        audio.play().catch(() => fail('audio play failed'));
      })
      .catch((e) => fail(e instanceof Error ? e.message : String(e)));
  }

  // ── Web Speech API（含神经音色自动检测）────────────────────────────
  /**
   * v6.3 · 对标 OpenMAIC engine.ts:
   *   1. ensureVoicesLoaded：Chrome voices 异步加载，必须等 voiceschanged
   *   2. cancel() before speak()：清掉残余合成状态，避免第二段糊音
   *   3. onerror.error === 'canceled' 区分：用户主动 cancel 不算错误
   */
  private async speakWebSpeech(text: string, onDone: () => void): Promise<void> {
    if (typeof window === 'undefined' || !window.speechSynthesis) {
      // 无 TTS 时按阅读速度等待，避免字幕一闪即逝。
      // CJK: 150ms/字 | 非CJK: 240ms/词 | 最少 2s
      const cjk = (text.match(/[\u4e00-\u9fff\u3400-\u4dbf]/g) || []).length;
      const isCJK = text.length > 0 && cjk / text.length > 0.3;
      const rawMs = isCJK
        ? Math.max(2000, text.length * 150)
        : Math.max(2000, text.split(/\s+/).filter(Boolean).length * 240);
      const readMs = rawMs / this.opts.rate;
      setTimeout(() => { if (!this.disposed) onDone(); }, readMs);
      return;
    }
    const voices = await this.ensureVoicesLoaded();
    if (this.disposed) return;
    const utter = new SpeechSynthesisUtterance(text);
    utter.lang = 'zh-CN';
    utter.rate = this.opts.rate;
    const neural = voices.find(
      (v) => v.lang.startsWith('zh') && /Xiaoxiao|Yunxi|XiaoXiao|YunXi|云希|晓晓/i.test(v.name)
    ) ?? voices.find((v) => v.lang.startsWith('zh'));
    if (neural) {
      utter.voice = neural;
      utter.lang = neural.lang;
    } else {
      // CJK 比例兜底：>30% 走 zh-CN，否则 en-US（对标 OpenMAIC CJK_LANG_THRESHOLD=0.3）
      const cjkLen = (text.match(/[\u4e00-\u9fff\u3400-\u4dbf]/g) || []).length;
      utter.lang = text.length > 0 && cjkLen / text.length > 0.3 ? 'zh-CN' : 'en-US';
    }
    utter.onend = () => { if (!this.disposed) onDone(); };
    utter.onerror = (event) => {
      // 'canceled' / 'interrupted' 是用户主动 stop 的预期事件，不是真错误
      const err = (event as SpeechSynthesisErrorEvent).error;
      if (err === 'canceled' || err === 'interrupted' || this.expectingCancel) {
        // 静默——pause/stop 路径自己处理 onDone 时机
        return;
      }
      if (!this.disposed) onDone();
    };
    // ★ Chrome bug workaround：speak 之前先 cancel，清残余合成状态
    window.speechSynthesis.cancel();
    // 给 cancel 一点时间排空队列再 speak，避免 onerror('canceled') 紧接着覆盖新 utterance
    setTimeout(() => {
      if (this.disposed) return;
      window.speechSynthesis.speak(utter);
    }, 30);
  }

  // ── ensureVoicesLoaded（对标 OpenMAIC engine.ts:705-733）─────────────
  private async ensureVoicesLoaded(): Promise<SpeechSynthesisVoice[]> {
    if (this.cachedVoices && this.cachedVoices.length > 0) return this.cachedVoices;
    if (typeof window === 'undefined' || !window.speechSynthesis) return [];

    let voices = window.speechSynthesis.getVoices();
    if (voices.length > 0) {
      this.cachedVoices = voices;
      return voices;
    }
    // Chrome：voices 异步加载，等 voiceschanged 事件，2s 超时兜底
    await new Promise<void>((resolve) => {
      const onChanged = () => {
        window.speechSynthesis.removeEventListener('voiceschanged', onChanged);
        resolve();
      };
      window.speechSynthesis.addEventListener('voiceschanged', onChanged);
      setTimeout(() => {
        window.speechSynthesis.removeEventListener('voiceschanged', onChanged);
        resolve();
      }, 2000);
    });
    voices = window.speechSynthesis.getVoices();
    this.cachedVoices = voices;
    return voices;
  }
}
