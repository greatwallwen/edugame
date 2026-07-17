import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { fileURLToPath } from 'node:url';

export default defineConfig(({ mode }) => ({
  plugins: [react()],
  resolve: {
    alias: {
      '@dgbook/game/host': fileURLToPath(new URL('../../packages/edugame/src/core/EduGameHost.tsx', import.meta.url)),
      '@dgbook/game': fileURLToPath(new URL('../../packages/edugame/src/index.ts', import.meta.url)),
    },
  },
  server: {
    port: 5173,
    strictPort: true,
    host: '127.0.0.1',
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true,
      },
    },
  },
  build: {
    target: 'es2022',

    // 开发保留 true 便于调试。
    sourcemap: mode !== 'production',
    outDir: 'dist',
    rollupOptions: {
      output: {

        // 浏览器可并行下载 + 长期缓存（业务代码变更不会让 vendor 失效）。
        // mermaid/pixi 生态已通过 React.lazy 动态 import 自动分块，无需手动列。
        manualChunks(id) {
          if (id.includes('node_modules')) {
            if (/[\\/](react|react-dom|scheduler)[\\/]/.test(id)) return 'vendor-react';
            if (id.includes('zod')) return 'vendor-zod';
          }
          if (id.includes('/packages/primitives/') || id.includes('@dgbook/blocks')) {
            return 'blocks-interactive';
          }
          return undefined;
        },
      },
    },
  },
}));
