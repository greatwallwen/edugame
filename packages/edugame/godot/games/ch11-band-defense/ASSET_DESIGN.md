# 手环数据链路防线素材设计

本设计服务于第 11 章“运动手环”塔防复习游戏。敌人表示数据链路中的异常信号或系统风险；塔表示处理这些风险所需的知识模块。视觉可以简约科幻，但概念不能偏离 IMU、I2C、滤波、计步峰值检测和低功耗唤醒。

概念图：

```text
packages/edugame/assets/games/ch11-band-defense/concept/band-defense-enemy-tower-sheet-v1.png
packages/edugame/assets/games/ch11-band-defense/concept/band-defense-enemy-tower-sheet-v2-contrast.png
```

优先使用 v2 contrast 作为后续拆分素材参考。v2 的重点是拉开敌人与塔的识别差异：敌人像“被污染的异常数据”，塔像“可信的数据处理模块”。

Godot 内仍可通过 `res://assets/...` 访问这些素材，因为 `packages/edugame/godot/games/ch11-band-defense/assets` 是指向中央素材库的目录联接。

## 敌人素材

| 敌人 | 对应知识点 | 视觉锚点 | 克制塔 |
| --- | --- | --- | --- |
| 配置错误包 | I2C 地址错误、WHO_AM_I 不匹配、ODR/量程寄存器配置错误。 | 破损寄存器块、错位总线、警告小角标。 | I2C 初始化塔 |
| 传感噪声包 | 加速度计原始数据中的抖动、采样噪声和瞬时毛刺。 | 带毛刺的波形、散点噪声、抖动数据包。 | 滤波塔 |
| 假峰值信号 | 手臂晃动或阈值过低导致的误计步峰值。 | 超过阈值的尖峰、重复峰、时间间隔门。 | 峰值检测塔 |
| 功耗尖峰 | 未进入 STOP、唤醒策略不当或显示/采样策略过密造成的耗电风险。 | 电池冲击波、异常电流脉冲、睡眠被打断。 | 低功耗唤醒塔 |

## 防御塔素材

| 塔 | 严谨含义 | 视觉锚点 | 不应表现为 |
| --- | --- | --- | --- |
| I2C 初始化塔 | 通过总线初始化、设备地址、WHO_AM_I 和寄存器配置确认传感器可用。 | SDA/SCL 双线、寄存器格、设备 ID 校验。 | 不负责滤波或计步判定。 |
| 滤波塔 | 对原始加速度信号做平滑、去毛刺或防抖，降低噪声误触发。 | 噪声波形进入后变平滑、低通曲线、滤波栅格。 | 不修复 I2C 地址或寄存器错误。 |
| 峰值检测塔 | 依据合加速度、阈值和最小步间隔识别有效步态峰值。 | 峰值曲线、水平阈值线、时间间隔门。 | 不等同于简单“高伤害炮塔”。 |
| 低功耗唤醒塔 | 通过 STOP 模式、WOM 运动唤醒和中断策略降低可穿戴设备功耗。 | 电池、睡眠月牙/待机符号、运动唤醒脉冲。 | 不表示普通电量补给或攻击武器。 |

## 视觉规则

- 敌人应像“异常数据包、错误状态、噪声事件”，不要画成生物。
- 塔应像“数据处理节点、传感器模块、算法模块”，不要画成炮台武器。
- 敌人与塔必须在剪影、色彩、材质上明显区分：
  - 敌人：深色、破碎、棱角、不对称、故障像素、琥珀/紫色警告。
  - 塔：浅色、干净、圆角、对称、稳定青色数据线、绿色可信反馈。
- 使用浅色科技 UI：蓝白底、蓝灰硬件边框、青色数据线、绿色可信数据、琥珀色警告。
- 避免太阳、太阳能板、追光、PID、Kp/Ki/Kd、PWM 舵机等第 12 章语义。
- 不依赖图片内文字解释知识点；专业解释放在 UI、图鉴、题目反馈中。

## 接入建议

当前 MVP 已有 4 类敌人与 4 类塔：

```text
enemy: config, noise, false_peak, power_spike
tower: i2c, filter, peak, power
```

后续可以先把概念图拆成独立透明 PNG，保存到：

```text
packages/edugame/assets/games/ch11-band-defense/sprites/
```

运行时代码中可把现有灰盒绘制替换为这些贴图，但仍保留 `threatTag` 与 `counterTags` 的克制关系，避免把塔防变成纯数值战斗。

## 背景地图素材

当前推荐背景地图：

```text
packages/edugame/assets/games/ch11-band-defense/backgrounds/band-defense-map-v2-screen.png
```

Godot 项目内访问路径：

```text
res://assets/backgrounds/band-defense-map-v2-screen.png
```

旧版背景地图：

```text
packages/edugame/assets/games/ch11-band-defense/backgrounds/band-defense-map-v1.png
```

Godot 项目内访问路径：

```text
res://assets/backgrounds/band-defense-map-v1.png
```

这张图是 1280x720 的完整画布背景。左侧约 70% 是塔防地图，保留固定数据路径和 4 个空塔位；右侧约 25% 是留给 HUD 的深色空面板。画面表达手环 IMU/PPG 数据链路、I2C 总线、滤波、峰值检测与低功耗唤醒，但不使用图片内文字说明。后续接入时，建议先把它作为底图绘制，再保留或弱化现有代码绘制的路径线与塔位高亮。

v2 将右侧空面板调整为更像一块正在工作的嵌入式诊断屏：有玻璃反光、内发光边框、扫描网格、波形幽影和空状态模块。它仍然不承担知识解释文本，只作为 UI 背景和屏幕氛围。

第二关专用背景地图：

```text
packages/edugame/assets/games/ch11-band-defense/backgrounds/band-defense-map-level2-night-run.png
```

Godot 项目内访问路径：

```text
res://assets/backgrounds/band-defense-map-level2-night-run.png
```

这张图用于“手环夜跑数据异常”。它保持第一关的浅色 PCB、右侧诊断屏和手环数据链路风格，但左侧路线改为更长的单线折返路线，并提供 6 个空塔位，让第二关在视觉和策略上都比第一关更复杂。
