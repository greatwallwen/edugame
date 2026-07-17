/**
 * 纯 SVG 数字人头像。
 *
 * - 呼吸：整体 scale + Y 位移（CSS keyframe）
 * - 眨眼：眼睑 scaleY 周期收闭（CSS keyframe，间隔 ~5s）
 * - 脉动光晕：HUD 圆环（chip-dark 主题下尤为明显）
 * - 颜色全部来自 CSS variables，自动跟随主题
 *
 * 渲染于 Shell 右下角浮窗（DigitalHumanFloat）。无外部依赖。
 */
import s from './Avatar.module.css';

interface AvatarProps {
  /** 当前是否在播报；true 时嘴部脉动幅度更大 */
  speaking?: boolean;
  size?: number;
}

export function Avatar({ speaking = false, size = 132 }: AvatarProps) {
  return (
    <svg
      className={`${s.avatar} ${speaking ? s.speaking : ''}`}
      width={size}
      height={size}
      viewBox="0 0 132 132"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden
    >
      {/* HUD 双圆环 */}
      <circle className={s.ringOuter} cx="66" cy="66" r="62" />
      <circle className={s.ringInner} cx="66" cy="66" r="54" />
      {/* 四向刻度 */}
      <g className={s.ticks} stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
        <line x1="66" y1="2"  x2="66" y2="9" />
        <line x1="66" y1="123" x2="66" y2="130" />
        <line x1="2"  y1="66" x2="9"  y2="66" />
        <line x1="123" y1="66" x2="130" y2="66" />
      </g>

      {/* 整个头部组：呼吸动画 */}
      <g className={s.head}>
        {/* 头部外形（圆角矩形 + 顶部线圈，呼应芯片质感） */}
        <rect className={s.face} x="36" y="32" width="60" height="68" rx="22" />
        {/* 头顶天线/接口针脚 */}
        <g className={s.pins} stroke="currentColor" strokeWidth="2" strokeLinecap="round">
          <line x1="50" y1="30" x2="50" y2="22" />
          <line x1="66" y1="30" x2="66" y2="20" />
          <line x1="82" y1="30" x2="82" y2="22" />
        </g>
        {/* 眼睛 — 用两条短弧 */}
        <g className={s.eyes}>
          <ellipse className={s.eye} cx="54" cy="60" rx="5" ry="5" />
          <ellipse className={s.eye} cx="78" cy="60" rx="5" ry="5" />
          {/* 眨眼眼睑（覆盖在眼睛上方，scaleY 缩放） */}
          <rect className={s.lid} x="48" y="55" width="12" height="10" rx="2" />
          <rect className={s.lid} x="72" y="55" width="12" height="10" rx="2" />
        </g>
        {/* 嘴 — 横线，speaking 时高度脉动 */}
        <rect className={s.mouth} x="56" y="80" width="20" height="3" rx="1.5" />
        {/* 颊部电路装饰（左右各一条） */}
        <g className={s.circuit} stroke="currentColor" strokeWidth="1.2" fill="none" strokeLinecap="round">
          <path d="M40 70 L34 70 L34 80 L40 80" />
          <path d="M92 70 L98 70 L98 80 L92 80" />
        </g>
      </g>

      {/* 底部音波 */}
      <g className={s.wave}>
        <line x1="48" y1="115" x2="84" y2="115" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
        <line className={s.waveBar1} x1="56" y1="119" x2="58" y2="111" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
        <line className={s.waveBar2} x1="64" y1="121" x2="66" y2="109" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
        <line className={s.waveBar3} x1="72" y1="119" x2="74" y2="111" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
      </g>
    </svg>
  );
}
