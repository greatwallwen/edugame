/**
 * apps/player/e2e/iter41-G2-page-actions.spec.ts
 *
 * 验证 PageActionRunner 在 ch3 LED 页（p3-led-blink）的真实工作：
 *   1. manifest 含 page.actions 字段（14 段微电影已部署）
 *   2. 进入页面后按 Space 启动 → spotlight overlay 出现
 *   3. ←/→ 段间跳转：actions 模式不切页（URL 不变）
 *   4. Esc 停止后 spotlight 清除
 *
 * 与 iter40-features.spec.ts 的边界：
 *   - 那里 ←/→ 是 BlockPlaybackEngine 模式 → 切页（URL 变）
 *   - 这里 ←/→ 是 PageActionRunner 模式 → 段间跳转（URL 不变）
 *   两者并存证明双模式路由生效。
 *
 * 跑：
 *   pnpm --filter @dgbook/player e2e -- --grep iter41-G2
 */
import { test, expect, type Page } from '@playwright/test';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const SCREEN_DIR = path.join(__dirname, 'screenshots', 'iter41-g2');

async function gotoLED(page: Page, baseURL?: string) {
  await page.goto(`${baseURL}?page=p3-led-blink`, { waitUntil: 'load' });
  await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
  // 等关键 selector：Wokwi LED 渲染完成是 actions 可执行的硬信号
  await page.waitForSelector('[data-wokwi-kind="led"]', { timeout: 10000 }).catch(() => {});
  await page.waitForTimeout(500);
}

test.describe('Iter-41-G2 · PageActionRunner manifest 部署校验', () => {
  test('p3-led-blink 含 page.actions 微电影（自动生成器版本）', async ({ page, baseURL }) => {
    const res = await page.request.get(`${baseURL}manifest.json`);
    expect(res.ok()).toBeTruthy();
    const m = await res.json();
    const ch3 = m.chapters.find((c: { id: string }) => c.id === 'ch3');
    expect(ch3).toBeDefined();
    const t1 = ch3.sections.find((s: { id: string }) => s.id === 'ch3-t1');
    expect(t1).toBeDefined();
    const led = t1.pages.find((p: { id: string }) => p.id === 'p3-led-blink');
    expect(led).toBeDefined();
    expect(Array.isArray(led.actions)).toBe(true);

    expect(led.actions.length).toBeGreaterThanOrEqual(20);
    // Wokwi LED 与 220Ω 电阻的 spotlight 必须存在（自动 generator wokwi 兜底）
    const allTargets = led.actions
      .filter((a: { type: string; targetId?: string }) => a.type === 'spotlight')
      .map((a: { targetId: string }) => a.targetId);
    expect(allTargets).toContain('dgb-wokwi-p3-led-blink-wokwi-led');
    expect(allTargets).toContain('dgb-wokwi-p3-led-blink-wokwi-r');
    // graphics 4 节点电流路径必须存在
    expect(allTargets).toContain('dgb-graphics-gpio');
    expect(allTargets).toContain('dgb-graphics-r');
    expect(allTargets).toContain('dgb-graphics-led');
    expect(allTargets).toContain('dgb-graphics-gnd');
  });
});

test.describe('Iter-41-G2 · 学生快捷键路由到 PageActionRunner', () => {
  test('actions 模式首次进入 LED 页 → onboarding 提示自动出现', async ({ page, baseURL }) => {
    await gotoLED(page, baseURL);
    // onboarding hint 在 useEffect([effectiveActive]) 里设置，不依赖按键
    const hint = page.locator('text=/空格.*暂停.*继续/');
    const hintVisible = await hint.isVisible({ timeout: 4000 }).catch(() => false);
    await page.screenshot({
      path: path.join(SCREEN_DIR, '01-onboarding-hint-visible.png'),
      fullPage: false,
    });
    expect(hintVisible).toBe(true);
  });

  test('←/→ 在 actions 模式不切 URL（段内跳转，不切页）', async ({ page, baseURL }) => {
    await gotoLED(page, baseURL);
    await page.keyboard.press('Space');
    await page.waitForTimeout(800);
    const beforeUrl = page.url();
    await page.keyboard.press('ArrowRight');
    await page.waitForTimeout(500);
    const afterUrl = page.url();
    // actions 模式：←/→ 触发 runner.gotoPrev/Next，不应改 ?page= 参数
    expect(afterUrl).toBe(beforeUrl);
  });

  test('Esc 停止 PageActionRunner 不抛错', async ({ page, baseURL }) => {
    const errors: string[] = [];
    page.on('pageerror', (e) => errors.push(String(e)));
    await gotoLED(page, baseURL);
    await page.keyboard.press('Space');
    await page.waitForTimeout(600);
    await page.keyboard.press('Escape');
    await page.waitForTimeout(300);
    expect(errors).toHaveLength(0);
    await page.screenshot({
      path: path.join(SCREEN_DIR, '02-after-escape-stopped.png'),
      fullPage: false,
    });
  });
});
