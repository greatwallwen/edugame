/**
 * ManimDriver · 视频播放 + step 时间轴同步
 *
 * 加载 manim 预渲染视频，按 steps[].time 触发 onStepChange，
 * 让 ActionEngine 可以在对应时间点触发 speak / spotlight。
 */
import type { AnimDriver, AnimData, AnimStep } from '../types';

export class ManimDriver implements AnimDriver {
  readonly kind = 'manim';
  private video: HTMLVideoElement | null = null;
  private steps: AnimStep[];
  private currentStep = -1;
  private timeUpdateHandler: (() => void) | null = null;

  onStepChange?: (step: number) => void;
  onComplete?: () => void;

  constructor(private data: AnimData) {
    this.steps = data.steps ?? [];
  }

  get stepCount(): number {
    return this.steps.length;
  }

  async mount(el: HTMLElement): Promise<void> {
    const video = document.createElement('video');
    video.className = 'dgb-anim-manim-video';
    video.style.width = '100%';
    video.style.height = '100%';
    video.style.objectFit = 'contain';
    video.preload = 'auto';
    video.playsInline = true;
    if (this.data.src) {
      video.src = this.data.src;
    }
    el.appendChild(video);
    this.video = video;

    // 时间轴同步
    this.timeUpdateHandler = () => {
      if (!this.video) return;
      const t = this.video.currentTime;
      let nextStep = -1;
      for (let i = 0; i < this.steps.length; i++) {
        const stepTime = this.steps[i]?.time ?? 0;
        if (t >= stepTime) nextStep = i;
      }
      if (nextStep !== this.currentStep && nextStep >= 0) {
        this.currentStep = nextStep;
        this.onStepChange?.(nextStep);
      }
    };
    video.addEventListener('timeupdate', this.timeUpdateHandler);
    video.addEventListener('ended', () => this.onComplete?.());

    // 等 metadata 加载
    await new Promise<void>((resolve) => {
      video.onloadedmetadata = () => resolve();
      setTimeout(resolve, 5000);
    });
  }

  step(n: number): void {
    if (!this.video || n < 0 || n >= this.steps.length) return;
    const time = this.steps[n]?.time ?? 0;
    this.video.currentTime = time;
    this.currentStep = n;
    this.onStepChange?.(n);
  }

  play(): void {
    void this.video?.play();
  }

  pause(): void {
    this.video?.pause();
  }

  resume(): void {
    void this.video?.play();
  }

  finalize(): void {
    if (this.video) {
      this.video.currentTime = this.video.duration || 0;
    }
    this.onComplete?.();
  }

  destroy(): void {
    if (this.video) {
      if (this.timeUpdateHandler) {
        this.video.removeEventListener('timeupdate', this.timeUpdateHandler);
      }
      this.video.pause();
      this.video.src = '';
      this.video.remove();
      this.video = null;
    }
  }
}
