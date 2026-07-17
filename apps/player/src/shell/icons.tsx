/**
 * 专业 SVG 图标集 v2.0
 * 风格：Phosphor Icons 精简风格，1.6px 笔宽，Duotone 层次感
 * 规范：24×24 viewBox，stroke=currentColor，无硬编码色值
 */
import type { SVGProps } from 'react';

type IconProps = SVGProps<SVGSVGElement> & { size?: number };

function Base({ size = 20, children, ...rest }: IconProps & { children: React.ReactNode }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
      {...rest}
    >
      {children}
    </svg>
  );
}

/** 放大镜搜索 — 圆形镜片 + 精准手柄 */
export const IconSearch = (p: IconProps) => (
  <Base {...p}>
    <circle cx="10.5" cy="10.5" r="7" />
    <path d="M21 21l-4.35-4.35" strokeWidth="2" />
  </Base>
);

export const IconMenu = (p: IconProps) => (
  <Base {...p}>
    <path d="M3 6h18M3 12h18M3 18h18" />
  </Base>
);

/** 书本 — 双页打开，中缝清晰 */
export const IconBookOpen = (p: IconProps) => (
  <Base {...p}>
    <path d="M2 4h8a2 2 0 0 1 2 2v14a3 3 0 0 0-3-3H2Z" />
    <path d="M22 4h-8a2 2 0 0 0-2 2v14a3 3 0 0 1 3-3h7Z" />
    <path d="M12 6v14" strokeWidth="1" strokeDasharray="2 2" opacity=".4" />
  </Base>
);

/** 层叠页 — 课程主页入口 */
export const IconLayers = (p: IconProps) => (
  <Base {...p}>
    <path d="M2 7.5L12 3l10 4.5L12 12Z" />
    <path d="M2 12l10 4.5L22 12" opacity=".5" />
    <path d="M2 16.5L12 21l10-4.5" opacity=".3" />
  </Base>
);

/** 播放三角 — 填充风格 */
export const IconPlay = (p: IconProps) => (
  <Base {...p} strokeWidth="0">
    <path d="M6 4.5v15l13-7.5Z" fill="currentColor" />
  </Base>
);

/** 暂停 — 双竖条 */
export const IconPause = (p: IconProps) => (
  <Base {...p} strokeWidth="0">
    <rect x="5" y="4" width="4.5" height="16" rx="1.5" fill="currentColor" />
    <rect x="14.5" y="4" width="4.5" height="16" rx="1.5" fill="currentColor" />
  </Base>
);

/** 后退 — 竖线 + 三角 */
export const IconSkipBack = (p: IconProps) => (
  <Base {...p} strokeWidth="0">
    <path d="M18 4.5v15L7 12Z" fill="currentColor" />
    <rect x="5" y="4" width="3" height="16" rx="1" fill="currentColor" />
  </Base>
);

/** 前进 — 三角 + 竖线 */
export const IconSkipForward = (p: IconProps) => (
  <Base {...p} strokeWidth="0">
    <path d="M6 4.5v15l11-7.5Z" fill="currentColor" />
    <rect x="16" y="4" width="3" height="16" rx="1" fill="currentColor" />
  </Base>
);

/** 音量 — 喇叭 + 音波弧线 */
export const IconVolume = (p: IconProps) => (
  <Base {...p}>
    <path d="M4 9.5H7.5L12 5.5v13l-4.5-4H4Z" fill="currentColor" fillOpacity=".15" />
    <path d="M15.5 8.5a5 5 0 0 1 0 7" />
    <path d="M18 6a8.5 8.5 0 0 1 0 12" opacity=".45" />
  </Base>
);

/** 右指箭头/折叠展开 */
export const IconChevron = (p: IconProps) => (
  <Base {...p}><path d="m9 18 6-6-6-6" /></Base>
);
export const IconChevronDown = (p: IconProps) => (
  <Base {...p}><path d="m6 9 6 6 6-6" /></Base>
);

