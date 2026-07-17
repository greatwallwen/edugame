# -*- coding: utf-8 -*-
"""
build_p2_pages / quick_page / build_p3_pages
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
    interactive,
    table_block, experiment_block, step, waveform_block, page,
    mermaid_block,
    # M10 · Finale Challenge
    finale_challenge_block, finale_stage,
    fq_quiz_single, fq_quiz_multi, fq_quiz_tf, fq_quiz_fill,
    fq_int_matching, fq_int_ordering,
)
from manifest.factories import quick_page  # noqa: E402

# 注入 gen_manifest.py 中的 page/quiz 等基础函数（exec 兼容模式）
_GM_PATH = _os.path.join(_PUBLIC_DIR, 'gen_manifest.py')
exec(open(_GM_PATH, encoding='utf-8').read(), globals())

def build_p2_pages():
    pages = []
    pages.append(page(
        "p2-ide", "2.1 开发环境搭建与CubeMX配置",
        blocks=[
            text_block("p2-ide-text", """\
                # 2.1 STM32开发环境搭建与CubeMX配置

                ## 2.1.1 开发工具链概述

                STM32开发采用ST官方提供的完整工具链，全部免费：

                | 工具 | 版本 | 用途 | 下载地址 |
                |-----|------|------|---------|
                | **STM32CubeIDE** | 1.14+ | 集成IDE（编辑+编译+调试） | st.com/stm32cubeide |
                | **STM32CubeMX** | 6.10+ | 图形化芯片配置（内置于IDE） | 随CubeIDE安装 |
                | **STM32CubeF1** | 1.8+ | HAL库固件包 | CubeMX自动下载 |
                | **ST-Link驱动** | V3 | 仿真器USB驱动 | 随IDE安装 |

                > 💡 **安装顺序**：先装CubeIDE → 启动后自动提示安装HAL库固件包 → 插入ST-Link自动安装驱动

                ## 2.1.2 STM32CubeMX 图形化配置详解

                CubeMX是STM32开发的核心工具，通过图形界面完成芯片配置，自动生成初始化代码。

                ### 新建工程步骤

                1. **File → New STM32 Project**
                2. 搜索芯片型号：输入 `STM32F103C8` → 选择 `STM32F103C8Tx`
                3. 输入工程名和路径 → Finish

                ### 引脚配置（Pinout & Configuration）

                - 点击芯片引脚图上的引脚 → 弹出功能列表
                - 选择功能：`GPIO_Output`（LED）/ `GPIO_Input`（按键）/ `USART1_TX` 等
                - 绿色引脚=已配置，黄色=冲突，灰色=未使用

                ### 时钟树配置（Clock Configuration）

                ```
                外部晶振 HSE = 8MHz
                    ↓ PLL倍频 ×9
                SYSCLK = 72MHz（最高主频）
                    ↓ AHB分频 ÷1
                HCLK = 72MHz（CPU/GPIO/DMA时钟）
                    ↓ APB1分频 ÷2
                PCLK1 = 36MHz（TIM2~7/USART2~3/SPI2/I2C）
                    ↓ APB2分频 ÷1
                PCLK2 = 72MHz（TIM1/USART1/SPI1/ADC）
                ```

                > ⚠️ **关键**：APB1最高36MHz，APB2最高72MHz。定时器时钟=APB×2（若APB分频≠1）。

                ### 生成代码

                - **Project Manager** → 设置工程名、路径、IDE类型（STM32CubeIDE）
                - **Code Generator** → 勾选"Generate peripheral initialization as a pair of .c/.h files"
                - 点击 **GENERATE CODE** → 自动在CubeIDE中打开

                ## 2.1.3 HAL库工程结构

                CubeMX生成的工程包含以下关键文件：

                | 文件 | 位置 | 说明 |
                |------|------|------|
                | `main.c` | Core/Src/ | 主程序，用户代码写在USER CODE区 |
                | `stm32f1xx_hal_msp.c` | Core/Src/ | 外设底层初始化（时钟/GPIO复用） |
                | `stm32f1xx_it.c` | Core/Src/ | 中断服务函数 |
                | `gpio.c/h` | Core/Src/Inc/ | GPIO初始化（CubeMX生成） |
                | `usart.c/h` | Core/Src/Inc/ | UART初始化（CubeMX生成） |
                | `stm32f1xx_hal.h` | Drivers/STM32F1xx_HAL_Driver/ | HAL库总头文件 |

                ## 2.1.4 用户代码保护区

                ```c
                /* USER CODE BEGIN 2 */
                /* ↑↑↑ 在这里写初始化代码 ↑↑↑ */
                HAL_TIM_Base_Start_IT(&htim2);
                /* USER CODE END 2 */

                while (1) {
                    /* USER CODE BEGIN WHILE */
                    /* ↑↑↑ 在这里写主循环代码 ↑↑↑ */
                    HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);
                    HAL_Delay(500);
                    /* USER CODE END WHILE */
                }
                ```

                > ⚠️ **铁律**：所有用户代码必须写在 `USER CODE BEGIN/END` 之间！
                > 重新生成代码时，CubeMX只保留这些区域的内容，其他地方会被覆盖。

                ## 2.1.5 ST-Link调试器使用

                ST-Link通过SWD（Serial Wire Debug）接口连接MCU，支持：
                - **程序下载**：编译后直接烧录到Flash
                - **断点调试**：设置断点，单步执行，查看变量
                - **实时监视**：Live Expressions窗口实时显示变量值
                - **串口查看**：通过SWO引脚输出printf（ITM调试）

                **SWD接口连接**（最少4根线）：
                ```
                ST-Link    STM32F103
                SWDIO  ──→  PA13
                SWDCLK ──→  PA14
                GND    ──→  GND
                3.3V   ──→  3.3V（可选，也可外部供电）
                ```
            """),
            mindmap_block("p2-ide-mm", {
                "text": "STM32开发工具链", "children": [
                    {"text": "CubeMX", "children": [
                        {"text": "引脚配置"},{"text": "时钟树设置"},{"text": "生成HAL框架"}]},
                    {"text": "CubeIDE", "children": [
                        {"text": "代码编辑"},{"text": "GCC编译"},{"text": "GDB调试"}]},
                    {"text": "HAL库", "children": [
                        {"text": "GPIO/RCC"},{"text": "UART/SPI/I2C"},{"text": "Timer/ADC"}]},
                    {"text": "ST-Link", "children": [
                        {"text": "SWD下载"},{"text": "断点调试"},{"text": "变量监视"}]},
                ]
            }),
            anim_block("p2-ide-anim", "STM32开发流程", [
                {"icon": "🔧", "t": "Step1：CubeMX图形配置",
                 "d": "选芯片→点引脚选功能→设置时钟树72MHz→Generate Code，零寄存器手写"},
                {"icon": "💻", "t": "Step2：CubeIDE编写逻辑",
                 "d": "在USER CODE区域调用HAL函数，如HAL_GPIO_TogglePin()控制LED闪烁"},
                {"icon": "⬇️", "t": "Step3：ST-Link下载",
                 "d": "SWD接口连接4根线（3.3V/GND/SWCLK/SWDIO），点击Run下载并自动运行"},
                {"icon": "🔍", "t": "Step4：调试与验证",
                 "d": "设断点、查看变量、单步执行、观察外设寄存器值，精确定位问题"},
            ]),
            ordering("p2-ide-i1", "⚙️ CubeMX工程创建步骤排序：", [
                "选择芯片型号STM32F103C8Tx",
                "在引脚视图配置PC13为GPIO_Output",
                "时钟树设置HCLK=72MHz",
                "点击Generate Code生成工程",
                "在CubeIDE的while(1)中写业务代码",
                "编译并通过ST-Link下载到开发板",
            ]),
            matching("p2-ide-i2", "GPIO模式与应用场景连线：", [
                ("推挽输出", "驱动LED灯"),
                ("上拉输入", "按键检测"),
                ("开漏输出", "I2C总线"),
                ("模拟模式", "ADC采样"),
                ("复用推挽", "UART发送"),
            ]),
            classification("p2-ide-i3", "代码分类：哪些写在USER CODE区？",
                {"usr": "USER CODE区（可写）", "gen": "生成代码区（禁改）"},
                [("u1", "HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);", "usr"),
                 ("u2", "__HAL_RCC_GPIOA_CLK_ENABLE();（Init内部）", "gen"),
                 ("u3", "int counter = 0;（用户变量）", "usr"),
                 ("u4", "SystemClock_Config();（时钟配置）", "gen"),
                 ("u5", "while(1)循环内业务逻辑", "usr"),
                 ("u6", "GPIO_InitTypeDef GPIO_InitStruct = {0};", "gen")]),
            memory_match("p2-ide-i4", "🃏 配对：HAL函数与功能", [
                ("HAL_GPIO_WritePin()", "设置GPIO引脚电平"),
                ("HAL_Delay()", "毫秒级阻塞延时"),
                ("HAL_UART_Transmit()", "串口发送数据"),
                ("HAL_TIM_Base_Start_IT()", "启动定时器中断"),
                ("HAL_ADC_Start()", "启动ADC转换"),
                ("HAL_I2C_Master_Transmit()", "I2C主机发数据"),
            ]),
            flashcard("p2-ide-i5", "📚 开发环境核心知识卡", [
                ("CubeMX的核心价值？", "图形化配置引脚+时钟，自动生成HAL初始化框架，无需手写寄存器"),
                ("系统时钟为何是72MHz？", "STM32F103最高主频，通过PLL对8MHz HSE晶振9倍频获得"),
                ("SWD接口需要几根线？", "4根：3.3V/GND/SWCLK/SWDIO（比JTAG的20Pin精简很多）"),
                ("HAL_Delay(500)的精度？", "依赖SysTick中断，精度约1ms，但不适合在高优先级中断中使用"),
            ]),
            code_block("p2-ide-code", "c", """\
                /* GPIO初始化（CubeMX生成，理解后不要修改） */
                static void MX_GPIO_Init(void) {
                  GPIO_InitTypeDef GPIO_InitStruct = {0};
                  __HAL_RCC_GPIOC_CLK_ENABLE();  /* 先使能时钟！ */

                  GPIO_InitStruct.Pin   = GPIO_PIN_13;
                  GPIO_InitStruct.Mode  = GPIO_MODE_OUTPUT_PP; /* 推挽 */
                  GPIO_InitStruct.Pull  = GPIO_NOPULL;
                  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
                  HAL_GPIO_Init(GPIOC, &GPIO_InitStruct);
                }

                /* 用户代码（main.c的while循环中）*/
                while (1) {
                  /* USER CODE BEGIN WHILE */
                  HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13); /* 翻转PC13 */
                  HAL_Delay(500);  /* 等待500ms */
                  /* USER CODE END WHILE */
                }
            """, "main.c", [3, 13, 15]),
            experiment_block("p2-ide-exp", "第一个LED闪烁程序全流程", [
                step(1, "安装CubeIDE", "从st.com下载STM32CubeIDE（约1.2GB），安装时选中ST-Link驱动组件。", chk=True),
                step(2, "新建STM32工程", "File→New→STM32 Project，搜索STM32F103C8Tx，填写工程名，点击Finish。", chk=True),
                step(3, "配置PC13输出", "在CubeMX引脚视图找PC13，选GPIO_Output，Push Pull，No Pull。", chk=False),
                step(4, "生成并编写代码", "Generate Code，在while(1)的USER CODE区添加TogglePin和Delay。",
                     "HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);\nHAL_Delay(500);", True),
                step(5, "编译下载", "Ctrl+B编译（0错误），连接ST-Link，点Run下载，观察LED闪烁。", chk=True),
            ], "板载LED以500ms周期闪烁"),
            summary_block("p2-ide-sum",
                ["CubeMX图形配置→生成HAL框架→CubeIDE写逻辑→ST-Link下载，这是标准流程",
                 "GPIO有8种模式：推挽输出最常用，上拉输入用于按键，开漏用于I2C",
                 "USER CODE区域是用户代码的保护区，不能在外面写！",
                 "时钟是STM32所有外设的基础，使用外设前必须先用RCC使能其时钟"],
                ["CubeMX重新生成代码后用户代码会消失吗？为什么？",
                 "推挽输出和开漏输出有何区别？"]),
        ],
        objectives=["搭建STM32开发环境", "掌握GPIO 8种模式", "完成第一个LED闪烁程序"],
        minutes=45, difficulty="beginner", tags=["ide", "cubemx", "hal", "gpio"]
    ))

    # 页2：C语言位操作
    pages.append(page(
        "p2-clang", "2.2 STM32编程C语言核心技巧",
        blocks=[
            text_block("p2-cl-text", """\
                # 2.2 STM32编程C语言特性

                ## 位操作（嵌入式最核心技能！）

                ```c
                uint32_t reg = 0x0000;
                reg |= (1 << 3);   /* 第3位置1 → 0x0008 */
                reg &= ~(1 << 3);  /* 第3位清0 → 0x0000 */
                reg ^= (1 << 3);   /* 第3位翻转→ 0x0008 */
                if (reg & (1 << 3)) { /* 测试第3位 */ }
                ```

                ## define宏定义：让代码自我说明

                ```c
                #define LED_PORT  GPIOC
                #define LED_PIN   GPIO_PIN_13
                HAL_GPIO_TogglePin(LED_PORT, LED_PIN);
                ```

                ## extern：多文件共享变量

                ```c
                /* file_a.c */  uint32_t g_tick = 0;  /* 定义 */
                /* file_b.c */  extern uint32_t g_tick; /* 声明后使用 */
                ```

                ## __weak：HAL回调扩展点

                ```c
                /* HAL库提供默认空实现 */
                __weak void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin) {}
                /* 用户重定义后，中断发生时自动调用用户版本 */
                void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin) {
                    HAL_GPIO_TogglePin(LED_PORT, LED_PIN);
                }
                ```

                ## 条件编译：调试/发布一键切换

                ```c
                #define DEBUG_MODE
                #ifdef DEBUG_MODE
                #  define LOG(m) printf("[DBG] " m)
                #else
                #  define LOG(m)
                #endif
                ```
            """),
            anim_block("p2-cl-anim", "C语言位操作与HAL回调", [
                {"icon": "🔢", "t": "位操作：精确控制寄存器每一位",
                 "d": "GPIO寄存器的每个bit对应一个引脚。|=置位、&=~清位、^=翻转，比直接赋值安全（不影响其他位）"},
                {"icon": "📌", "t": "宏定义：代码的自文档化",
                 "d": "#define LED_PIN GPIO_PIN_13。有意义的名字比魔法数字可读100倍，改硬件只需改一处"},
                {"icon": "🔄", "t": "__weak：软件扩展点",
                 "d": "HAL中断处理内部调用__weak回调，用户重定义同名函数即可接管中断，无需修改HAL源码"},
                {"icon": "🎛️", "t": "extern：模块间通信",
                 "d": "全局变量在.c文件定义，在.h文件用extern声明，实现多模块数据共享"},
            ]),
            fill_blank("p2-cl-i1", "填写C语言位操作代码：",
                ["将reg第5位置1：", {"blank": True, "answer": "reg |= (1 << 5)", "hint": "位或"},
                 "\n将reg第5位清0：", {"blank": True, "answer": "reg &= ~(1 << 5)", "hint": "取反后与"},
                 "\n翻转reg第5位：", {"blank": True, "answer": "reg ^= (1 << 5)", "hint": "异或"}]),
            matching("p2-cl-i2", "连线：C语言语法与STM32用途", [
                ("|=", "寄存器位置1"),
                ("&= ~(...)", "寄存器位清0"),
                ("^=", "引脚电平翻转"),
                ("#define", "引脚别名定义"),
                ("extern", "跨文件使用变量"),
                ("__weak", "可被覆盖的HAL回调"),
            ]),
            classification("p2-cl-i3", "寄存器操作安全性分类：",
                {"safe": "安全操作（不影响其他位）", "unsafe": "危险操作（覆盖其他位）"},
                [("s1", "GPIOA->ODR |= (1<<5);", "safe"),
                 ("s2", "GPIOA->ODR = 0xFFFF;", "unsafe"),
                 ("s3", "GPIOA->BSRR = GPIO_PIN_5;", "safe"),
                 ("s4", "RCC->APB2ENR = 0x04;", "unsafe"),
                 ("s5", "RCC->APB2ENR |= RCC_APB2ENR_IOPAEN;", "safe"),
                 ("s6", "GPIOA->CRL = 0x44444433;", "unsafe")]),
            memory_match("p2-cl-i4", "🃏 配对：C特性与代码示例", [
                ("置位操作", "reg |= (1 << n)"),
                ("清位操作", "reg &= ~(1 << n)"),
                ("HAL回调机制", "__weak void Callback(){}"),
                ("跨文件变量", "extern uint32_t g_tick;"),
                ("条件编译", "#ifdef DEBUG_MODE"),
                ("引脚宏定义", "#define LED_PIN GPIO_PIN_13"),
            ]),
            code_block("p2-cl-code", "c", """\
                #include "main.h"
                /* 宏定义硬件引脚别名 */
                #define LED_PORT  GPIOC
                #define LED_PIN   GPIO_PIN_13
                #define KEY_PORT  GPIOA
                #define KEY_PIN   GPIO_PIN_0

                extern uint32_t g_press_count;  /* 来自另一个.c文件 */

                /* 重定义__weak回调，响应外部中断 */
                void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin) {
                    if (GPIO_Pin == KEY_PIN) {
                        g_press_count++;
                        HAL_GPIO_TogglePin(LED_PORT, LED_PIN);
                    }
                }

                /* 位操作安全写法 */
                void safe_bit_ops(void) {
                    uint32_t reg = 0;
                    reg |=  (1 << 5);  /* 置位第5位 */
                    reg &= ~(1 << 3);  /* 清零第3位 */
                    reg ^=  (1 << 7);  /* 翻转第7位 */
                }
            """, "user_code.c", [11, 17, 18, 19]),
            summary_block("p2-cl-sum",
                ["位操作（|= 置位、&=~ 清位、^= 翻转）是嵌入式C的核心技能",
                 "#define宏定义引脚别名，提升可读性和可维护性",
                 "__weak是HAL库中断回调的实现基础，用户重定义即可接管",
                 "extern用于多文件共享全局变量，头文件声明+.c定义"],
                ["reg |= (1<<3) 和 reg = 1<<3 有什么不同？",
                 "为什么不能在中断服务函数中调用HAL_Delay()？"]),
            dh_block("p2-cl-dh",
                "C语言位操作是嵌入式与上层软件开发最大的区别。当你第一次用|=精确控制某个bit而不影响相邻bit时，你就真正进入嵌入式的世界了！",
                [{"q": "volatile关键字有什么用？",
                  "a": "告诉编译器不要优化该变量的访问，每次都从内存读取。中断标志位和外设寄存器必须加volatile，否则优化后代码逻辑失效。"},
                 {"q": "uint32_t和unsigned int有区别吗？",
                  "a": "uint32_t是固定32位，unsigned int依赖平台（16位MCU可能只有16位）。嵌入式开发中应始终使用uint8_t/uint16_t/uint32_t这类固定宽度类型。"}]),
        ],
        objectives=["掌握位操作置位/清位/翻转", "学会#define宏定义和__weak回调", "理解extern跨文件变量"],
        minutes=30, difficulty="beginner", tags=["c-language", "bit-operation", "macro"]
    ))
    return pages


# ─── 项目3：GPIO应用 ─────────────────────────────────────────────────
def build_p3_pages():
    pages = [
        quick_page(
            "p3-led-blink", "3.1 LED闪烁与流水灯",
            md_body="""\
                # 3.1 LED闪烁与流水灯

                ## LED驱动原理
                LED（发光二极管）具有单向导电性。驱动时需串联**限流电阻**（通常220Ω~1kΩ）。

                **电路连接**：`PA5 → 220Ω → LED正极 → LED负极 → GND`

                - 高电平(3.3V)：`(3.3V - 2V) / 220Ω ≈ 6mA`，LED亮
                - 低电平(0V)：无电流，LED灭

                ## HAL库控制LED

                ```c
                /* 点亮LED */
                HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_SET);

                /* 熄灭LED */
                HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_RESET);

                /* 翻转（闪烁专用） */
                HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_5);
                HAL_Delay(500);
                ```

                ## 流水灯实现思路
                通过数组存储引脚号，循环遍历依次点亮：

                ```c
                uint16_t leds[] = {GPIO_PIN_5, GPIO_PIN_6, GPIO_PIN_7, GPIO_PIN_8};
                for (int i = 0; i < 4; i++) {
                    HAL_GPIO_WritePin(GPIOA, leds[i], GPIO_PIN_SET);
                    HAL_Delay(200);
                    HAL_GPIO_WritePin(GPIOA, leds[i], GPIO_PIN_RESET);
                }
                ```

                ## 呼吸灯（软件PWM）
                通过改变高电平/低电平持续时间比例（占空比）实现亮度渐变：

                ```c
                for (int duty = 0; duty <= 100; duty++) {  /* 渐亮 */
                    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_SET);
                    delay_us(duty);  /* 高电平时间 */
                    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_RESET);
                    delay_us(100 - duty);  /* 低电平时间 */
                }
                ```
            """,
            mm_root={"text": "GPIO LED控制", "children": [
                {"text": "驱动原理", "children": [{"text": "限流电阻220Ω"}, {"text": "正向压降~2V"}, {"text": "工作电流~6mA"}]},
                {"text": "控制函数", "children": [{"text": "WritePin(SET/RESET)"}, {"text": "TogglePin()"}, {"text": "Delay(ms)"}]},
                {"text": "花样效果", "children": [{"text": "闪烁（Toggle+Delay）"}, {"text": "流水（数组遍历）"}, {"text": "呼吸（软PWM）"}]},
            ]},
            anim_scenes=[
                {"icon": "💡", "t": "LED驱动原理", "d": "PA5输出3.3V→经220Ω限流→LED正极，电流约6mA，LED发光。WritePin(SET)=高电平=亮，WritePin(RESET)=低电平=灭"},
                {"icon": "🌊", "t": "流水灯效果", "d": "数组存储4个引脚号，for循环依次WritePin(SET)→Delay(200ms)→WritePin(RESET)，实现流水效果"},
                {"icon": "😮‍💨", "t": "呼吸灯原理（软PWM）", "d": "固定100μs周期，通过改变高电平占比（duty%）控制亮度。duty=0%最暗，duty=100%最亮"},
                {"icon": "🔄", "t": "HAL_GPIO_TogglePin的妙用", "d": "翻转函数每次调用都切换电平状态，配合HAL_Delay实现精确闪烁，无需记录当前状态"},
            ],
            games=[
                ordering("p3-led-i1", "🔢 LED初始化步骤排序：", [
                    "使能GPIOA时钟（RCC）",
                    "配置PA5为推挽输出",
                    "调用HAL_GPIO_Init()",
                    "在while(1)中调用TogglePin+Delay",
                ]),
                fill_blank("p3-led-i2", "填写流水灯代码：",
                    ["uint16_t leds[] = {GPIO_PIN_5, GPIO_PIN_6, GPIO_PIN_7};",
                     "\nfor(int i=0; i<3; i++) {",
                     "\n  HAL_GPIO_WritePin(GPIOA, leds[i], ", {"blank": True, "answer": "GPIO_PIN_SET", "hint": "点亮"},
                     ");",
                     "\n  HAL_Delay(", {"blank": True, "answer": "200", "hint": "延时毫秒数"}, ");",
                     "\n  HAL_GPIO_WritePin(GPIOA, leds[i], ", {"blank": True, "answer": "GPIO_PIN_RESET", "hint": "熄灭"},
                     ");\n}"]),
                matching("p3-led-i3", "连线：GPIO函数与效果", [
                    ("HAL_GPIO_WritePin(GPIO_PIN_SET)", "点亮LED"),
                    ("HAL_GPIO_WritePin(GPIO_PIN_RESET)", "熄灭LED"),
                    ("HAL_GPIO_TogglePin()", "LED状态翻转"),
                    ("数组+for循环", "流水灯效果"),
                    ("软PWM占空比渐变", "呼吸灯效果"),
                ]),
                classification("p3-led-i4", "分类：以下代码实现哪种效果？",
                    {"blink": "闪烁", "flow": "流水", "breath": "呼吸"},
                    [("e1", "TogglePin(PA5); Delay(500);", "blink"),
                     ("e2", "for数组遍历，依次亮灭各LED", "flow"),
                     ("e3", "duty变量0→100渐变，高低电平比例改变", "breath"),
                     ("e4", "WritePin(SET); Delay(300); WritePin(RESET); Delay(300);", "blink"),
                     ("e5", "LEDs[i]依次点亮，前一个熄灭", "flow"),
                     ("e6", "Delay_us(duty) 和 Delay_us(100-duty)交替", "breath")]),
                memory_match("p3-led-i5", "🃏 LED控制关键参数配对", [
                    ("限流电阻值", "220Ω（常用）"),
                    ("LED正向压降", "约2V（红色）"),
                    ("工作电流", "5~20mA"),
                    ("STM32 GPIO高电平", "3.3V"),
                    ("TogglePin周期500ms", "每秒闪烁2次"),
                    ("软PWM周期", "100μs（10kHz）"),
                ]),
            ],
            quiz_ref="q-p3-led",
            sum_pts=["GPIO推挽输出驱动LED，必须串联限流电阻（220Ω）",
                     "流水灯=数组存引脚+for循环遍历依次亮灭",
                     "呼吸灯=软PWM，改变高低电平时间比例（占空比）",
                     "TogglePin()每次调用翻转电平，是实现闪烁的最简洁方式"],
            dh_script="GPIO是STM32与物理世界交互的第一道门。点亮第一颗LED，是每个嵌入式工程师的成年礼。看似简单的闪烁，背后涉及时钟使能、引脚配置、电流驱动能力……每一步都有其道理。",
            dh_faq=[{"q": "LED没亮怎么排查？",
                     "a": "检查顺序：1.限流电阻是否接了 2.LED正负极 3.引脚配置是否为推挽输出 4.是否使能了GPIOA时钟 5.用万用表测PA5电压"},
                    {"q": "可以不加限流电阻吗？",
                     "a": "绝对不可以！STM32引脚最大输出电流约25mA，无限流电阻时LED电流可能超过100mA，会烧毁LED甚至损坏芯片引脚。"}],
            objectives=["配置GPIO推挽输出驱动LED", "实现LED闪烁、流水灯、呼吸灯效果", "理解限流电阻的必要性"],
            minutes=40, tags=["gpio", "led", "output"],
            extra_blocks_before_exp=[

                # 保留 CodeBlock 内的 mermaid pane 即可）
                code_block("p3-led-code", "c", """\
                /* LED闪烁/流水灯/呼吸灯 完整示例 */
                #include "main.h"

                /* 1. LED闪烁（最简版）*/
                void led_blink(void) {
                    while (1) {
                        HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_5);
                        HAL_Delay(500);  /* 500ms周期 */
                    }
                }

                /* 2. 流水灯（4个LED：PA5~PA8）*/
                void led_flow(void) {
                    uint16_t pins[] = {GPIO_PIN_5, GPIO_PIN_6, GPIO_PIN_7, GPIO_PIN_8};
                    while (1) {
                        for (int i = 0; i < 4; i++) {
                            HAL_GPIO_WritePin(GPIOA, pins[i], GPIO_PIN_SET);
                            HAL_Delay(200);
                            HAL_GPIO_WritePin(GPIOA, pins[i], GPIO_PIN_RESET);
                        }
                    }
                }

                /* 3. 呼吸灯（软件PWM，TIM2 PWM模式更推荐）*/
                void led_breath(void) {
                    while (1) {
                        for (int duty=0; duty<=100; duty++) {
                            HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_SET);
                            delay_us(duty);       /* 高电平 */
                            HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_RESET);
                            delay_us(100-duty);   /* 低电平 */
                        }
                        for (int duty=100; duty>=0; duty--) {
                            HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_SET);
                            delay_us(duty);
                            HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_RESET);
                            delay_us(100-duty);
                        }
                    }
                }
            """, "led_demo.c", [8, 16, 28])],
            exp_steps=[
                step(1, "搭建LED电路", "用面包板连接：PA5→220Ω电阻→LED正极→LED负极→GND。", chk=True),
                step(2, "配置PA5为GPIO输出", "CubeMX中配置PA5为GPIO_Output，Push Pull，Low Speed。Generate Code。", chk=False),
                step(3, "实现LED闪烁", "while(1)中添加TogglePin和Delay(500)，编译下载，观察LED闪烁。",
                     "HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_5);\nHAL_Delay(500);", True),
                step(4, "实现流水灯", "定义引脚数组，用for循环依次点亮4个LED。", chk=True),
            ],

            # 注入 p3-led-blink-finale（finale-challenge）接管复习巩固区。
            # finale 内含 summaryPoints + summaryUnlockMap，把课后总结合并进游戏。
            outro_mode='finale-plus',
        ),
        quick_page(
            "p3-key-int", "3.2 按键扫描与外部中断",
            md_body="""\
                # 3.2 按键扫描与外部中断

                ## 按键电路原理

                按键一端接GND，另一端接MCU引脚（内部上拉10kΩ）：
                - **未按下**：引脚通过上拉电阻接3.3V → 读到高电平（1）
                - **按下**：引脚通GND → 读到低电平（0）

                ## 按键抖动问题

                机械按键在按下/释放时会产生10~20ms的抖动（多次高低跳变）。
                软件消抖：检测到低电平后延时20ms，再次确认。

                ```c
                if (HAL_GPIO_ReadPin(GPIOA, GPIO_PIN_0) == GPIO_PIN_RESET) {
                    HAL_Delay(20);  /* 消抖 */
                    if (HAL_GPIO_ReadPin(GPIOA, GPIO_PIN_0) == GPIO_PIN_RESET) {
                        /* 确认按键按下 */
                        HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);
                    }
                }
                ```

                ## 外部中断（EXTI）

                轮询（polling）浪费CPU，中断（interrupt）让CPU只在事件发生时响应：

                1. CubeMX：将PA0配置为**GPIO_EXTI0**，触发方式选**Falling Edge**（下降沿=按下）
                2. 使能NVIC中断（EXTI0_IRQn），设置优先级
                3. 实现回调函数：

                ```c
                void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin) {
                    if (GPIO_Pin == GPIO_PIN_0) {
                        HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);
                    }
                }
                ```

                ## 中断优先级

                STM32使用4位NVIC优先级：**抢占优先级（高位）** + **子优先级（低位）**。
                数字越小，优先级越高。不同外设应分配不同优先级。
            """,
            mm_root={"text": "按键与外部中断", "children": [
                {"text": "按键输入", "children": [{"text": "上拉输入模式"}, {"text": "低电平=按下"}, {"text": "软件消抖20ms"}]},
                {"text": "轮询方式", "children": [{"text": "ReadPin检测"}, {"text": "占用CPU"}, {"text": "适合简单场合"}]},
                {"text": "中断方式", "children": [{"text": "EXTI配置"}, {"text": "下降沿触发"}, {"text": "Callback回调"}]},
                {"text": "NVIC优先级", "children": [{"text": "抢占优先级"}, {"text": "子优先级"}, {"text": "数字小优先"}]},
            ]},
            anim_scenes=[
                {"icon": "🔘", "t": "按键电路：上拉输入原理", "d": "引脚接内部10kΩ上拉到3.3V，按键另一端接GND。未按=高电平，按下=低电平。避免引脚悬空（浮空）导致的随机值"},
                {"icon": "🔀", "t": "按键抖动与消抖", "d": "机械触点弹跳产生10~20ms的高低跳变。软件消抖：检测到低电平→等待20ms→再次确认，确保是稳定按键"},
                {"icon": "⚡", "t": "外部中断EXTI工作流程", "d": "按键触发下降沿→EXTI检测到→触发IRQ→NVIC路由到ISR→HAL调用Callback回调→用户代码执行"},
                {"icon": "📊", "t": "中断 vs 轮询", "d": "轮询：CPU不停地问'按了没？'，浪费资源。中断：按键主动打断CPU，CPU只在需要时响应，效率提升，CPU可做其他事"},
            ],
            games=[
                ordering("p3-key-i1", "外部中断配置步骤排序：", [
                    "CubeMX将PA0设为GPIO_EXTI0",
                    "选择触发方式：下降沿（Falling Edge）",
                    "在NVIC中使能EXTI0_IRQn并设优先级",
                    "Generate Code",
                    "实现HAL_GPIO_EXTI_Callback()",
                    "在回调中编写业务逻辑（翻转LED等）",
                ]),
                matching("p3-key-i2", "连线：按键状态与电平", [
                    ("按键未按下", "高电平（3.3V）"),
                    ("按键按下", "低电平（0V）"),
                    ("GPIO_PIN_SET", "1/高电平"),
                    ("GPIO_PIN_RESET", "0/低电平"),
                    ("下降沿触发", "按下时触发中断"),
                    ("上升沿触发", "释放时触发中断"),
                ]),
                classification("p3-key-i3", "分类：哪些属于中断方式的特点？",
                    {"irq": "中断方式优势", "poll": "轮询方式特点"},
                    [("k1", "CPU可在等待期间执行其他任务", "irq"),
                     ("k2", "在while(1)中不断ReadPin检查", "poll"),
                     ("k3", "事件驱动，响应更及时", "irq"),
                     ("k4", "代码逻辑简单直观", "poll"),
                     ("k5", "系统功耗更低", "irq"),
                     ("k6", "需要配置NVIC优先级", "irq")]),
                fill_blank("p3-key-i4", "填写外部中断回调函数：",
                    ["void HAL_GPIO_EXTI_Callback(", {"blank": True, "answer": "uint16_t GPIO_Pin", "hint": "参数类型和名称"},
                     ") {\n  if (GPIO_Pin == ", {"blank": True, "answer": "GPIO_PIN_0", "hint": "PA0对应的PIN号"},
                     ") {\n    HAL_GPIO_", {"blank": True, "answer": "TogglePin", "hint": "翻转引脚函数"},
                     "(GPIOC, GPIO_PIN_13);\n  }\n}"]),
                flashcard("p3-key-i5", "📚 按键与中断核心概念", [
                    ("为什么需要上拉电阻？", "避免引脚悬空（浮空），确保按键释放时引脚有确定的高电平状态"),
                    ("软件消抖的原理？", "检测到低电平后等待20ms让抖动平息，再次确认电平，两次都是低才算有效按键"),
                    ("__weak回调的作用？", "HAL库中断处理函数内部调用__weak标记的回调，用户重定义后自动替换"),
                    ("NVIC优先级数字越小越高吗？", "是的，0为最高优先级，数字越大优先级越低"),
                ]),
                interactive("p3-key-i6", {
                    "kind": "bit-flip",
                    "prompt": "配置 EXTI_IMR 使能 Line0 中断：将 MR0 位置 1",
                    "registerName": "EXTI->IMR", "initial": 0, "target": 1,
                    "explanation": "EXTI_IMR 的 bit0（MR0）控制 Line0 中断屏蔽，置1放行后按键中断才能到达 NVIC。",
                    "bitLabels": ["MR0", "MR1", "MR2", "MR3", "MR4", "MR5", "MR6", "MR7"]}),
                interactive("p3-key-i7", {
                    "kind": "code-cloze",
                    "prompt": "补全 HAL 库外部中断回调关键代码", "language": "c",
                    "template": "void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin)\n{\n  if (GPIO_Pin == {{pin}})\n  {\n    {{toggle}};\n  }\n}",
                    "blanks": [
                        {"id": "pin", "accepted": ["GPIO_PIN_0", "GPIO_Pin_0"], "rationale": "PA0 对应 GPIO_PIN_0"},
                        {"id": "toggle", "accepted": ["HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13)", "HAL_GPIO_TogglePin(GPIOC,GPIO_PIN_13)"], "rationale": "翻转 PC13 上的 LED"}],
                    "validate": "normalized"}),
                interactive("p3-key-i8", {
                    "kind": "timed-quiz",
                    "prompt": "外部中断快答 · 限时 60 秒", "seconds": 60,
                    "questions": [
                        {"id": "tq1", "stem": "STM32 的 EXTI Line0 对应哪些引脚的 Pin0？", "options": ["PA0/PB0/PC0 等", "只有 PA0", "任意引脚", "PA1"], "answer": 0},
                        {"id": "tq2", "stem": "机械按键消抖典型延时？", "options": ["10~20ms", "1μs", "1s", "100ms"], "answer": 0},
                        {"id": "tq3", "stem": "EXTI 下降沿触发意味着？", "options": ["电平从高到低", "电平从低到高", "保持高电平", "保持低电平"], "answer": 0},
                        {"id": "tq4", "stem": "清除 EXTI 挂起标志的 HAL 宏？", "options": ["__HAL_GPIO_EXTI_CLEAR_IT()", "HAL_GPIO_WritePin()", "HAL_NVIC_ClearPending()", "HAL_GPIO_Init()"], "answer": 0},
                        {"id": "tq5", "stem": "抢占优先级高的中断？", "options": ["可打断低抢占优先级中断", "只影响排队", "无区别", "子优先级更重要"], "answer": 0}]}),
                interactive("p3-key-i9", {
                    "kind": "signal-trace",
                    "prompt": "在波形上标记按键按下时 PA0 的下降沿和消抖采样点",
                    "waveform": [{"x": 0, "y": 1}, {"x": 5, "y": 1}, {"x": 5, "y": 0}, {"x": 5.5, "y": 1}, {"x": 6, "y": 0}, {"x": 7, "y": 0}, {"x": 25, "y": 0}, {"x": 25, "y": 1}, {"x": 26, "y": 1}, {"x": 50, "y": 1}],
                    "markers": [
                        {"id": "m1", "label": "首次下降沿", "x": 5, "tolerance": 1, "markerType": "falling-edge"},
                        {"id": "m2", "label": "消抖采样点", "x": 25, "tolerance": 2, "markerType": "sample"},
                        {"id": "m3", "label": "稳定低电平确认", "x": 7, "tolerance": 2, "markerType": "trigger"}],
                    "xUnit": "ms", "yLabel": "PA0 电平",
                    "explanation": "按键按下产生 5~6ms 抖动，消抖策略等待 20ms 后再采样确认。首次下降沿触发 EXTI，消抖后确认有效按下。"}),
            ],
            quiz_ref="q-p3-key",
            sum_pts=["按键接GND+内部上拉，未按=高电平，按下=低电平（负逻辑）",
                     "软件消抖：检测低电平→延时20ms→二次确认，过滤机械抖动",
                     "外部中断EXTI配置：引脚→EXTI模式→触发沿→NVIC使能→回调函数",
                     "中断优于轮询：CPU不被占用，系统响应更及时，功耗更低"],
            dh_script="按键是人机交互的起点，中断是嵌入式系统的灵魂。掌握这两者，你的STM32程序就从'只会跑循环'进化到'能响应外部世界'。",
            dh_faq=[{"q": "没有消抖为什么LED会闪多次？",
                     "a": "机械按键触点在50ms内可能产生数十次高低跳变，每次跳变都触发中断，所以LED会连续翻转多次。消抖就是过滤这段时间内的抖动信号。"},
                    {"q": "中断优先级该怎么设置？",
                     "a": "通常：HAL的SysTick优先级=0（最高），用户外设中断设1~5，低速设备如按键设5~10。相同优先级的中断不能互相抢占。"}],
            objectives=["实现按键输入检测（轮询和中断两种方式）", "理解软件消抖原理", "掌握EXTI外部中断配置"],
            minutes=45, tags=["gpio", "key", "exti", "interrupt"],
            extra_blocks_before_exp=[
                # 且垂直占用过大）。动态动画已完整呈现 EXTI 处理流程，奥卡姆去冗余。
                code_block("p3-key-code", "c", """\
                /* 按键检测：轮询+消抖 / 外部中断两种方式 */
                #include "main.h"

                /* ── 方式1：轮询+软件消抖 ── */
                void key_poll_task(void) {
                    /* PA0：内部上拉，按下=低电平 */
                    if (HAL_GPIO_ReadPin(GPIOA, GPIO_PIN_0) == GPIO_PIN_RESET) {
                        HAL_Delay(20);  /* 消抖：等待抖动平息 */
                        if (HAL_GPIO_ReadPin(GPIOA, GPIO_PIN_0) == GPIO_PIN_RESET) {
                            /* 确认有效按下，等待释放 */
                            while (HAL_GPIO_ReadPin(GPIOA, GPIO_PIN_0) == GPIO_PIN_RESET);
                            HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);  /* 翻转LED */
                        }
                    }
                }

                /* ── 方式2：外部中断回调（EXTI0） ── */
                /* CubeMX：PA0→GPIO_EXTI0，下降沿触发，NVIC使能 */
                void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin) {
                    if (GPIO_Pin == GPIO_PIN_0) {
                        /* ★ 此处不能调用HAL_Delay！ */
                        HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);
                        /* 记录时间戳用于防抖（在主循环中判断间隔）*/
                    }
                }
            """, "key_demo.c", [7, 16, 19]),
                # M10 · Finale Challenge 试点（闯关 + Boss 战）
                #   3 关：识图（热身） → 连线（进阶） → Boss 三题混合
                #   schema 详见 packages/types/src/manifest.ts FinaleChallengeBlockSchema
                finale_challenge_block(
                    bid="p3-key-int-finale",
                    title="外部中断综合挑战",
                    intro="刚学完按键 + EXTI，用 3 关挑战检验你掌握得怎么样",
                    hp_max=3,
                    bgm_track="tense",
                    trigger_label="挑战测验",
                    trigger_icon="🏆",
                    stages=[
                        finale_stage(
                            sid="fs-warmup",
                            title="第 1 关 · 概念识图",
                            subtitle="3 道单选 + 判断，快速热身",
                            time_limit_sec=60,
                            pass_threshold=0.6,
                            questions=[
                                fq_quiz_single(
                                    "fq-w1",
                                    stem="EXTI 的全称是？",
                                    options=[
                                        ("a", "External Interrupt（外部中断）"),
                                        ("b", "Extra Interrupt（额外中断）"),
                                        ("c", "Extended Interface（扩展接口）"),
                                        ("d", "Event Trigger Index（事件触发索引）"),
                                    ],
                                    answer="a",
                                    score=100,
                                    difficulty="easy",
                                    hint="External 表示\"来自芯片外部的信号\"",
                                ),
                                fq_quiz_tf(
                                    "fq-w2",
                                    stem="STM32 中 NVIC 优先级数字越小，优先级越高。",
                                    answer=True,
                                    score=80,
                                    difficulty="easy",
                                ),
                                fq_quiz_single(
                                    "fq-w3",
                                    stem="按键接 GND + 内部上拉，未按下时 GPIO 读到的电平是？",
                                    options=[
                                        ("a", "高电平"),
                                        ("b", "低电平"),
                                        ("c", "悬空"),
                                        ("d", "不确定"),
                                    ],
                                    answer="a",
                                    score=100,
                                    difficulty="easy",
                                ),
                            ],
                        ),
                        finale_stage(
                            sid="fs-advance",
                            title="第 2 关 · 连线 + 多选",
                            subtitle="把概念与说明连起来",
                            time_limit_sec=75,
                            pass_threshold=0.7,
                            questions=[
                                fq_int_matching(
                                    "fq-a1",
                                    prompt="把名词与作用连起来",
                                    pairs=[
                                        ("EXTI", "外部信号边沿检测"),
                                        ("NVIC", "中断优先级与路由"),
                                        ("HAL_GPIO_EXTI_Callback", "用户业务回调"),
                                        ("软件消抖", "过滤机械抖动"),
                                    ],
                                    score=140,
                                    difficulty="medium",
                                ),
                                fq_quiz_multi(
                                    "fq-a2",
                                    stem="下列关于\"中断 vs 轮询\"的说法正确的有（多选）",
                                    options=[
                                        ("a", "中断响应通常比轮询更及时"),
                                        ("b", "中断不占用 CPU 主循环时间"),
                                        ("c", "轮询代码逻辑通常更简单"),
                                        ("d", "中断回调里可以放任意耗时任务"),
                                    ],
                                    answers=["a", "b", "c"],
                                    score=160,
                                    difficulty="medium",
                                    hint="回调里不能放 HAL_Delay 或长循环",
                                ),
                            ],
                        ),
                        finale_stage(
                            sid="fs-boss",
                            title="Boss · 综合实战",
                            subtitle="3 题混合：填空 + 排序 + 判断",
                            time_limit_sec=90,
                            pass_threshold=0.7,
                            questions=[
                                fq_quiz_fill(
                                    "fq-b1",
                                    stem="按键消抖典型延时为 ___ 毫秒（填数字）",
                                    answers=["20", "20ms"],
                                    score=160,
                                    difficulty="hard",
                                ),
                                fq_int_ordering(
                                    "fq-b2",
                                    prompt="按 EXTI 中断的真实流转顺序排列：",
                                    items=[
                                        "PA0 下降沿",
                                        "EXTI 检测到匹配触发沿",
                                        "NVIC 路由到 CPU",
                                        "EXTI0_IRQHandler 清标志",
                                        "HAL_GPIO_EXTI_Callback 翻转 LED",
                                        "返回主循环",
                                    ],
                                    score=200,
                                    difficulty="hard",
                                ),
                                fq_quiz_tf(
                                    "fq-b3",
                                    stem="HAL_GPIO_EXTI_Callback 中调用 HAL_Delay(500) 是合规的实现方式。",
                                    answer=False,
                                    score=120,
                                    difficulty="hard",
                                    hint="ISR 中不应做长时间阻塞操作",
                                ),
                            ],
                        ),
                    ],
                )],
            exp_steps=[
                step(1, "搭建按键电路", "PA0→按键→GND。使用内部上拉（Pull-Up），无需外接电阻。", chk=True),
                step(2, "轮询方式实现", "while(1)中用ReadPin检测PA0，低电平时延时20ms消抖后翻转LED。", chk=True),
                step(3, "配置外部中断", "CubeMX：PA0→GPIO_EXTI0→Falling Edge，NVIC使能，Generate Code。", chk=False),
                step(4, "实现中断回调", "实现HAL_GPIO_EXTI_Callback，在PA0触发时翻转LED，验证中断比轮询响应更及时。",
                     "void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin) {\n  if(GPIO_Pin==GPIO_PIN_0)\n    HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);\n}", True),
            ]
        ),
    ]
    # M11 子-A · P3 章节播报脚本注入（≥15 分钟/节，单一事实源在 inject_narration_p3_*.py）
    # 设计：数据与代码分离，chapters 路径与 manifest patch 路径共用同一份 dict
    try:
        from manifest.inject_narration_p3_key_int import apply_to_pages as _apply_p3_key_int_narration
        _apply_p3_key_int_narration(pages)
    except ImportError:
        # 子-A 未部署时静默跳过，保持 chapters 仍可独立 import
        pass
    try:
        from manifest.inject_narration_p3_led_blink import apply_to_pages as _apply_p3_led_blink_narration
        _apply_p3_led_blink_narration(pages)
    except ImportError:
        pass
    return pages


