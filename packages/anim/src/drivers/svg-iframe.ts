/**
 * SvgIframeDriver · 封装 inline SVG iframe 的 postMessage 协议
 *
 * 把 Shell.tsx 中散落的 dgb-step / dgb-anim-finalize 协议集中到此处。
 * 调用方只需 driver.step(n) / driver.finalize()，不再手动操作 iframe。
 */
import type { AnimDriver, AnimData } from '../types';

export class SvgIframeDriver implements AnimDriver {
  readonly kind = 'svg-iframe';
  private iframe: HTMLIFrameElement | null = null;
  private _stepCount: number;
  private currentStep = -1;

  onStepChange?: (step: number) => void;
  onComplete?: () => void;

  constructor(private data: AnimData) {
    this._stepCount = data.steps?.length ?? 0;
  }

  get stepCount(): number {
    return this._stepCount;
  }

  async mount(el: HTMLElement): Promise<void> {
    const iframe = document.createElement('iframe');
    iframe.className = 'dgb-anim-html-frame';
    iframe.style.width = '100%';
    iframe.style.height = '100%';
    iframe.style.border = 'none';
    if (this.data.src) {
      iframe.srcdoc = this.data.src.replace(/^inline:/, '');
    }
    el.appendChild(iframe);
    this.iframe = iframe;

    // 等 iframe 加载完成
    await new Promise<void>((resolve) => {
      iframe.onload = () => resolve();
      setTimeout(resolve, 3000); // 3s 超时兜底
    });
  }

  step(n: number): void {
    if (!this.iframe?.contentWindow) return;
    this.currentStep = n;
    this.iframe.contentWindow.postMessage({ type: 'dgb-step', step: n }, '*');
    this.onStepChange?.(n);
  }

  play(): void {
    // SVG iframe 没有连续播放概念，逐步推进
    if (this.currentStep < this._stepCount - 1) {
      this.step(this.currentStep + 1);
    }
  }

  pause(): void {
    // SVG iframe 是静态帧，pause 无操作
  }

  resume(): void {
    // 同 pause
  }

  finalize(): void {
    if (!this.iframe?.contentWindow) return;
    this.iframe.contentWindow.postMessage({ type: 'dgb-anim-finalize' }, '*');
    this.onComplete?.();
  }

  destroy(): void {
    if (this.iframe) {
      this.iframe.remove();
      this.iframe = null;
    }
  }
}