/** 文件夹 — 圆角，双层感 */
export const IconFolder = (p: IconProps) => (
  <Base {...p}>
    <path d="M4 5h6l2 2.5H20a1 1 0 0 1 1 1V19a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1Z" fill="currentColor" fillOpacity=".08" />
    <path d="M3 10h18" opacity=".35" />
  </Base>
);

/** 发送 — 精准纸飞机风格 */
export const IconSend = (p: IconProps) => (
  <Base {...p}>
    <path d="M22 2L11 13" />
    <path d="M22 2L15 22l-4-9-9-4Z" fill="currentColor" fillOpacity=".12" />
  </Base>
);

/** 勾选圆圈 — 完成状态 */
export const IconCheckCircle = (p: IconProps) => (
  <Base {...p}>
    <circle cx="12" cy="12" r="9" fill="currentColor" fillOpacity=".08" />
    <path d="M8 12l3 3 5-6" strokeWidth="2" />
  </Base>
);

/** 显示器/全屏 — 专注模式 */
export const IconMonitor = (p: IconProps) => (
  <Base {...p}>
    <rect x="2" y="3" width="20" height="15" rx="2" fill="currentColor" fillOpacity=".08" />
    <path d="M8 22h8M12 18v4" />
    <path d="M7 10.5h10M7 13.5h6" opacity=".4" />
  </Base>
);

/** 微芯片 — 嵌入式专业感 */
export const IconChip = (p: IconProps) => (
  <Base {...p}>
    <rect x="7" y="7" width="10" height="10" rx="2" fill="currentColor" fillOpacity=".12" />
    <path d="M10 4v3M14 4v3M10 17v3M14 17v3M4 10h3M4 14h3M17 10h3M17 14h3" />
  </Base>
);

/** 电路板图案 — SideNav 分类用 */
export const IconCircuit = (p: IconProps) => (
  <Base {...p}>
    <path d="M4 6h4M12 6h4M18 6h2" opacity=".4" />
    <path d="M4 12h2M8 12h8M18 12h2" />
    <path d="M4 18h4M12 18h4M18 18h2" opacity=".4" />
    <circle cx="8" cy="12" r="1.5" fill="currentColor" />
    <circle cx="16" cy="12" r="1.5" fill="currentColor" />
  </Base>
);

/** 目标/靶心 — 学习目标 */
export const IconTarget = (p: IconProps) => (
  <Base {...p}>
    <circle cx="12" cy="12" r="9" opacity=".2" fill="currentColor" />
    <circle cx="12" cy="12" r="5.5" opacity=".35" fill="currentColor" stroke="none" />
    <circle cx="12" cy="12" r="2.5" fill="currentColor" stroke="none" />
  </Base>
);

/** 闪电/快速 — 互动区标志 */
export const IconZap = (p: IconProps) => (
  <Base {...p}>
    <path d="M13.5 2L4 13h7.5L10.5 22l9.5-11H12.5Z" fill="currentColor" fillOpacity=".12" />
    <path d="M13.5 2L4 13h7.5L10.5 22l9.5-11H12.5Z" />
  </Base>
);

/** 复制 */
export const IconCopy = (p: IconProps) => (
  <Base {...p}>
    <rect x="9" y="9" width="12" height="12" rx="2" fill="currentColor" fillOpacity=".08" />
    <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
  </Base>
);

