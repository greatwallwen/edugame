# DGBook · 数字教材平台

> 可复用的数字教材底层框架 + 示范课程实例。
> 朗读驱动 · 块级 spotlight · 多种动画模板 · 25 种互动题型 · 闯关游戏化挑战。

## 架构

```
DGBook/                       monorepo (pnpm)
├── apps/player/              框架播放器 (React + Vite + TS)
├── packages/types            manifest schema (zod)
├── packages/primitives       block 组件
├── packages/renderer-sdk     页面渲染器
├── courses/                  课程资产（stm32f10x + _template）
├── docs/                     框架文档
└── courses/_template/PROMPT.md  AI 内容生成约束
```

## 铁律（违反会浪费大量时间）

1. **manifest.json 是构建产物**（在 .gitignore 中）。绝不直接手工编辑。
2. **改源头不改产物**：`chapters/*.py` 或 `inject_*.py`（挂在 `inject_all.py` 管线）。
3. **构建期 zod 校验是硬门**：`pnpm -F @dgbook/player exec vitest run src/playback/manifest-schema.test.ts`
4. **验证必须真实**：build → 部署 → 浏览器打开 `http://124.220.234.157/?page=<页id>` 实看渲染。

## 常用命令

```bash
pnpm -F @dgbook/player dev          # 开发模式
pnpm -F @dgbook/player build        # 构建
pnpm -F @dgbook/player exec vitest run src/playback/manifest-schema.test.ts  # schema 校验
python apps/player/public/deploy/deploy_step1.py   # 部署
```

**新机器首次恢复**：
```bash
pnpm install
python apps/player/public/gen_manifest_main.py
python apps/player/public/manifest/inject_all.py --continue-on-error
python apps/player/public/manifest/generate_page_actions.py
python apps/player/public/manifest/build_capabilities.py
python apps/player/public/manifest/build_gallery.py
```

## 生成链路

```
gen_manifest_main.py → inject_all.py --continue-on-error
→ generate_page_actions.py → build_capabilities.py → build_gallery.py
```

## 部署

```bash
pnpm build
python apps/player/public/deploy/deploy_step1.py
```

| 项目 | 值 |
|------|------|
| 测试地址 | `http://124.220.234.157/` |
| 前端路径 | `/opt/dgbook/player/` |
| Gitea | `http://water.js.cn:3156/greatwallwen/DGBook` |

## 核心概念

- **manifest.json** — 内容数据源（构建产物，不入 git）
- **Block** — 内容积木（14 种 kind × spotlight 播报语义）
- **Interactive** — 25 种互动题型（15 种已使用）
- **Finale** — 每章末尾多关闯关挑战（全 12 章覆盖）

## 工作纪律

- 改 → zod 测试 → 部署 → 浏览器验证 → commit → push
- 奥卡姆原则：最小改动解决问题
- 诚实复盘：验证发现的问题如实报告
- Git remote 是 `gitea`（不是 origin）

## 当前状态

53 页 · 15 种互动题型 · 12 章 finale · 全章节播报 · courses/ 资产分离骨架

## 文档导航

| 类别 | 入口 |
|---|---|
| 文档总入口 | [docs/README.md](docs/README.md) |
| 踩坑经验 | [docs/LESSONS.md](docs/LESSONS.md) |
| 框架架构 | [docs/framework/](docs/framework/) |
| 课程制作 | [docs/authoring/](docs/authoring/) |
| 迭代日志 | [docs/retrospectives/](docs/retrospectives/) |
| AI 内容规范 | [courses/_template/PROMPT.md](courses/_template/PROMPT.md) |

## License

[MIT](LICENSE) © DGBook contributors.
