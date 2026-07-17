/**
 * @dgbook/anim · 统一动画抽象层
 *
 * AnimDriver 接口统一 SVG-iframe / template / manim / PixiJS 四种动画源。
 * 平台代码只通过 AnimDriver 驱动动画，不感知具体实现。
 */

/** 动画步骤（时间轴节点） */
export interface AnimStep {
  /** 步骤开始时间（秒），仅 manim/video 用 */
  time?: number;
  /** 对应的 speak 文本（用于 TTS 同步） */
  speech?: string;
  /** 视觉动作描述 */
  label?: string;
}

/** 动画数据（从 manifest block 解析） */
export interface AnimData {
  kind: string;
  /** iframe src / video url */
  src?: string;
  /** template name（注册表查找） */
  template?: string;
  /** 模板参数 */
  params?: Record<string, unknown>;
  /** 时间轴步骤 */
  steps?: AnimStep[];
}

/** 统一动画驱动接口 */
export interface AnimDriver {
  readonly kind: string;
  readonly stepCount: number;

  /** 挂载到 DOM 容器 */
  mount(el: HTMLElement): Promise<void>;
  /** 跳到第 n 步（0-based） */
  step(n: number): void;
  /** 从当前位置连续播放 */
  play(): void;
  /** 暂停 */
  pause(): void;
  /** 恢复 */
  resume(): void;
  /** 终态定格 */
  finalize(): void;
  /** 卸载销毁 */
  destroy(): void;

  /** 步骤变化回调 */
  onStepChange?: (step: number) => void;
  /** 播放完成回调 */
  onComplete?: () => void;
}
