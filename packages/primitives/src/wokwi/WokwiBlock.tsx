
import type { ReactNode } from 'react';
import { WokwiLED, type WokwiLEDProps } from './WokwiLED';
import { WokwiResistor, type WokwiResistorProps } from './WokwiResistor';
import { WokwiPushbutton, type WokwiPushbuttonProps } from './WokwiPushbutton';
import {
  WokwiBuzzer, type WokwiBuzzerProps,
  Wokwi7Segment, type Wokwi7SegmentProps,
  WokwiPotentiometer, type WokwiPotentiometerProps,
  WokwiBreadboardMini, type WokwiBreadboardMiniProps,
  WokwiArduinoUno, type WokwiArduinoUnoProps,
} from './WokwiExtended';
import './WokwiBlock.css';

/**
 * 与 packages/types/src/manifest-block.ts WokwiElementBlockSchema 严格对应。
 * spec 字段在 schema 层用 discriminated union（kind 区分），这里 props 类型保持镜像。
 */
export type WokwiElementSpec =
  | ({ kind: 'led' } & WokwiLEDProps)
  | ({ kind: 'resistor' } & WokwiResistorProps)
  | ({ kind: 'pushbutton' } & WokwiPushbuttonProps)
  | ({ kind: 'buzzer' } & WokwiBuzzerProps)
  | ({ kind: '7segment' } & Wokwi7SegmentProps)
  | ({ kind: 'potentiometer' } & WokwiPotentiometerProps)
  | ({ kind: 'breadboard-mini' } & WokwiBreadboardMiniProps)
  | ({ kind: 'arduino-uno' } & WokwiArduinoUnoProps);

export interface WokwiBlockProps {
  /** Block 主键（来自 manifest.block.id），用于 G3 高亮协议 */
  blockId: string;
  /** 三件套 spec */
  spec: WokwiElementSpec;
  /** 顶部小标题（可选） */
  title?: string;
  /** 底部 caption（可选） */
  caption?: string;
}

function renderElement(spec: WokwiElementSpec, elementId: string): ReactNode {
  // discriminated union：按 kind 选组件，spread 剩余字段（已通过 schema 校验合法）
  if (spec.kind === 'led') {
    const { kind: _k, ...props } = spec;
    return <WokwiLED {...props} data-element-id={elementId} />;
  }
  if (spec.kind === 'resistor') {
    const { kind: _k, ...props } = spec;
    return <WokwiResistor {...props} data-element-id={elementId} />;
  }
  if (spec.kind === 'pushbutton') {
    const { kind: _k, ...props } = spec;
    return <WokwiPushbutton {...props} data-element-id={elementId} />;
  }
  if (spec.kind === 'buzzer') {
    const { kind: _k, ...props } = spec;
    return <WokwiBuzzer {...props} data-element-id={elementId} />;
  }
  if (spec.kind === '7segment') {
    const { kind: _k, ...props } = spec;
    return <Wokwi7Segment {...props} data-element-id={elementId} />;
  }
  if (spec.kind === 'potentiometer') {
    const { kind: _k, ...props } = spec;
    return <WokwiPotentiometer {...props} data-element-id={elementId} />;
  }
  if (spec.kind === 'breadboard-mini') {
    const { kind: _k, ...props } = spec;
    return <WokwiBreadboardMini {...props} data-element-id={elementId} />;
  }
  if (spec.kind === 'arduino-uno') {
    const { kind: _k, ...props } = spec;
    return <WokwiArduinoUno {...props} data-element-id={elementId} />;
  }
  return null;
}

export function WokwiBlock({ blockId, spec, title, caption }: WokwiBlockProps) {
  const elementId = `dgb-wokwi-${blockId}`;
  return (
    <figure className="dgb-wokwi-block" data-block-id={blockId}>
      {title ? <figcaption className="dgb-wokwi-block__title">{title}</figcaption> : null}
      <div className="dgb-wokwi-block__stage">{renderElement(spec, elementId)}</div>
      {caption ? <figcaption className="dgb-wokwi-block__caption">{caption}</figcaption> : null}
    </figure>
  );
}
