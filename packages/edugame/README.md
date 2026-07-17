# @dgbook/game — 教育游戏引擎

> 课程无关的游戏化学习框架，28 种游戏模式，可直接复用到任何数字化教材。

## 架构

```
src/
├── core/           ← 框架核心（课程无关）
│   ├── GameMode.ts       抽象基类：init / update / destroy
│   ├── GameSession.ts    状态机：idle → playing → paused → completed
│   ├── ScoreSystem.ts    评分引擎：连击 / 时间奖励 / 星级
│   ├── LevelLoader.ts    关卡加载器（JSON → LevelData）
│   ├── EduGameHost.tsx   React 宿主组件
│   └── types.ts          ModeId / LevelData / GameResult / GameContext
├── modes/          ← 28 种游戏模式（每个独立文件夹）
│   ├── bit-flip-quest/     位翻转闯关
│   ├── pin-rush/           引脚速配
│   ├── signal-surfer/      信号冲浪
│   ├── circuit-builder/    电路搭建
│   ├── memory-card/        记忆翻牌
│   ├── drag-match/         拖拽配对
│   ├── quiz-rush/          快答竞速
│   ├── tower-defense/      塔防守卫
│   └── ... (共28种)
└── levels/         ← 关卡数据（JSON，按课程/章节组织）
```

## 复用到新课程

```tsx
import { EduGameHost, BitFlipQuestMode } from '@dgbook/game';

// 1. 定义关卡数据
const level: LevelData = {
  modeId: 'bit-flip-quest',
  levelId: 'my-course-l1',
  title: '二进制基础',
  objective: '翻转指定位',
  difficulty: 1,
  starThresholds: [60, 80, 95],
  timeLimit: 60,
  data: { /* BitFlipQuestData */ }
};

// 2. 渲染
<EduGameHost
  mode={new BitFlipQuestMode()}
  level={level}
  onComplete={(result) => console.log(result)}
/>
```

## GameMode 接口

```ts
abstract class GameMode<TPayload = unknown> {
  abstract readonly id: ModeId;
  abstract readonly displayName: string;
  abstract readonly objective: string;
  abstract readonly howToPlay: string[];
  
  abstract init(ctx: GameContext): void | Promise<void>;
  update(dt: number): void {}
  pause(): void {}
  resume(): void {}
  abstract destroy(): void;
}
```

## 28 种游戏模式

| 模式 | 教学目标 | 适用场景 |
|------|---------|---------|
| bit-flip-quest | 位操作 | 寄存器/二进制 |
| pin-rush | 引脚识别 | GPIO/硬件 |
| signal-surfer | 信号分析 | 通信协议 |
| circuit-builder | 电路搭建 | 电路设计 |
| interrupt-defender | 中断处理 | 嵌入式系统 |
| memory-card | 概念记忆 | 术语/定义 |
| drag-match | 概念配对 | 对应关系 |
| sort-flow | 排序流程 | 步骤/流程 |
| quiz-rush | 快速问答 | 知识点巩固 |
| tower-defense | 策略防御 | 系统架构 |
| match-3 | 三消匹配 | 分类识别 |
| pipe-connect | 管道连接 | 数据流/信号流 |
| maze-troubleshoot | 迷宫排错 | 调试思维 |
| timeline-build | 时间线构建 | 历史/顺序 |
| classification-run | 分类跑酷 | 快速分类 |
| ... | ... | ... |