/** 保留旧接口兼容 */
export const IconBot = IconChip;
export const IconSparkles = IconZap;
export const IconNote = IconCopy;
export const IconStar = IconTarget;
export const IconSettings = (p: IconProps) => (
  <Base {...p}>
    <circle cx="12" cy="12" r="3.5" />
    <path d="M12 1v4M12 19v4M4.22 4.22l2.83 2.83M16.95 16.95l2.83 2.83M1 12h4M19 12h4M4.22 19.78l2.83-2.83M16.95 7.05l2.83-2.83" />
  </Base>
);
export const IconBook = IconBookOpen;
export const IconUser = (p: IconProps) => (
  <Base {...p}>
    <circle cx="12" cy="8" r="4" fill="currentColor" fillOpacity=".12" />
    <path d="M4 20c0-4 3.6-7 8-7s8 3 8 7" />
  </Base>
);
export const IconBell = (p: IconProps) => (
  <Base {...p}>
    <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" fill="currentColor" fillOpacity=".1" />
    <path d="M13.73 21a2 2 0 0 1-3.46 0" />
  </Base>
);
export const IconHome = (p: IconProps) => (
  <Base {...p}>
    <path d="M3 9.5L12 3l9 6.5V20a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1Z" fill="currentColor" fillOpacity=".08" />
    <path d="M9 21V12h6v9" />
  </Base>
);
export const IconMessage = (p: IconProps) => (
  <Base {...p}>
    <path d="M21 11.5a8.5 8.5 0 1 1-17 0 8.5 8.5 0 0 1 17 0Z" fill="currentColor" fillOpacity=".08" />
    <path d="M3.5 19.5L5 15.5" />
  </Base>
);
export const IconBarChart = (p: IconProps) => (
  <Base {...p}>
    <path d="M12 20V10M18 20V4M6 20v-4" strokeWidth="3" strokeLinecap="round" />
  </Base>
);
export const IconAward = (p: IconProps) => (
  <Base {...p}>
    <circle cx="12" cy="8.5" r="6" fill="currentColor" fillOpacity=".1" />
    <path d="M8.5 14.5 7 23l5-3 5 3-1.5-8.5" />
  </Base>
);
export const IconClock = (p: IconProps) => (
  <Base {...p}>
    <circle cx="12" cy="12" r="9" fill="currentColor" fillOpacity=".08" />
    <path d="M12 7v5l3 2" />
  </Base>
);
export const IconFilm = IconMonitor;
export const IconList = (p: IconProps) => (
  <Base {...p}>
    <path d="M9 6h12M9 12h12M9 18h12" />
    <circle cx="4" cy="6" r="1.5" fill="currentColor" stroke="none" />
    <circle cx="4" cy="12" r="1.5" fill="currentColor" stroke="none" />
    <circle cx="4" cy="18" r="1.5" fill="currentColor" stroke="none" />
  </Base>
);
export const IconGrid = (p: IconProps) => (
  <Base {...p}>
    <rect x="3" y="3" width="7.5" height="7.5" rx="1.5" fill="currentColor" fillOpacity=".12" />
    <rect x="13.5" y="3" width="7.5" height="7.5" rx="1.5" fill="currentColor" fillOpacity=".12" />
    <rect x="13.5" y="13.5" width="7.5" height="7.5" rx="1.5" fill="currentColor" fillOpacity=".12" />
    <rect x="3" y="13.5" width="7.5" height="7.5" rx="1.5" fill="currentColor" fillOpacity=".12" />
  </Base>
);
export const IconTrendingUp = (p: IconProps) => (
  <Base {...p}>
    <polyline points="22 7 13 16 9 12 2 19" />
    <polyline points="16 7 22 7 22 13" />
  </Base>
);
export const IconFlag = (p: IconProps) => (
  <Base {...p}>
    <path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1Z" fill="currentColor" fillOpacity=".1" />
    <line x1="4" y1="22" x2="4" y2="15" />
  </Base>
);
export const IconMoreHorizontal = (p: IconProps) => (
  <Base {...p}>
    <circle cx="5" cy="12" r="1.5" fill="currentColor" stroke="none" />
    <circle cx="12" cy="12" r="1.5" fill="currentColor" stroke="none" />
    <circle cx="19" cy="12" r="1.5" fill="currentColor" stroke="none" />
  </Base>
);
export const IconLock = (p: IconProps) => (
  <Base {...p}>
    <rect x="3" y="11" width="18" height="11" rx="2" fill="currentColor" fillOpacity=".08" />
    <path d="M7 11V7a5 5 0 0 1 10 0v4" />
  </Base>
);
/** T-17-A · 停止（圆角方块） */
export const IconStop = (p: IconProps) => (
  <Base {...p}>
    <rect x="6" y="6" width="12" height="12" rx="2" fill="currentColor" fillOpacity=".15" />
    <rect x="6" y="6" width="12" height="12" rx="2" />
  </Base>
);

