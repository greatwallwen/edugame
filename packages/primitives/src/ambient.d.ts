/** 非 JS/TS 资源的最小声明；由消费者（Vite）提供真实解析。 */
declare module '*.css';

/** pixi-live2d-display 类型声明 */
declare module 'pixi-live2d-display' {
  import type { Container, DisplayObject } from 'pixi.js';

  export interface Live2DModelOptions {
    autoInteract?: boolean;
    motionPreload?: 'NONE' | 'IDLE' | 'ALL';
  }

  export class Live2DModel extends Container {
    static from(source: string | object, options?: Live2DModelOptions): Promise<Live2DModel>;

    internalModel: {
      motionManager: {
        expressionManager?: {
          setExpression(expression: string | number): void;
          getExpression(): string | number | undefined;
        };
        startRandomMotion(group: string, priority?: number): void;
        expression(expression: string | number): void;
      };
      coreModel: {
        getParameterValueById(id: string): number;
        setParameterValueById(id: string, value: number): void;
      };
    };

    scale: { set(value: number): void };
    x: number;
    y: number;
    width: number;
    height: number;

    destroy(options?: boolean | object): void;
  }
}
