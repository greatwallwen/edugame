/**
 * 设计 Token（DRY 原则：所有颜色/尺寸/字体只在此处定义）
 * 违反此处硬编码的 PR 将被拒。
 */

export const colors = {
  brand: {
    50: '#EFF4FF',
    100: '#E6EEFF',
    500: '#4F7DFF',
    600: '#3A63E8',
    700: '#2A4EC9',
  },
  node: {
    purple: '#7A6BFF',
    blue: '#4F7DFF',
    green: '#45D4B0',
  },
  surface: {
    base: '#F7F9FC',
    card: '#FFFFFF',
    muted: '#F1F5F9',
    border: '#E2E8F0',
  },
  text: {
    primary: '#1A1A2E',
    secondary: '#475569',
    tertiary: '#94A3B8',
    inverse: '#FFFFFF',
  },
  state: {
    success: '#10B981',
    warning: '#F59E0B',
    danger: '#EF4444',
    info: '#6366F1',
  },
} as const;

export const fonts = {
  sans: "'PingFang SC','Source Han Sans SC','Microsoft YaHei',sans-serif",
  mono: "'JetBrains Mono','Fira Code',Consolas,monospace",
} as const;

export const layout = {
  shell: {
    topBarHeight: 44,
    sideNavWidth: 240,
    rightToolbarWidth: 48,
    audioBarHeight: 56,
  },
} as const;
