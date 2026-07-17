/**
 * apps/player/e2e/screenshot-evidence.spec.ts
 *
 * 仿 AI培训项目 local-screenshot-evidence.md 方法论：每个关键场景留 1 张截图证据，
 * 配合 e2e/local-screenshot-evidence.md 作为可读 catalog。
 *
 * 与 iter40-features.spec.ts 的边界：
 *   - iter40-features：功能断言（locator 存在 / count > 0 / URL 变化等强校验）
 *   - 本文件：纯视觉证据采集（waitFor 后 screenshot），断言只到"页面没崩"
 *
 * 跑：
 *   pnpm --filter @dgbook/player e2e -- screenshot-evidence
 *
 * 输出位置：apps/player/e2e/screenshots/iter40-evidence/
 */
import { test, type Page } from '@playwright/test';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DIR = path.join(__dirname, 'screenshots', 'iter40-evidence');

/** 通用：进 page，等关键 selector，再快门 */
async function snap(
  page: Page,
  baseURL: string | undefined,
  pageId: string,
  filename: string,
  options: { fullPage?: boolean; waitFor?: string } = {},
) {
  const url = pageId === 'home' ? (baseURL || '/') : `${baseURL}?page=${pageId}`;
  await page.goto(url, { waitUntil: 'load' });
  await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
  if (options.waitFor) {
    await page.waitForSelector(options.waitFor, { timeout: 10000 }).catch(() => {});
  }
  await page.waitForTimeout(600);
  await page.screenshot({
    path: path.join(DIR, filename),
    fullPage: options.fullPage ?? false,
  });
}

test.describe('Iter-40 截图证据 · 主路径快照', () => {
  test('01 课程首页全屏（Shell 三栏 + 底部播放条）', async ({ page, baseURL }) => {
    await snap(page, baseURL, 'home', '01-shell-home-fullscreen.png', {
      fullPage: false,
    });
  });

  test('02 ch3 LED 页主区（Wokwi 三件套就位）', async ({ page, baseURL }) => {
    await snap(page, baseURL, 'p3-led-blink', '02-ch3-led-mainview.png', {
      waitFor: '[data-wokwi-kind="led"]',
    });
  });

  test('03 Wokwi LED 元件特写（红色阳极 PA5）', async ({ page, baseURL }) => {
    await page.goto(`${baseURL}?page=p3-led-blink`, { waitUntil: 'load' });
    await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
    await page.waitForSelector('[data-wokwi-kind="led"]', { timeout: 15000 }).catch(() => {});
    await page.waitForTimeout(1200);
    const led = page.locator('[data-wokwi-kind="led"]').first();
    // RALPH 修复：waitFor 元素 visible（实际 inline-flex span 在画面内）+ box 非零再快门
    await led.waitFor({ state: 'visible', timeout: 5000 }).catch(() => {});
    await led.scrollIntoViewIfNeeded();
    await page.waitForTimeout(300);
    // 截 LED 父级 figure 而非 inline span 本身（确保有合理尺寸）
    const figure = page.locator('.dgb-wokwi-block').first();
    await figure.screenshot({ path: path.join(DIR, '03-wokwi-led-closeup.png') });
  });

  test('04 Wokwi 220Ω 电阻特写（4 色环：红红棕金）', async ({ page, baseURL }) => {
    await page.goto(`${baseURL}?page=p3-led-blink`, { waitUntil: 'load' });
    await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
    await page.waitForSelector('[data-wokwi-kind="resistor"]', { timeout: 15000 }).catch(() => {});
    await page.waitForTimeout(1200);
    const r = page.locator('[data-wokwi-kind="resistor"]').first();
    await r.waitFor({ state: 'visible', timeout: 5000 }).catch(() => {});
    await r.scrollIntoViewIfNeeded();
    await page.waitForTimeout(300);
    // 截父级 figure（dgb-wokwi-block 第二个）
    const figure = page.locator('.dgb-wokwi-block').nth(1);
    await figure.screenshot({ path: path.join(DIR, '04-wokwi-resistor-closeup.png') });
  });

  test('05 底部讲师播放条（aiTutor.subtitle 双行版式）', async ({ page, baseURL }) => {
    await page.goto(baseURL || '/', { waitUntil: 'load' });
    await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
    await page.waitForTimeout(1000);
    // 截屏底部 1/4（含播放条）
    const vh = page.viewportSize()?.height ?? 864;
    const vw = page.viewportSize()?.width ?? 1536;
    await page.screenshot({
      path: path.join(DIR, '05-teacher-audiobar-bottom.png'),
      clip: { x: 0, y: vh - 200, width: vw, height: 200 },
    });
  });

  test('06 多课节 ch1 概念页（首页）', async ({ page, baseURL }) => {
    await snap(page, baseURL, 'p1-concept', '06-ch1-concept.png', { fullPage: false });
  });

  test('07 多课节 ch7-adc 页（含 fsm 模板动画）', async ({ page, baseURL }) => {
    await snap(page, baseURL, 'p7-adc', '07-ch7-adc.png', { fullPage: false });
  });

  test('08 多课节 ch10-parking 综合页', async ({ page, baseURL }) => {
    await snap(page, baseURL, 'p10-parking', '08-ch10-parking.png', { fullPage: false });
  });

  test('09 finale-challenge 全屏挑战入口（截 button 区）', async ({ page, baseURL }) => {
    await page.goto(`${baseURL}?page=p3-led-blink`, { waitUntil: 'load' });
    await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
    await page.waitForTimeout(1000);
    // 滚到底部找 finale-challenge button
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(500);
    await page.screenshot({
      path: path.join(DIR, '09-finale-challenge-entry.png'),
      fullPage: false,
    });
  });

  test('10 LED 页全长截图（fullPage 含所有 block 顺序）', async ({ page, baseURL }) => {
    await snap(page, baseURL, 'p3-led-blink', '10-ch3-led-fullpage.png', {
      fullPage: true,
      waitFor: '[data-wokwi-kind="led"]',
    });
  });
});

test.describe('Iter-40 截图证据 · 学生交互快照', () => {
  test('11 Space 按下后 UI 状态（图标变化）', async ({ page, baseURL }) => {
    await page.goto(`${baseURL}?page=p3-led-blink`, { waitUntil: 'load' });
    await page.waitForTimeout(1500);
    await page.keyboard.press('Space');
    await page.waitForTimeout(500);
    await page.screenshot({
      path: path.join(DIR, '11-after-space-press.png'),
      fullPage: false,
    });
  });

  test('12 ArrowRight 后 URL 切换到下一课节', async ({ page, baseURL }) => {
    await page.goto(`${baseURL}?page=p3-led-blink`, { waitUntil: 'load' });
    await page.waitForTimeout(1500);
    await page.keyboard.press('ArrowRight');
    await page.waitForTimeout(800);
    await page.screenshot({
      path: path.join(DIR, '12-after-arrow-right.png'),
      fullPage: false,
    });
  });

  // 大屏教室 1920×1080 保留——这是教师投影场景，与移动端学习不同语境

  test('13 桌面大屏 1920x1080（教室投影场景）', async ({ page, baseURL }) => {
    await page.setViewportSize({ width: 1920, height: 1080 });
    await snap(page, baseURL, 'p3-led-blink', '13-desktop-1920.png', {
      fullPage: false,
    });
  });
});
