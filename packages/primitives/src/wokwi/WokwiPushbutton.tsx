
import {
  useCallback,
  useId,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
  type KeyboardEvent,
  type PointerEvent,
} from 'react';

export interface WokwiPushbuttonProps {
  /** 按钮帽颜色 */
  color?: string;
  /** 受控按下状态；不传则内部 state */
  pressed?: boolean;
  /** 按钮下方标签 */
  label?: string;
  /** 透视模式（显示内部金属片） */
  xray?: boolean;
  /** 按下回调 */
  onPress?: () => void;
  /** 松开回调 */
  onRelease?: () => void;
  className?: string;
  /** Phase G3 · 让 ActionRunner 能高亮 */
  'data-element-id'?: string;
}

const containerStyle: CSSProperties = {
  display: 'inline-flex',
  flexDirection: 'column',
  alignItems: 'center',
};

const labelStyle: CSSProperties = {
  fontSize: 12,
  textAlign: 'center',
  color: 'gray',
  position: 'relative',
  lineHeight: 1,
  top: -2,
};

const buttonStyle: CSSProperties = {
  border: 'none',
  background: 'none',
  padding: 0,
  margin: 0,
  cursor: 'pointer',
  WebkitAppearance: 'none',
  MozAppearance: 'none',
};

const SPACE_KEYS = [' ', 'Spacebar', 'Enter'];

