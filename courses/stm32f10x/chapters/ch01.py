# -*- coding: utf-8 -*-
"""
build_p1_goals_page / build_p2_gpio_hal_page
此文件由 gen_manifest_main.py 自动拆分，请勿手动修改函数签名。
"""
import os as _os, sys as _sys
_PUBLIC_DIR = _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__))))
if _PUBLIC_DIR not in _sys.path:
    _sys.path.insert(0, _PUBLIC_DIR)

from manifest.blocks import (
    text_block, code_block, mindmap_block, anim_block, intro_block,
    summary_block, dh_block, matching, classification, ordering,
    flashcard, memory_match, fill_blank, hotspot,
    table_block, experiment_block, step, waveform_block, page,
)

# 注入 gen_manifest.py 中的 page/quiz 等基础函数（exec 兼容模式）
_GM_PATH = _os.path.join(_PUBLIC_DIR, 'gen_manifest.py')
exec(open(_GM_PATH, encoding='utf-8').read(), globals())

# ─── 额外补充页面（对应书籍化目录新增的节）─────────────────────────
def build_p1_goals_page():
    """1.1 学习目标与工作任务（项目引入页）"""
    from gen_svg import svg_stm32_block
    return page(
        "p1-goals", "1.1 学习目标与项目引入",
        blocks=[
            text_block("p1g-text", """\
                # 项目一：认识单片机

                ## 1.1 学习目标

                完成本项目学习后，你将能够：

                | 序号 | 学习目标 | 能力层次 |
                |------|---------|---------|
                | 1 | 理解单片机（MCU）的定义与核心特点 | 理解 |
                | 2 | 区分MCU、CPU、SoC三类芯片的本质差异 | 分析 |
                | 3 | 说出STM32F103C8T6的核心参数（主频/Flash/SRAM/外设） | 记忆 |
                | 4 | 了解单片机从4位到32位的发展历程 | 了解 |
                | 5 | 认识国产MCU（GD32/AT32等）的发展现状 | 了解 |
                | 6 | 理解单片机的典型硬件结构与开发流程 | 理解 |

                ## 1.2 工作任务安排

                本项目分为两个工作任务，建议学习时间约2课时：

                | 任务编号 | 任务名称 | 核心内容 | 建议时间 |
                |---------|---------|---------|---------|
                | **工作任务一** | 认识单片机 | 基本概念·发展历程·国产MCU·应用领域 | 45分钟 |
                | **工作任务二** | 典型结构和工作场景 | 硬件构成·开发系统·工作原理·开发流程 | 45分钟 |

                ## 1.3 项目引入

                单片机技术是现代电子系统设计的基石。在你的日常生活中，单片机无处不在：

                - 🏠 **家用电器**：洗衣机控制板、微波炉定时器、空调温控器
                - 📱 **消费电子**：手机充电器、蓝牙耳机、智能手表
                - 🚗 **汽车电子**：ABS防抱死系统、发动机ECU、车窗控制器
                - 🏥 **医疗设备**：血糖仪、心电图机、输液泵
                - 🏭 **工业控制**：PLC、变频器、机器人关节控制器
                - 🌐 **物联网**：智能门锁、环境传感器节点、工业网关

                > 💡 **数据**：全球每年生产约300亿颗MCU，平均每人每天接触50+颗单片机。
                > 掌握单片机技术，就掌握了现代电子世界的"语言"。

                ## 1.4 为什么选择STM32F103入门

                STM32F103是嵌入式入门的黄金选择，原因如下：

                1. **性价比高**：开发板约20~50元，芯片约5~15元，学习成本低
                2. **生态完善**：ST官方提供CubeIDE+CubeMX+HAL库，工具链免费
                3. **资料丰富**：中文教程、视频、论坛资源极多，遇到问题容易找到答案
                4. **工业应用广**：掌握后可直接用于实际项目，就业竞争力强
                5. **国产替代**：GD32F103与STM32F103引脚兼容，代码可直接移植

                ## 1.5 本课程学习路径

                ```
                项目1：认识单片机（概念基础）
                    ↓
                项目2：开发环境搭建（工具链）
                    ↓
                项目3：GPIO应用（第一个实验）
                    ↓
                项目4~6：定时器/PWM/串口（核心外设）
                    ↓
                项目7~8：ADC/DAC（模拟信号）
                    ↓
                项目9~12：综合系统（传感器融合/PID控制）
                ```

                > 💡 学习单片机可以培养解决复杂问题的能力，为物联网时代的职业发展奠定基础。
            """),
            {"id": "p1g-svg", "kind": "graphics", "src": f"inline:{svg_stm32_block()}",
             "format": "svg", "caption": "STM32F103 内部系统框图"},
            summary_block("p1g-sum",
                ["单片机=CPU+存储器+外设集成在一颗芯片上的微型计算机",
                 "工作任务一：认识单片机基本概念与发展历程",
                 "工作任务二：学习STM32典型硬件结构与开发流程",
                 "本课程参考教材：STM32F103嵌入式系统开发（194页）"],
                ["单片机和CPU的区别是什么？", "为什么选择STM32F103作为入门芯片？"]),
        ],
        objectives=["了解课程整体目标", "了解单片机基本概念", "预习STM32F103芯片架构"],
        minutes=15, difficulty="beginner", tags=["intro", "overview", "mcu"]
    )


