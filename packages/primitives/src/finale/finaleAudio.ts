/**
 * Finale Audio · 全程零依赖、零文件的音频层
 *
 * 设计取舍：
 *  - 不依赖外部 mp3 / wav 文件（避免 404 和加载抖动）
 *  - 用 Web Audio API 合成短音效：correct / wrong / combo / stage-clear / boss-defeat / time-warning
 *  - BGM 用三层震荡器叠加合成 pad；主题切换通过频率与节拍调整实现：
 *      tense — A minor 慢速 pad
 *      epic  — D minor 中速 pad + 心跳低频脉冲
 *      calm  — F major 慢速 pad
 *  - 自动播放策略：必须用户首次手势（点击 trigger）后再 init；之前所有调用静默丢弃。
 *  - 静音切换：muted 时不合成、不发声，但 AudioContext 不销毁（避免重启延迟）。
 */

export type FinaleAudioTrack = 'tense' | 'epic' | 'calm';

interface OscNode {
  osc: OscillatorNode;
  gain: GainNode;
}

class FinaleAudio {
  private ctx: AudioContext | null = null;
  private master: GainNode | null = null;
  private bgmNodes: OscNode[] = [];
  private heartbeatTimer: number | null = null;
  private currentTrack: FinaleAudioTrack | null = null;
  private muted = false;

  /** 首次用户手势时调用一次。重复调用安全。 */
  init(): boolean {
    if (this.ctx) return true;
    try {
      const w = window as unknown as {
        AudioContext?: typeof AudioContext;
        webkitAudioContext?: typeof AudioContext;
      };
      const Ctor = w.AudioContext ?? w.webkitAudioContext;
      if (!Ctor) return false;
      const ctx = new Ctor();
      const master = ctx.createGain();
      master.gain.value = 0.32;
      master.connect(ctx.destination);
      this.ctx = ctx;
      this.master = master;
      return true;
    } catch {
      return false;
    }
  }

  setMuted(muted: boolean) {
    this.muted = muted;
    if (this.master) {
      this.master.gain.value = muted ? 0 : 0.32;
    }
  }

  isMuted() {
    return this.muted;
  }

