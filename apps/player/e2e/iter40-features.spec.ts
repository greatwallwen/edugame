/**
 * apps/player/e2e/iter40-features.spec.ts
 *
 * 覆盖 Iter-40 三大产物在生产环境的真实表现：
 *   1. Iter-40-D: Wokwi 三件套（LED + 220Ω resistor）在 ch3 LED 页可见
 *   2. Iter-40-E: 视觉收敛（讲师角色 / callout subtitle / 横向编号卡）
 *   3. Iter-40-G: 学生交互快捷键（Space / ←→ / Esc）
 *
 * 设计原则（仿 AI 培训项目 Playwright 取证方法论 local-screenshot-evidence.md）：
 *   - 每个用例 1 张截图证据存到 e2e/screenshots/iter40-features/
 *   - 失败时自动 trace + screenshot（playwright.config 已配置）
 *   - 跑生产 URL（http://124.220.234.157/）真实验证云端部署
 *
 * 跑：
 *   pnpm --filter @dgbook/player e2e -- --grep iter40-features
 */
import { test, expect, type Page } from '@playwright/test';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// ESM 下 __dirname 不可用，从 import.meta.url 解析
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const SCREEN_DIR = path.join(__dirname, 'screenshots', 'iter40-features');

async function gotoLED(page: Page, baseURL?: string) {
  await page.goto(`${baseURL}?page=p3-led-blink`, { waitUntil: 'load' });
  // RALPH 迭代 2：networkidle 8s 偶发不够 → 改 15s + 等待 wokwi 块出现作为关键路径信号
  await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
  // 关键 selector 等待：data-wokwi-kind 是 LED 渲染完成的硬信号，比 timeout 更可靠
  await page.waitForSelector('[data-wokwi-kind="led"]', { timeout: 10000 }).catch(() => {});
  await page.waitForTimeout(400);
}

test.describe('Iter-40-D · Wokwi 三件套生产可见性', () => {
  test('p3-led-blink 渲染 Wokwi LED + 220Ω 电阻', async ({ page, baseURL }) => {
    await gotoLED(page, baseURL);
    // LED block：data-wokwi-kind="led" 是 WokwiLED 组件的硬协议
    const leds = await page.locator('[data-wokwi-kind="led"]').count();
    const resistors = await page.locator('[data-wokwi-kind="resistor"]').count();
    expect(leds).toBeGreaterThanOrEqual(1);
    expect(resistors).toBeGreaterThanOrEqual(1);

    await page.screenshot({
      path: path.join(SCREEN_DIR, '01-wokwi-led-resistor-rendered.png'),
      fullPage: false,
    });
  });

  test('Wokwi LED 阳极标签 PA5 出现', async ({ page, baseURL }) => {
    await gotoLED(page, baseURL);
    // WokwiLED label='PA5' 渲染为 .led-label 文字
    const ledLabel = page.locator('text=PA5').first();
    await expect(ledLabel).toBeVisible();
  });

  test('Wokwi block caption 含限流电阻说明', async ({ page, baseURL }) => {
    await gotoLED(page, baseURL);
    // 220Ω 限流电阻 caption 文字应在页面上
    const caption = page.locator('text=/220.*限流/i').first();
    await expect(caption).toBeVisible();
  });
});

