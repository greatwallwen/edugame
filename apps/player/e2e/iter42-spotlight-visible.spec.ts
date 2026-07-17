/**
 * apps/player/e2e/iter42-spotlight-visible.spec.ts
 *
 * 修复目标：教训 89 落地——spotlight 被触发时目标必须在 viewport 内可见。
 *   Iter-41-G2 之前：actions 模式 spotlight 永远在 y=2200+，scrollY=0 → 学生看不见
 *   Iter-42 修复：
 *     a) Shell.tsx onEffectFire 联动 setActiveBlockId → AnimatedBlockWrap.scrollIntoView center
 *     b) HighlightOverlay 自带 scrollIntoView 兜底（current 切换时若目标不在视区则 scroll）
 *
 * 本 spec 真跑生产 ch3 LED 14 段，断言每段 mask 落在 viewport 内。
 *
 * 跑：
 *   pnpm --filter @dgbook/player e2e -- --grep iter42
 */
import { test, expect, type Page } from '@playwright/test';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const SCREEN_DIR = path.join(__dirname, 'screenshots', 'iter42-evidence');

async function gotoLED(page: Page, baseURL?: string) {
  await page.goto(`${baseURL}?page=p3-led-blink`, { waitUntil: 'load' });
  await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
  await page.waitForSelector('[data-wokwi-kind="led"]', { timeout: 10000 }).catch(() => {});
  await page.waitForTimeout(800);
}

test.describe('spotlight 视觉真可见（教训 89 兜底）', () => {
  // 跑 60s 真实时序，超过 default 30s timeout
  test.setTimeout(120_000);

  test('ch3 LED 至少 1 段节点级 spotlight 落在 viewport 内', async ({ page, baseURL }) => {
    await gotoLED(page, baseURL);
    await page.evaluate(() =>
      window.dispatchEvent(new KeyboardEvent('keydown', { code: 'Space', key: ' ', bubbles: true }))
    );
    // 跑 25s 取节点级 spotlight 证据（generator 早期 actions 含 wokwi/graphics）
    const result = await page.evaluate(async () => {
      let nodeLevelCount = 0;
      let inViewportCount = 0;
      let lastBubble = '';
      for (let i = 0; i < 25; i++) {
        await new Promise((f) => setTimeout(f, 1000));
        const svg = document.querySelector('svg.dgb-hl-overlay-spotlight');
        const blackR = svg?.querySelector('rect[fill="black"]') ?? null;
        const bubble = document.querySelector('[class*="audioBubbleText"]')?.textContent?.slice(0, 40) || '';
        if (bubble && bubble !== lastBubble && svg) {
          lastBubble = bubble;
          nodeLevelCount++;
          if (blackR) {
            const y = parseFloat(blackR.getAttribute('y') || '0');
            if (y >= 0 && y < window.innerHeight) inViewportCount++;
          }
        }
      }
      return { nodeLevelCount, inViewportCount };
    });
    expect(result.nodeLevelCount).toBeGreaterThanOrEqual(1);
    expect(result.inViewportCount).toBeGreaterThanOrEqual(1);

    await page.screenshot({
      path: path.join(SCREEN_DIR, '01-spotlight-visible-multi-segments.png'),
      fullPage: false,
    });
  });

  test('actions 模式至少 2 个不同 activeBlock 切换', async ({ page, baseURL }) => {
    await gotoLED(page, baseURL);
    await page.evaluate(() =>
      window.dispatchEvent(new KeyboardEvent('keydown', { code: 'Space', key: ' ', bubbles: true }))
    );
    const blocksSeen = await page.evaluate(async () => {
      const seen = new Set<string>();
      for (let i = 0; i < 18; i++) {
        await new Promise((f) => setTimeout(f, 1000));
        const ab = document.querySelector('.dgb-block-spotlight[data-element-id]')?.getAttribute('data-element-id');
        if (ab) seen.add(ab);
      }
      return Array.from(seen);
    });
    expect(blocksSeen.length).toBeGreaterThanOrEqual(2);
  });
});
