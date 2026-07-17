# STM32F10x 嵌入式教材

> DGBook 示范课程 · 12 个项目 · 53 页 · 328 blocks

## 课程信息

- **courseId**: stm32f10x-complete
- **版本**: 1.0.0
- **目标芯片**: STM32F103C8T6 (ARM Cortex-M3, 72MHz, 64KB Flash, 20KB SRAM)
- **开发环境**: STM32CubeIDE + CubeMX + HAL 库
- **硬件**: 已配套电路板

## 章节概览

| 章 | 项目名称 | 核心知识点 |
|----|---------|-----------|
| 1 | 认识单片机 | MCU概念·STM32F103参数·开发流程 |
| 2 | 开发环境 | CubeIDE·CubeMX·HAL库·GPIO |
| 3 | GPIO应用 | LED控制·按键扫描·EXTI中断 |
| 4 | 定时器 | PSC/ARR/CNT·溢出中断·数码管 |
| 5 | PWM输出 | 占空比·呼吸灯·舵机控制 |
| 6 | 串口通信 | UART协议·printf重定向·中断接收 |
| 7 | ADC采样 | 12位分辨率·光敏电阻·分压电路 |
| 8 | DAC输出 | 波形生成·正弦波表·DMA |
| 9 | 环境监测 | I2C·BH1750·HDC1080·MQ-2 |
| 10 | 无人停车场 | SPI·MFRC522·超声波·状态机 |
| 11 | 运动手环 | IMU·PPG·计步算法·低功耗 |
| 12 | 追光系统 | PID控制·舵机·四象限光敏 |

## 构建

```bash
# 当前构建流程（课程内容仍在 player/ 下）
python apps/player/public/gen_manifest_main.py
python apps/player/public/manifest/inject_all.py --continue-on-error
python apps/player/public/manifest/generate_page_actions.py
python apps/player/public/manifest/build_capabilities.py
python apps/player/public/manifest/build_gallery.py
```

## 资产迁移计划

课程特有内容将从 `apps/player/public/manifest/` 迁移到本目录：
- `chapters/*.py` → `courses/stm32f10x/chapters/`
- `intros_extensions.py` → `courses/stm32f10x/`
- `course_metadata.py` → `courses/stm32f10x/`
- `inject_narration_*.py` → `courses/stm32f10x/inject/`