  /** 合成单音 beep —— 用于音效 */
  private beep(opts: {
    freq: number;
    duration: number;
    type?: OscillatorType;
    volume?: number;
    attack?: number;
    release?: number;
  }) {
    if (!this.ctx || !this.master || this.muted) return;
    const {
      freq,
      duration,
      type = 'sine',
      volume = 0.4,
      attack = 0.005,
      release = 0.08,
    } = opts;
    const t0 = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t0);
    gain.gain.setValueAtTime(0, t0);
    gain.gain.linearRampToValueAtTime(volume, t0 + attack);
    gain.gain.setValueAtTime(volume, t0 + duration - release);
    gain.gain.linearRampToValueAtTime(0, t0 + duration);
    osc.connect(gain).connect(this.master);
    osc.start(t0);
    osc.stop(t0 + duration + 0.05);
  }

  /** 短滑音 —— combo 升级时上扬 */
  private chirp(opts: {
    freqStart: number;
    freqEnd: number;
    duration: number;
    volume?: number;
  }) {
    if (!this.ctx || !this.master || this.muted) return;
    const t0 = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(opts.freqStart, t0);
    osc.frequency.linearRampToValueAtTime(opts.freqEnd, t0 + opts.duration);
    const v = opts.volume ?? 0.3;
    gain.gain.setValueAtTime(0, t0);
    gain.gain.linearRampToValueAtTime(v, t0 + 0.02);
    gain.gain.linearRampToValueAtTime(0, t0 + opts.duration);
    osc.connect(gain).connect(this.master);
    osc.start(t0);
    osc.stop(t0 + opts.duration + 0.05);
  }

  playCorrect(verdict: 'perfect' | 'great' | 'good') {
    if (verdict === 'perfect') {
      // 上扬 + 高音
      this.chirp({ freqStart: 660, freqEnd: 1100, duration: 0.18 });
      window.setTimeout(() => this.beep({ freq: 1320, duration: 0.12, volume: 0.3 }), 90);
    } else if (verdict === 'great') {
      this.chirp({ freqStart: 520, freqEnd: 880, duration: 0.16 });
    } else {
      this.beep({ freq: 660, duration: 0.12, volume: 0.28 });
    }
  }

  playWrong() {
    // 下沉的钝响
    this.beep({ freq: 220, duration: 0.18, type: 'sawtooth', volume: 0.28 });
    window.setTimeout(() => this.beep({ freq: 165, duration: 0.18, type: 'sawtooth', volume: 0.22 }), 70);
  }

  playCombo(combo: number) {
    const f = 600 + Math.min(combo, 10) * 80;
    this.beep({ freq: f, duration: 0.08, type: 'triangle', volume: 0.25 });
  }

  playStageClear() {
    [523, 659, 784, 1047].forEach((f, i) => {
      window.setTimeout(() => this.beep({ freq: f, duration: 0.18, volume: 0.32 }), i * 90);
    });
  }


  playBossDefeat() {
    // 上行 fanfare：三连音 + 顶音
    [392, 523, 659, 784, 1047].forEach((f, i) => {
      window.setTimeout(
        () => this.beep({ freq: f, duration: 0.22, volume: 0.36 }),
        i * 80,
      );
    });
    window.setTimeout(
      () => this.beep({ freq: 1568, duration: 0.45, volume: 0.4 }),
      450,
    );
  }

  playTimeWarning() {
    // tick 1 声
    this.beep({ freq: 880, duration: 0.06, type: 'square', volume: 0.18 });
  }

  /* ─────────── BGM ─────────── */

  playBgm(track: FinaleAudioTrack) {
    if (!this.ctx || !this.master) return;
    if (this.currentTrack === track) return;
    this.stopBgm();
    this.currentTrack = track;
    if (this.muted) return;

    const presets: Record<
      FinaleAudioTrack,
      { freqs: number[]; volume: number; lfoRate: number }
    > = {
      tense: { freqs: [110, 165, 220], volume: 0.06, lfoRate: 0.5 },
      epic: { freqs: [73.4, 110, 146.8, 220], volume: 0.08, lfoRate: 0.8 },
      calm: { freqs: [130.8, 196, 261.6], volume: 0.05, lfoRate: 0.35 },
    };
    const preset = presets[track];
    const t0 = this.ctx.currentTime;

    preset.freqs.forEach((f, i) => {
      const osc = this.ctx!.createOscillator();
      const gain = this.ctx!.createGain();
      osc.type = i === 0 ? 'sine' : 'triangle';
      osc.frequency.setValueAtTime(f, t0);
      gain.gain.setValueAtTime(0, t0);
      gain.gain.linearRampToValueAtTime(preset.volume, t0 + 1.2);

      // LFO 让 pad 有"呼吸感"
      const lfo = this.ctx!.createOscillator();
      const lfoGain = this.ctx!.createGain();
      lfo.frequency.setValueAtTime(preset.lfoRate, t0);
      lfoGain.gain.setValueAtTime(preset.volume * 0.4, t0);
      lfo.connect(lfoGain).connect(gain.gain);
      lfo.start(t0);

      osc.connect(gain).connect(this.master!);
      osc.start(t0);
      this.bgmNodes.push({ osc, gain });
      this.bgmNodes.push({ osc: lfo, gain: lfoGain });
    });

    // epic 加心跳
    if (track === 'epic') {
      const beat = () => {
        if (this.currentTrack !== 'epic') return;
        this.beep({ freq: 60, duration: 0.18, type: 'sine', volume: 0.18 });
        window.setTimeout(() => {
          this.beep({ freq: 50, duration: 0.16, type: 'sine', volume: 0.14 });
        }, 180);
      };
      beat();
      this.heartbeatTimer = window.setInterval(beat, 900);
    }
  }

  stopBgm() {
    if (!this.ctx) return;
    const t0 = this.ctx.currentTime;
    this.bgmNodes.forEach(({ osc, gain }) => {
      try {
        gain.gain.cancelScheduledValues(t0);
        gain.gain.setValueAtTime(gain.gain.value, t0);
        gain.gain.linearRampToValueAtTime(0, t0 + 0.4);
        osc.stop(t0 + 0.5);
      } catch {
        /* noop */
      }
    });
    this.bgmNodes = [];
    if (this.heartbeatTimer !== null) {
      window.clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
    this.currentTrack = null;
  }

  /** 卸载（页面切换 / 关闭挑战） */
  dispose() {
    this.stopBgm();
    if (this.ctx) {
      try {
        this.ctx.close();
      } catch {
        /* noop */
      }
    }
    this.ctx = null;
    this.master = null;
  }
}

let singleton: FinaleAudio | null = null;

export function getFinaleAudio(): FinaleAudio {
  if (!singleton) singleton = new FinaleAudio();
  return singleton;
}
