/**
 * apps/player/playwright.config.ts
 *
 * Playwright 全量 e2e 测试配置（@playwright/test 1.60+）。
 * - testDir: ./e2e
 * - 默认 BASE_URL: http://124.220.234.157/（线上）
 * - 也可以本地：BASE_URL=http://127.0.0.1:8765/ 跑 dist-offline
 * - reporter: list（控制台）+ html（CI 浏览）
 * - retries: 2（线上偶发 502 / 网络抖动容忍）
 * - workers: 4（并行加速 17 页 smoke）
 *
 * 使用：
 *   pnpm --filter @dgbook/player e2e         # 默认线上
 *   pnpm --filter @dgbook/player e2e:ui      # 交互式调试
 *   BASE_URL=http://127.0.0.1:8765/ pnpm --filter @dgbook/player e2e
 *
 * 与现有 scripts/_iter27_smoke_full.mjs 关系：
 * - 现有脚本是基于 chromium.launch() 直接调用的轻量 smoke（17 页 console.error / pageerror）
 * - 本配置是正式 e2e 测试框架（test/expect/retry/report 全套）
 * - Iter-33+ 逐步把 _iter27_smoke 行为迁到 e2e/*.spec.ts
 */
import { defineConfig, devices } from '@playwright/test';

const BASE_URL = process.env.BASE_URL || 'http://124.220.234.157/';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 1,
  workers: process.env.CI ? 4 : 4,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : [['list']],
  timeout: 30_000,

  use: {
    baseURL: BASE_URL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    // 真实用户视口
    viewport: { width: 1536, height: 864 },
    // 默认 locale 与站点一致
    locale: 'zh-CN',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    // 后续 Iter-34+ 可按需打开 firefox / webkit
  ],
});
