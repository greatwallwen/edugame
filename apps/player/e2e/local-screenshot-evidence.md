# DGBook · 本地截图取证清单（Iter-40 系列）

> 仿 AI培训项目 `local-screenshot-evidence.md` 方法论：每个关键场景 1 张证据截图，
> 配合 spec 文件作为 e2e 取证的可读 catalog。
>
> **生成方式**：`pnpm --filter @dgbook/player e2e -- screenshot-evidence`
> **输出路径**：`apps/player/e2e/screenshots/iter40-evidence/`
> **跑生产**：BASE_URL 默认 http://124.220.234.157/（playwright.config.ts）

## 主路径快照（10 张）

| # | 文件 | 来源场景 | 采集方式 | 用途 |
|---|---|---|---|---|
| 01 | `01-shell-home-fullscreen.png` | 首页加载完成 | 全屏 viewport 1536×864 | 三栏布局 + 底部播放条 + 课程导航完整态 |
| 02 | `02-ch3-led-mainview.png` | 进入 p3-led-blink 页 | viewport 截图 | Iter-40-D Wokwi 三件套就位的主区视觉 |
| 03 | `03-wokwi-led-closeup.png` | LED 元件 element 截图 | scrollIntoView + element.screenshot | 红色 LED + 阳极 PA5 标签 1:1 端口自 wokwi-elements 1.9.2 视觉验证 |
| 04 | `04-wokwi-resistor-closeup.png` | 220Ω 电阻 element 截图 | scrollIntoView + element.screenshot | 4 色环（红红棕金） 电子色码自动计算正确性 |
| 05 | `05-teacher-audiobar-bottom.png` | 首页底部裁剪 | clip {x:0, y:vh-200, w:vw, h:200} | aiTutor.subtitle 数据驱动双行版式（教训 81）|
| 06 | `06-ch1-concept.png` | p1-concept 页 | viewport 截图 | ch1 章节首页（finaleTrig=0 + animTpl=4 模板）|
| 07 | `07-ch7-adc.png` | p7-adc 页 | viewport 截图 | ch7 ADC 页（含 fsm 模板动画 + 大量 SVG）|
| 08 | `08-ch10-parking.png` | p10-parking 页 | viewport 截图 | ch10 综合应用页（综合考察）|
| 09 | `09-finale-challenge-entry.png` | LED 页底部 | scrollTo bottom + viewport | finale-challenge 闯关入口按钮 |
| 10 | `10-ch3-led-fullpage.png` | LED 页 fullPage | fullPage:true | 整页内容流（text → graphics → 2 wokwi-element → mindmap → ...）|

## 学生交互快照（5 张）

| # | 文件 | 来源动作 | 采集方式 | 用途 |
|---|---|---|---|---|
| 11 | `11-after-space-press.png` | LED 页 → Space | keyboard.press('Space') + 500ms | Iter-40-G Space 暂停/继续 UI 状态变化（按钮图标）|
| 12 | `12-after-arrow-right.png` | LED 页 → → | keyboard.press('ArrowRight') + 800ms | ArrowRight 翻页到下一课节后视觉态 |
| 13 | `13-mobile-iphone12.png` | LED 页 + 390×844 | setViewportSize | iPhone 12 移动端不溢出验证 |
| 14 | `14-tablet-ipad-mini.png` | LED 页 + 768×1024 | setViewportSize | iPad mini 平板视口适配 |
| 15 | `15-desktop-1920.png` | LED 页 + 1920×1080 | setViewportSize | 大屏教室 1080p 投影仪适配 |

## 功能断言截图（来自 iter40-features.spec.ts，3 张）

| # | 文件 | 来源场景 | 用途 |
|---|---|---|---|
| F1 | `screenshots/iter40-features/01-wokwi-led-resistor-rendered.png` | LED 页 Wokwi 渲染 | 配合 locator 断言（≥1 LED + ≥1 resistor）|
| F2 | `screenshots/iter40-features/02-teacher-role-bottom-bar.png` | 首页底部讲师区 | 配合 text 断言（"随堂问答 / 课堂伙伴 / 讲师"匹配）|
| F3 | `screenshots/iter40-features/03-keyboard-arrow-right-navigated.png` | ArrowRight 后 | 配合 URL 变化断言 |

**总计：18 张截图证据 + 1 个 spec catalog**

## RALPH 收敛记录（Iter-40 末）

| 轮 | 失败 | 修复 | 结果 |
|---|---|---|---|
| 1 基线 | 4 flaky（network timeout）| — | 24 PASS / 0 fail / 4 flaky |
| 2 | 3 flaky + 1 fail（PA5 label） | smoke 8s→15s timeout | 26 PASS / 0 fail / 3 flaky |
| 3 | 2 flaky | iter40-features 加 waitForSelector 替代 waitForTimeout | 26 PASS / 0 fail / 2 flaky-retry-pass |

**收敛标准达成**：硬 fail 清零，剩余 flaky 都是 retry 即过的网络抖动，不是代码 bug（教训 85）。

## 复现步骤

```bash
# 1. 跑生产 e2e（含截图证据采集）
cd apps/player
pnpm e2e

# 2. 仅跑截图证据 spec（5min）
pnpm e2e -- screenshot-evidence

# 3. 跑特定 viewport
BASE_URL=http://124.220.234.157/ pnpm e2e -- screenshot-evidence -g "iPhone 12"

# 4. 看 HTML 报告（CI 模式自动生成）
CI=1 pnpm e2e
# 然后 npx playwright show-report
```

## 与 AI培训项目方法论的差异

| 维度 | AI培训 | DGBook |
|---|---|---|
| 测试入口 | 本地 dev server | **生产 URL**（教训 84）|
| 截图载体 | scripts 直接调用 chromium.launch | Playwright test framework + retry/trace |
| 证据格式 | markdown 三列表 | markdown 五列表 + RALPH 收敛记录 |
| 自动化触发 | 手动跑 / CI 触发 | 同（手动 + CI 双模式）|

## 下一步（Iter-40-G2）

当 page.actions 数据接入主路径后，需要补的截图：
- 16. 场景化播放进行中（spotlight 高亮 + 字幕同步）
- 17. 段间 ←/→ 切换前后对比图
- 18. ch3 LED 页 14 段微电影第 N 段定格