export function WokwiPushbutton({
  color = 'red',
  pressed,
  label = '',
  xray = false,
  onPress,
  onRelease,
  className,
  ...rest
}: WokwiPushbuttonProps) {
  const reactId = useId();
  const uid = useMemo(() => reactId.replace(/[:]/g, '-'), [reactId]);
  const [internalPressed, setInternalPressed] = useState(false);
  const isControlled = pressed !== undefined;
  const isPressed = isControlled ? pressed : internalPressed;
  const stuckRef = useRef(false);

  const buttonFill = isPressed ? `url(#dgb-wokwi-pb-down-${uid})` : `url(#dgb-wokwi-pb-up-${uid})`;

  const doPress = useCallback(() => {
    if (!isControlled) setInternalPressed(true);
    onPress?.();
  }, [isControlled, onPress]);

  const doRelease = useCallback(() => {
    if (!isControlled) setInternalPressed(false);
    onRelease?.();
  }, [isControlled, onRelease]);

  const handlePointerDown = (e: PointerEvent<HTMLButtonElement>) => {
    e.preventDefault();
    doPress();
  };
  const handlePointerUp = () => {
    if (stuckRef.current) {
      stuckRef.current = false;
      return;
    }
    doRelease();
  };
  const handlePointerLeave = () => {
    if (!stuckRef.current && isPressed) doRelease();
  };
  const handleKeyDown = (e: KeyboardEvent<HTMLButtonElement>) => {
    if (SPACE_KEYS.includes(e.key)) {
      e.preventDefault();
      doPress();
    }
  };
  const handleKeyUp = (e: KeyboardEvent<HTMLButtonElement>) => {
    if (SPACE_KEYS.includes(e.key)) {
      e.preventDefault();
      doRelease();
    }
  };

  return (
    <span
      className={className}
      style={containerStyle}
      data-element-id={rest['data-element-id']}
      data-wokwi-kind="pushbutton"
    >
      <button
        type="button"
        aria-label={`${label} ${color} pushbutton`}
        aria-pressed={isPressed}
        style={buttonStyle}
        onPointerDown={handlePointerDown}
        onPointerUp={handlePointerUp}
        onPointerLeave={handlePointerLeave}
        onKeyDown={handleKeyDown}
        onKeyUp={handleKeyUp}
      >
        <svg
          width="71"
          height="48"
          version="1.1"
          viewBox="-3 0 18 12"
          xmlns="http://www.w3.org/2000/svg"
          aria-hidden="true"
        >

          <defs>
            <linearGradient id={`dgb-wokwi-pb-up-${uid}`} x1="0" x2="1" y1="0" y2="1">
              <stop stopColor="#ffffff" offset="0" />
              <stop stopColor={color} offset="0.3" />
              <stop stopColor={color} offset="0.5" />
              <stop offset="1" />
            </linearGradient>
            <linearGradient id={`dgb-wokwi-pb-down-${uid}`} x1="1" x2="0" y1="1" y2="0">
              <stop stopColor="#ffffff" offset="0" />
              <stop stopColor={color} offset="0.3" />
              <stop stopColor={color} offset="0.5" />
              <stop offset="1" />
            </linearGradient>
          </defs>
          <rect x="0" y="0" width="12" height="12" rx=".44" ry=".44" fill="#464646" />
          <rect x=".75" y=".75" width="10.5" height="10.5" rx=".211" ry=".211" fill="#eaeaea" />
          {xray && (
            <>
              <rect
                style={{ opacity: 0.3, fill: '#999999', strokeWidth: 0.563001, paintOrder: 'stroke markers fill' }}
                width="12.087865"
                height="1.0371729"
                x="-0.00075517414"
                y="2.9106798"
              />
              <rect
                style={{ opacity: 0.3, fill: '#999999', strokeWidth: 0.534365, paintOrder: 'stroke markers fill' }}
                width="12.087865"
                height="0.93434691"
                x="-0.071111664"
                y="8.0458994"
              />
            </>
          )}
          <g fill="#1b1b1">
            <circle cx="1.767" cy="1.7916" r=".37" />
            <circle cx="10.161" cy="1.7916" r=".37" />
            <circle cx="10.161" cy="10.197" r=".37" />
            <circle cx="1.767" cy="10.197" r=".37" />
          </g>
          <g fill="#999" strokeWidth="1.0154">
            <path d="m12.365 2.426c0.06012 0 0.10849 0.0469 0.1085 0.10522v0.38698h2.2173c0.12023 0 0.217 0.0938 0.217 0.21045v0.50721c0 0.1166-0.09677 0.21045-0.217 0.21045h-2.2173v0.40101c0 0.0583-0.0484 0.10528-0.1085 0.10528h-0.36835v-1.9266z" />
            <path d="m12.365 7.5c0.06012 0 0.10849 0.0469 0.1085 0.10522v0.38698h2.2173c0.12023 0 0.217 0.0938 0.217 0.21045v0.50721c0 0.1166-0.09677 0.21045-0.217 0.21045h-2.2173v0.40101c0 0.0583-0.0484 0.10528-0.1085 0.10528h-0.36835v-1.9266z" />
            <path d="m-0.35085 4.3526c-0.06012 0-0.10849-0.0469-0.1085-0.10522v-0.38698h-2.2173c-0.12023 0-0.217-0.0938-0.217-0.21045v-0.50721c0-0.1166 0.09677-0.21045 0.217-0.21045h2.2173v-0.40101c0-0.0583 0.0484-0.10528 0.1085-0.10528h0.36835v1.9266z" />
            <path d="m-0.35085 9.4266c-0.06012 0-0.10849-0.0469-0.1085-0.10522v-0.38698h-2.2173c-0.12023 0-0.217-0.0938-0.217-0.21045v-0.50721c0-0.1166 0.09677-0.21045 0.217-0.21045h2.2173v-0.40101c0-0.0583 0.0484-0.10528 0.1085-0.10528h0.36835v1.9266z" />
          </g>
          <g>
            <circle cx="6" cy="6" r="3.822" fill={buttonFill} />
            <circle
              cx="6"
              cy="6"
              r="2.9"
              fill={color}
              stroke="#2f2f2f"
              strokeOpacity=".47"
              strokeWidth=".08"
            />
          </g>
        </svg>
      </button>
      {label ? <span style={labelStyle}>{label}</span> : null}
    </span>
  );
}
