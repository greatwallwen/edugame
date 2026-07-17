import './TeacherAvatar.css';

export interface TeacherAvatarProps {
  speaking?: boolean;
  size?: number;
}

/** 简约 SVG 讲师头像 — 圆形绿底 + 白色半身线稿。
 *  speaking 时嘴部切换到张口状态并加呼吸光环。零外部依赖。 */
export function TeacherAvatar({ speaking = false, size = 44 }: TeacherAvatarProps) {
  return (
    <span
      className={`dgb-avatar${speaking ? ' dgb-avatar--speaking' : ''}`}
      style={{ width: size, height: size }}
      aria-hidden
    >
      <svg viewBox="0 0 64 64" width={size} height={size}>
        <defs>
          <linearGradient id="dgb-av-bg" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor="#0E7C4A" />
            <stop offset="1" stopColor="#0A5132" />
          </linearGradient>
        </defs>
        <circle cx="32" cy="32" r="32" fill="url(#dgb-av-bg)" />
        {/* 头部 */}
        <circle cx="32" cy="24" r="9" fill="#fff" opacity="0.95" />
        {/* 耳麦 */}
        <path d="M22 22 q0 -8 10 -8 q10 0 10 8" stroke="#fff" strokeWidth="1.5" fill="none" opacity="0.8" />
        <rect x="41" y="22" width="2" height="4" rx="1" fill="#fff" opacity="0.9" />
        {/* 躯干 */}
        <path d="M14 56 q0 -13 18 -13 q18 0 18 13 v2 h-36 z" fill="#fff" opacity="0.92" />
        {/* 领口 V */}
        <path d="M26 44 l6 8 l6 -8" stroke="#0E7C4A" strokeWidth="2" fill="none" strokeLinejoin="round" />
        {/* 嘴巴：speaking 时椭圆（张口），默认横线（闭口） */}
        {speaking ? (
          <ellipse cx="32" cy="27" rx="1.6" ry="1.1" fill="#0A5132" className="dgb-avatar-mouth" />
        ) : (
          <rect x="30" y="26.4" width="4" height="1.2" rx="0.6" fill="#0A5132" />
        )}
      </svg>
    </span>
  );
}