test.describe('Iter-40-E · 视觉收敛对齐 5G 截图', () => {
  test('底部播放条讲师角色行渲染（aiTutor.subtitle 数据驱动）', async ({ page, baseURL }) => {
    await page.goto(baseURL || '/', { waitUntil: 'load' });
    await page.waitForTimeout(800);
    // aiTutor.subtitle = "随堂问答 · 课堂伙伴"（教训 81：grep schema 发现的字段）
    const role = page.locator('text=/随堂问答|课堂伙伴|讲师/').first();
    await expect(role).toBeVisible();

    await page.screenshot({
      path: path.join(SCREEN_DIR, '02-teacher-role-bottom-bar.png'),
    });
  });

  test('Wokwi block 不再带米黄渐变（视觉收敛）', async ({ page, baseURL }) => {
    await gotoLED(page, baseURL);
    // .dgb-wokwi-block 应是白底（var(--dg-color-surface-card)），不是 linear-gradient
    const wokwi = page.locator('.dgb-wokwi-block').first();
    await expect(wokwi).toBeVisible();
    const bg = await wokwi.evaluate((el) => getComputedStyle(el).backgroundColor);
    // 白底 rgb(255,255,255) 或 var fallback；不应包含 'gradient' 关键字
    const bgImage = await wokwi.evaluate((el) => getComputedStyle(el).backgroundImage);
    expect(bgImage).toBe('none');
    // 背景色应该是白色或近白
    expect(bg).toMatch(/rgb\(2[45][0-9],\s*2[45][0-9],\s*2[45][0-9]\)|rgba?\(255/);
  });
});

test.describe('Iter-40-G · 学生快捷键 Space 暂停继续', () => {
  test('Space 在生产页面不抛错且不被浏览器吞', async ({ page, baseURL }) => {
    const errors: string[] = [];
    page.on('pageerror', (e) => errors.push(String(e)));
    await gotoLED(page, baseURL);

    // 按 Space 触发 pause/resume；如果没绑定监听，浏览器默认会下滚页面 1 屏；
    // 我们的实现 e.preventDefault()，所以 scrollY 应保持
    const beforeScrollY = await page.evaluate(() => window.scrollY);
    await page.keyboard.press('Space');
    await page.waitForTimeout(200);
    const afterScrollY = await page.evaluate(() => window.scrollY);
    // Space 的 preventDefault 让页面不滚动
    expect(Math.abs(afterScrollY - beforeScrollY)).toBeLessThan(50);
    // 没有 page error
    expect(errors, `pageerrors: ${errors.join('\n')}`).toHaveLength(0);
  });

  test('ArrowRight 在 actions 模式下不切 URL（全课已 PageActionRunner 化）', async ({ page, baseURL }) => {

    // ←/→ 改走 PageActionRunner.gotoPrev/gotoNext 段内跳转，URL 不变。
    // BlockPlaybackEngine 路径仅作 widget teacherActions 兜底，不再驱动主播报。
    await page.goto(`${baseURL}?page=p1-concept`, { waitUntil: 'load' });
    await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
    await page.waitForTimeout(800);
    const initialUrl = page.url();

    await page.keyboard.press('ArrowRight');
    await page.waitForTimeout(500);
    const afterRight = page.url();
    // actions 模式：URL 不变（行为反转 vs Iter-41-G2 之前）
    expect(afterRight).toBe(initialUrl);

    await page.screenshot({
      path: path.join(SCREEN_DIR, '03-keyboard-arrow-right-segment-step.png'),
    });
  });

  test('Escape 在播放中不抛错（idle 时被 guard 跳过）', async ({ page, baseURL }) => {
    const errors: string[] = [];
    page.on('pageerror', (e) => errors.push(String(e)));
    await gotoLED(page, baseURL);
    await page.keyboard.press('Escape');
    await page.waitForTimeout(300);
    expect(errors).toHaveLength(0);
  });

  test('在输入框中按 Space 不触发 pause（避免误触）', async ({ page, baseURL }) => {
    await gotoLED(page, baseURL);
    // 找一个 input 或 textarea；如果没有，跳过测试
    const input = page.locator('input[type="text"], textarea').first();
    const exists = await input.count();
    if (exists === 0) {
      test.skip();
      return;
    }
    await input.click();
    const beforeText = await input.inputValue().catch(() => '');
    await input.type('hello', { delay: 50 });
    await page.keyboard.press('Space');
    const afterText = await input.inputValue();
    // 输入框收到了空格，没被 pause 拦截
    expect(afterText).toContain(' ');
    expect(afterText.length).toBeGreaterThan(beforeText.length);
  });
});

test.describe('Iter-40 部署生产健康度', () => {
  test('manifest 仍然 200 OK 且非空', async ({ page, baseURL }) => {
    const res = await page.request.get(`${baseURL}manifest.json`);
    expect(res.ok()).toBeTruthy();
    const m = await res.json();
    expect(m.manifestVersion).toBeGreaterThanOrEqual(4);
    expect(Array.isArray(m.chapters)).toBe(true);
    expect(m.chapters.length).toBeGreaterThan(0);
  });

  test('manifest 含 wokwi-element block（Iter-40-D 已部署）', async ({ page, baseURL }) => {
    const res = await page.request.get(`${baseURL}manifest.json`);
    const m = await res.json();
    let wokwiCount = 0;
    for (const ch of m.chapters || []) {
      for (const s of ch.sections || []) {
        for (const p of s.pages || []) {
          for (const b of p.blocks || []) {
            if (b.kind === 'wokwi-element') wokwiCount++;
          }
        }
      }
    }
    // 至少 1 个（ch3 LED 页注入了 LED + 电阻 = 2 个）
    expect(wokwiCount).toBeGreaterThanOrEqual(1);
  });
});
