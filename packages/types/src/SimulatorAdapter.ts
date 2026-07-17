/**
 * SimulatorAdapter.ts — 多学科仿真能力抽象层
 *
 * 统一接口封装不同仿真后端（Wokwi、Renode、公司自研平台等），
 * 使 block 渲染组件只依赖接口而非具体实现。
 *
 * 架构：
 *   CourseManifest.experiment.simulator → SimulatorAdapter.create(type, config)
 *   ↓
 *   WokwiAdapter / RenodeAdapter / CustomAdapter
 *   ↓
 *   iframe / WebSocket / REST API
 */

export interface SimulatorConfig {
  type: 'wokwi' | 'renode' | 'custom';
  /** 仿真场景 URL 或 scene JSON 路径 */
  sceneUrl?: string;
  /** iframe 嵌入 URL */
  embedUrl?: string;
  /** WebSocket 端点（Renode 远程仿真） */
  wsEndpoint?: string;
  /** 场景初始化参数 */
  params?: Record<string, unknown>;
}

export interface SimulatorState {
  status: 'idle' | 'loading' | 'running' | 'paused' | 'error';
  errorMessage?: string;
}

export interface PinState {
  pin: string;
  value: number;       // 0 或 1（数字），0~4095（模拟）
  direction: 'input' | 'output';
}

export interface SimulatorAdapter {
  /** 适配器类型标识 */
  readonly type: string;

  /** 初始化仿真器 */
  init(config: SimulatorConfig): Promise<void>;

  /** 获取当前状态 */
  getState(): SimulatorState;

  /** 加载场景 */
  loadScene(sceneUrl: string): Promise<void>;

  /** 启动仿真 */
  start(): Promise<void>;

  /** 暂停仿真 */
  pause(): Promise<void>;

  /** 重置仿真 */
  reset(): Promise<void>;

  /** 读取引脚状态 */
  readPin(pin: string): Promise<PinState>;

  /** 设置引脚状态（模拟传感器输入） */
  writePin(pin: string, value: number): Promise<void>;

  /** 发送串口数据 */
  sendSerial(data: string): Promise<void>;

  /** 接收串口数据回调 */
  onSerialReceive(callback: (data: string) => void): void;

  /** 获取 iframe 嵌入元素（用于 Wokwi 等基于 iframe 的仿真器） */
  getEmbedElement(): HTMLIFrameElement | null;

  /** 销毁仿真器，释放资源 */
  destroy(): void;
}

/**
 * Wokwi 适配器 — 基于 iframe postMessage
 */
export class WokwiAdapter implements SimulatorAdapter {
  readonly type = 'wokwi';
  private iframe: HTMLIFrameElement | null = null;
  private state: SimulatorState = { status: 'idle' };

  async init(config: SimulatorConfig): Promise<void> {
    this.state = { status: 'loading' };
    if (config.embedUrl) {
      this.iframe = document.createElement('iframe');
      this.iframe.src = config.embedUrl;
      this.iframe.style.cssText = 'width:100%;height:400px;border:none;border-radius:12px;';
      this.iframe.sandbox.add('allow-scripts', 'allow-same-origin');
    }
  }

  getState(): SimulatorState { return this.state; }

  async loadScene(sceneUrl: string): Promise<void> {
    if (this.iframe) {
      this.iframe.src = sceneUrl;
      this.state = { status: 'running' };
    }
  }

  async start(): Promise<void> { this.state = { status: 'running' }; }
  async pause(): Promise<void> { this.state = { status: 'paused' }; }
  async reset(): Promise<void> { this.state = { status: 'idle' }; }

  async readPin(_pin: string): Promise<PinState> {
    return { pin: _pin, value: 0, direction: 'input' };
  }

  async writePin(_pin: string, _value: number): Promise<void> { /* Wokwi iframe 不支持 */ }
  async sendSerial(_data: string): Promise<void> { /* postMessage to iframe */ }
  onSerialReceive(_callback: (data: string) => void): void { /* window.addEventListener */ }

  getEmbedElement(): HTMLIFrameElement | null { return this.iframe; }

  destroy(): void {
    if (this.iframe?.parentNode) {
      this.iframe.parentNode.removeChild(this.iframe);
    }
    this.iframe = null;
    this.state = { status: 'idle' };
  }
}

/**
 * 仿真适配器工厂
 */
export function createSimulator(config: SimulatorConfig): SimulatorAdapter {
  switch (config.type) {
    case 'wokwi':
      return new WokwiAdapter();
    // case 'renode': return new RenodeAdapter();
    // case 'custom': return new CustomAdapter();
    default:
      return new WokwiAdapter();
  }
}