def build_p2_gpio_hal_page():
    """2.2 工作任务二：GPIO与HAL库程序设计"""
    from gen_svg import svg_gpio_modes
    return page(
        "p2-gpio-hal", "2.2 GPIO与HAL库程序设计",
        blocks=[
            text_block("p2gh-text", """\
                # 2.2 STM32 GPIO与HAL库程序设计

                ## 2.2.1 STM32F1系统架构与总线矩阵

                STM32F103基于ARM Cortex-M3内核，通过**AHB/APB总线矩阵**连接所有外设。
                理解总线结构对配置时钟和外设至关重要。

                | 总线 | 频率 | 连接的外设 |
                |------|------|-----------|
                | **AHB** | 72MHz | Flash、SRAM、DMA1/2、FSMC |
                | **APB2** | 72MHz | GPIOA~G、USART1、SPI1、ADC1/2、TIM1/8 |
                | **APB1** | 36MHz | TIM2~7、USART2~3、SPI2、I2C1/2、CAN、USB |

                > ⚠️ **关键**：使用任何外设前必须先使能其所在总线的时钟！
                > 例如：使用GPIOA前必须调用 `__HAL_RCC_GPIOA_CLK_ENABLE()`

                ## 2.2.2 GPIO 8种工作模式详解

                STM32的GPIO有8种工作模式，选择正确的模式是硬件驱动的基础：

                | 模式 | HAL宏常量 | 内部结构 | 典型应用 |
                |------|----------|---------|---------|
                | **推挽输出** | GPIO_MODE_OUTPUT_PP | P管+N管互补 | 驱动LED、继电器 |
                | **开漏输出** | GPIO_MODE_OUTPUT_OD | 只有N管 | I2C总线、线与逻辑 |
                | **浮空输入** | GPIO_MODE_INPUT + GPIO_NOPULL | 无偏置 | 外部强驱动信号 |
                | **上拉输入** | GPIO_MODE_INPUT + GPIO_PULLUP | 内部上拉~40kΩ | 按键（默认高电平） |
                | **下拉输入** | GPIO_MODE_INPUT + GPIO_PULLDOWN | 内部下拉~40kΩ | 特殊传感器 |
                | **模拟输入** | GPIO_MODE_ANALOG | 直通ADC | ADC/DAC引脚 |
                | **复用推挽** | GPIO_MODE_AF_PP | 外设控制+推挽 | UART TX、SPI MOSI |
                | **复用开漏** | GPIO_MODE_AF_OD | 外设控制+开漏 | I2C SDA/SCL |

                ### 推挽 vs 开漏的本质区别

                ```
                推挽输出：
                  高电平 → P管导通，N管截止 → 引脚强制拉高到VCC（3.3V）
                  低电平 → P管截止，N管导通 → 引脚强制拉低到GND（0V）
                  特点：驱动能力强，可以主动输出高低电平

                开漏输出：
                  低电平 → N管导通 → 引脚拉低到GND
                  高电平 → N管截止 → 引脚悬空（高阻态），需外部上拉电阻
                  特点：多个开漏设备可以共享一根线（线与逻辑），I2C就是这样工作的
                ```

                ## 2.2.3 GPIO输出速度配置

                STM32 GPIO输出速度影响信号边沿陡峭程度和EMI辐射：

                | 速度等级 | HAL宏 | 最大翻转频率 | 适用场景 |
                |---------|------|------------|---------|
                | 低速 | GPIO_SPEED_FREQ_LOW | 2MHz | LED、普通IO |
                | 中速 | GPIO_SPEED_FREQ_MEDIUM | 10MHz | 一般外设 |
                | 高速 | GPIO_SPEED_FREQ_HIGH | 50MHz | SPI、高速信号 |

                > 💡 **原则**：速度够用就好，速度越高EMI越大，功耗越高。
                > LED用低速，SPI用高速。

                ## 2.2.4 GPIO寄存器直接操作（进阶）

                HAL库封装了寄存器操作，但了解底层有助于调试：

                ```c
                /* 方式1：HAL库（推荐，可读性好）*/
                HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_SET);

                /* 方式2：直接操作ODR寄存器（不推荐，非原子操作）*/
                GPIOA->ODR |= GPIO_PIN_5;   /* 置高 */
                GPIOA->ODR &= ~GPIO_PIN_5;  /* 置低 */

                /* 方式3：BSRR寄存器（推荐，原子操作，中断安全）*/
                GPIOA->BSRR = GPIO_PIN_5;          /* 置高（低16位）*/
                GPIOA->BSRR = GPIO_PIN_5 << 16;    /* 置低（高16位）*/

                /* 方式4：读取输入（IDR寄存器）*/
                uint8_t val = (GPIOA->IDR & GPIO_PIN_0) ? 1 : 0;
                ```

                **BSRR的优势**：写入BSRR是原子操作，不会被中断打断，
                避免了"读-改-写"序列中的竞态条件。
            """),
            {"id": "p2gh-svg", "kind": "graphics", "src": f"inline:{svg_gpio_modes()}",
             "format": "svg", "caption": "GPIO 8种工作模式示意图"},
            anim_block("p2gh-anim", "GPIO工作模式详解", [
                {"icon": "⬆️", "t": "推挽输出（Push-Pull）",
                 "d": "P管+N管互补，可输出强高/低电平。驱动LED时GPIO→220Ω→LED→GND，最大驱动电流25mA。"},
                {"icon": "🔓", "t": "开漏输出（Open-Drain）",
                 "d": "只有N管，低电平接GND，高电平为高阻态。I2C标准接法，需外接4.7kΩ上拉电阻实现高电平。"},
                {"icon": "⬇️", "t": "输入模式（浮空/上拉/下拉）",
                 "d": "浮空：无偏置，电平由外部决定。上拉：内部拉到VCC，无信号=高。按键通常配置上拉输入。"},
                {"icon": "🔄", "t": "复用功能（AF）",
                 "d": "引脚控制权交给UART/SPI/I2C/TIM等外设。AF_PP用于UART TX/SPI MOSI，AF_OD用于I2C。"},
            ]),
            matching("p2gh-g1", "连线：GPIO模式与典型应用场景", [
                ("推挽输出PP", "驱动LED、继电器（强驱动）"),
                ("开漏输出OD", "I2C SDA/SCL总线（线与逻辑）"),
                ("上拉输入PU", "按键检测（未按下=高电平）"),
                ("模拟输入AN", "ADC采样光敏/温度传感器"),
                ("复用推挽AFP", "UART TX发送引脚"),
            ]),
            classification("p2gh-g2", "分类：以下操作属于哪类GPIO功能？",
                {"output": "GPIO输出操作", "input": "GPIO输入操作", "af": "复用功能"},
                [("g1", "HAL_GPIO_WritePin()置高LED", "output"),
                 ("g2", "HAL_GPIO_ReadPin()读按键电平", "input"),
                 ("g3", "UART1 TX引脚配置为AF_PP", "af"),
                 ("g4", "HAL_GPIO_TogglePin()翻转引脚", "output"),
                 ("g5", "I2C1 SDA配置为AF_OD+上拉", "af"),
                 ("g6", "ADC通道引脚配置为Analog", "input")]),
            flashcard("p2gh-g3", "GPIO关键知识卡片", [
                ("使能GPIO时钟的正确方式？", "__HAL_RCC_GPIOx_CLK_ENABLE()，必须在GPIO_Init之前调用，否则初始化无效"),
                ("HAL_GPIO_WritePin参数？", "参数：(GPIOx, GPIO_Pin, PinState)，PinState=SET(高)/RESET(低)"),
                ("如何同时操作多个引脚？", "GPIO_PIN_13 | GPIO_PIN_14，使用位或运算同时操作多个引脚"),
                ("BSRR寄存器的优势？", "原子操作，高16位清位，低16位置位，中断安全"),
            ]),
            ordering("p2gh-g4", "按正确顺序排列GPIO初始化步骤：", [
                "使能GPIO时钟：__HAL_RCC_GPIOA_CLK_ENABLE()",
                "配置GPIO_InitStruct结构体（Pin/Mode/Speed）",
                "调用HAL_GPIO_Init()完成初始化",
                "使用HAL_GPIO_WritePin()/ReadPin()操作引脚",
            ]),
            code_block("p2gh-code", "c", """\
                /* GPIO完整配置示例 */
                #include "main.h"

                void gpio_config_demo(void) {
                    GPIO_InitTypeDef GPIO_InitStruct = {0};
                    __HAL_RCC_GPIOA_CLK_ENABLE(); /* ★必须先使能时钟！*/

                    /* PA5推挽输出（LED）*/
                    GPIO_InitStruct.Pin   = GPIO_PIN_5;
                    GPIO_InitStruct.Mode  = GPIO_MODE_OUTPUT_PP;
                    GPIO_InitStruct.Pull  = GPIO_NOPULL;
                    GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
                    HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

                    /* PA0上拉输入（按键）*/
                    GPIO_InitStruct.Pin  = GPIO_PIN_0;
                    GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
                    GPIO_InitStruct.Pull = GPIO_PULLUP;
                    HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

                    /* 操作 */
                    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_SET);
                    HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_5);
                    if (HAL_GPIO_ReadPin(GPIOA, GPIO_PIN_0) == GPIO_PIN_RESET) {
                        /* 按键按下（低有效）*/
                    }
                }
            """, "gpio_config.c", [5, 8, 14, 20, 22]),
            experiment_block("p2gh-exp", "GPIO输入输出实验", [
                step(1, "CubeMX配置", "PA5→GPIO_Output(PP)，PA0→GPIO_Input(Pull-up)，Generate Code。", chk=True),
                step(2, "LED闪烁", "USER CODE中调用TogglePin+Delay(500)，下载验证LED闪烁。",
                     "HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_5);\nHAL_Delay(500);", True),
                step(3, "按键控制LED", "PA0=低时PA5 LED亮，松开时LED灭。", chk=True),
                step(4, "寄存器调试", "Debug模式下查看GPIOA->ODR和IDR的值。", chk=False),
            ]),
            summary_block("p2gh-sum",
                ["GPIO使能时钟必须在Init之前，是最常见的初始化错误",
                 "8种模式：推挽PP最常用，I2C用开漏OD+外部上拉",
                 "HAL_GPIO_WritePin/ReadPin/TogglePin是三个核心操作函数",
                 "BSRR寄存器实现原子GPIO操作，中断安全无竞态条件"],
                ["推挽输出和开漏输出驱动能力有何不同？"]),
            dh_block("p2gh-dh",
                "GPIO是STM32最基础的外设，所有实验都从GPIO开始。理解8种模式对后续I2C、UART配置很重要。",
                [{"q": "时钟不使能会发生什么？",
                  "a": "GPIO所有操作无效，引脚保持默认状态（复位后为浮空输入）。这是初学者最常犯的错误。"}]),
        ],
        objectives=["掌握GPIO 8种模式的区别", "学会HAL库配置GPIO", "完成GPIO输入输出实验"],
        minutes=40, difficulty="beginner", tags=["gpio", "hal", "stm32"]
    )


