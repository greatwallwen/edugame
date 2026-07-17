/**
 * apps/player/e2e/iter41-B-bit-flip-extend.spec.ts
 *
 * 验证 ch4-ch7 bit-flip 题部署：
 *   1. manifest 含 5 道 bit-flip（p3-led-bitflip + 4 道扩展）
 *   2. 每道题 target / initial 在 0-255 范围（schema 限制）
 *   3. 每道题 bitLabels 长度恰好 8
 *   4. 进入 p4-timer 页面后 BitFlip primitive 实际渲染
 *
 * 跑：
 *   pnpm --filter @dgbook/player e2e -- --grep iter41-B
 */
import { test, expect, type Page } from '@playwright/test';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const SCREEN_DIR = path.join(__dirname, 'screenshots', 'iter41-b');

type ManifestPage = { id: string; blocks: Array<Record<string, unknown>> };

function findPage(manifest: { chapters: Array<{ sections: Array<{ pages: ManifestPage[] }> }> }, pageId: string): ManifestPage | null {
  for (const ch of manifest.chapters) {
    for (const sec of ch.sections) {
      for (const p of sec.pages) {
        if (p.id === pageId) return p;
      }
    }
  }
  return null;
}

const EXPECTED_BIT_FLIPS = [
  { page: 'p3-led-blink', blockId: 'p3-led-bitflip', target: 0x20 },
  { page: 'p4-timer', blockId: 'p4-timer-bitflip', target: 0x01 },
  { page: 'p5-pwm', blockId: 'p5-pwm-bitflip', target: 0x60 },
  { page: 'p6-uart-it', blockId: 'p6-uart-it-bitflip', target: 0x20 },
  { page: 'p7-adc', blockId: 'p7-adc-bitflip', target: 0x03 },
];

test.describe('Iter-41-B · bit-flip 题库 5 道全量校验', () => {
  test('manifest 含 5 道 bit-flip（schema-valid）', async ({ page, baseURL }) => {
    const res = await page.request.get(`${baseURL}manifest.json`);
    expect(res.ok()).toBeTruthy();
    const m = await res.json();

    for (const exp of EXPECTED_BIT_FLIPS) {
      const p = findPage(m, exp.page);
      expect(p, `page ${exp.page} 必须存在`).not.toBeNull();
      const block = p!.blocks.find((b) => b.id === exp.blockId) as
        | { kind?: string; spec?: { kind?: string; initial?: number; target?: number; bitLabels?: string[] } }
        | undefined;
      expect(block, `${exp.blockId} 必须存在`).toBeDefined();
      expect(block!.kind).toBe('interactive');
      expect(block!.spec?.kind).toBe('bit-flip');
      // schema 限制：initial / target ∈ [0, 255]
      expect(block!.spec!.initial).toBeGreaterThanOrEqual(0);
      expect(block!.spec!.initial).toBeLessThanOrEqual(255);
      expect(block!.spec!.target).toBeGreaterThanOrEqual(0);
      expect(block!.spec!.target).toBeLessThanOrEqual(255);
      expect(block!.spec!.target).toBe(exp.target);
      // bitLabels 必须 8 个
      expect(Array.isArray(block!.spec!.bitLabels)).toBe(true);
      expect(block!.spec!.bitLabels!.length).toBe(8);
    }
  });
});

test.describe('Iter-41-B · BitFlip primitive 真渲染', () => {
  async function gotoPage(page: Page, baseURL: string | undefined, pageId: string) {
    await page.goto(`${baseURL}?page=${pageId}`, { waitUntil: 'load' });
    await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
    await page.waitForTimeout(800);
  }

  test('p4-timer 含 BitFlip 卡片（CEN bit0）', async ({ page, baseURL }) => {
    await gotoPage(page, baseURL, 'p4-timer');
    // p4-timer 页面用 InteractiveCard 折叠展示 bit-flip prompt；
    // 断言 prompt 在 DOM（不强制 viewport 内可见，因为页面长滚动）。
    const prompt = page.locator('text=/启动定时器.*CEN/');
    await expect(prompt).toHaveCount(1, { timeout: 8000 });
    await prompt.scrollIntoViewIfNeeded();
    await page.screenshot({ path: path.join(SCREEN_DIR, '01-p4-timer-bitflip.png'), fullPage: false });
  });

  test('p7-adc 含 BitFlip 卡片（ADON+CONT）', async ({ page, baseURL }) => {
    await gotoPage(page, baseURL, 'p7-adc');
    const prompt = page.locator('text=/连续转换模式.*ADON/');
    await expect(prompt).toHaveCount(1, { timeout: 8000 });
    await prompt.scrollIntoViewIfNeeded();
    await page.screenshot({ path: path.join(SCREEN_DIR, '02-p7-adc-bitflip.png'), fullPage: false });
  });
});
