/**
 * BlockRegistry.ts — Block 渲染组件注册表
 *
 * 将 PageRenderer.tsx 中巨大的 switch 语句替换为可扩展的注册表模式，
 * 使第三方课程和插件可以注册自定义 block 类型。
 *
 * 用法：
 *   // 注册自定义 block
 *   BlockRegistry.register('custom-sim', CustomSimBlock);
 *
 *   // 注册自定义互动题型
 *   InteractiveRegistry.register('arcade-runner', ArcadeRunnerBlock);
 *
 *   // PageRenderer 中使用
 *   const Component = BlockRegistry.get(block.kind);
 */
import React from 'react';

export type BlockRendererProps = {
  block: any;  // Block 类型
  manifest?: any;
  pageId?: string;
  [key: string]: any;
};

export type BlockRenderer = React.ComponentType<BlockRendererProps>;

export type InteractiveRendererProps = {
  spec: any;  // InteractiveSpec
  [key: string]: any;
};

export type InteractiveRenderer = React.ComponentType<InteractiveRendererProps>;

/**
 * Block 渲染组件注册表
 */
class BlockRegistryImpl {
  private renderers = new Map<string, BlockRenderer>();
  private interactiveRenderers = new Map<string, InteractiveRenderer>();

  /** 注册 block 渲染组件 */
  register(kind: string, renderer: BlockRenderer): void {
    this.renderers.set(kind, renderer);
  }

  /** 注册互动题型渲染组件 */
  registerInteractive(kind: string, renderer: InteractiveRenderer): void {
    this.interactiveRenderers.set(kind, renderer);
  }

  /** 获取 block 渲染组件 */
  get(kind: string): BlockRenderer | undefined {
    return this.renderers.get(kind);
  }

  /** 获取互动题型渲染组件 */
  getInteractive(kind: string): InteractiveRenderer | undefined {
    return this.interactiveRenderers.get(kind);
  }

  /** 检查 block 类型是否已注册 */
  has(kind: string): boolean {
    return this.renderers.has(kind);
  }

  /** 检查互动题型是否已注册 */
  hasInteractive(kind: string): boolean {
    return this.interactiveRenderers.has(kind);
  }

  /** 获取所有已注册的 block 类型 */
  listBlockKinds(): string[] {
    return Array.from(this.renderers.keys());
  }

  /** 获取所有已注册的互动题型 */
  listInteractiveKinds(): string[] {
    return Array.from(this.interactiveRenderers.keys());
  }

  /** 批量注册（用于初始化默认组件） */
  registerAll(entries: Record<string, BlockRenderer>): void {
    for (const [kind, renderer] of Object.entries(entries)) {
      this.register(kind, renderer);
    }
  }

  /** 批量注册互动题型 */
  registerAllInteractive(entries: Record<string, InteractiveRenderer>): void {
    for (const [kind, renderer] of Object.entries(entries)) {
      this.registerInteractive(kind, renderer);
    }
  }
}

/** 全局单例 */
export const BlockRegistry = new BlockRegistryImpl();
export const InteractiveRegistry = BlockRegistry;

export default BlockRegistry;
