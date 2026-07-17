/**
 * vitest config for @dgbook/player
 *
 * 用途：Iter-36 T-4.1 起，给 apps/player 内部 .ts 模块（ActionEngine / PageActionRunner /
 * TTSAdapter / blockToSpeech / 等）提供单元测试基础设施。
 *
 * 选择：
 *   - environment: 'node' —— ActionEngine / PageActionRunner 是纯逻辑类，无 DOM 依赖
 *     （需要 DOM 的测试可以单独 describe 里 vi.stubGlobal 或写入 jsdom env file）
 *   - 不引入 @testing-library/react —— 不在 player 包里测 React 组件（那是 primitives 的职责）
 *   - 排除 e2e Playwright spec 与 dist
 */
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    globals: false,
    include: ['src/**/*.{test,spec}.{ts,tsx}'],
    exclude: ['e2e/**', 'dist/**', 'dist-offline/**', 'node_modules/**'],
  },
});
