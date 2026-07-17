# 额外子页面（build_ch*_extra_pages）—— by chapters/extras.py
"""
build_ch1/ch3/ch6/ch9/ch12 extra pages.
"""
# -*- coding: utf-8 -*-
import textwrap, inspect

def _t(bid, md): return {"id": bid, "kind": "text", "markdown": inspect.cleandoc(md)}
def _code(bid, lang, code, fname=None):
    b = {"id": bid, "kind": "code", "language": lang, "code": textwrap.dedent(code)}
    if fname: b["filename"] = fname
    return b
def _fc(bid, prompt, cards):
    return {"id": bid, "kind": "interactive", "spec": {"kind": "flashcard", "prompt": prompt,
            "cards": [{"id": f"fc{i}", "front": f, "back": b} for i, (f, b) in enumerate(cards)]}}
def _match(bid, prompt, pairs):
    return {"id": bid, "kind": "interactive", "spec": {"kind": "matching", "prompt": prompt,
            "pairs": [{"left": l, "right": r} for l, r in pairs]}}
def _table(bid, cap, headers, rows):
    return {"id": bid, "kind": "table", "caption": cap, "headers": headers, "rows": rows}
def _sum(bid, pts, qs):
    return {"id": bid, "kind": "summary", "keyPoints": pts, "reviewQuestions": qs}
def _page(pid, title, blocks):
    return {"id": pid, "title": title, "template": "T-concept", "blocks": blocks}

# ═══════════════════════════════════════════════════════════
# 第1章  认识单片机 — 额外子页面
# ═══════════════════════════════════════════════════════════

def build_ch1_extra_pages():
    """第1章扩充：1.2节 + 1.3节各增加一个深化页"""

    # 1.2节 - 深化：单片机内部结构详解
    p1_arch = _page("p1-arch", "1.2 · 进阶｜单片机内部结构详解", [
        _t("p1arch-t1", """\
            ## 1.2 · 进阶｜STM32F103x 内部结构精讲

            ### 总线架构
            STM32F103x 采用 **ARM Cortex-M3** 内核，总线系统如下：

            | 总线名称 | 位宽 | 连接外设 | 最高频率 |
            |---------|------|---------|---------|
            | ICode | 32-bit | Flash指令缓存 | 72 MHz |
            | DCode | 32-bit | Flash数据访问 | 72 MHz |
            | System | 32-bit | SRAM / 外设 | 72 MHz |
            | AHB | 32-bit | DMA / GPIO / RCC | 72 MHz |
            | APB1 | 32-bit | TIM2~7 / UART / SPI2 / I2C | 36 MHz |
            | APB2 | 32-bit | GPIO / ADC / TIM1 / SPI1 | 72 MHz |

            > ⚠️ **注意**：APB1 最高 36 MHz，但连接到 APB1 的定时器实际时钟 = APB1×2 = 72 MHz（当 APB1 分频≠1时）。

            ### 存储器映射（Memory Map）
            Cortex-M3 采用统一的 4GB 线性地址空间：

            | 地址范围 | 区域 | 容量 |
            |---------|------|-----|
            | 0x0000_0000 ~ 0x07FF_FFFF | Flash / Boot ROM | 128 MB |
            | 0x0800_0000 ~ 0x0801_FFFF | 用户 Flash（程序区） | 128 KB |
            | 0x2000_0000 ~ 0x2000_4FFF | SRAM | 20 KB |
            | 0x4000_0000 ~ 0x4001_FFFF | APB1 外设寄存器 | 512 KB |
            | 0x4001_0000 ~ 0x4001_3FFF | APB2 外设寄存器 | 256 KB |
            | 0xE000_E000 ~ 0xE000_EFFF | NVIC / SysTick（Cortex 内核） | 4 KB |

            ### 时钟树（Clock Tree）
            ```
            HSE(外部晶振 8MHz)
              └─ PLL(×9) ─→ SYSCLK = 72 MHz
                              ├─ AHB(÷1) ─→ HCLK = 72 MHz ─→ Cortex-M3 内核/DMA/Flash
                              ├─ APB1(÷2) ─→ PCLK1 = 36 MHz ─→ TIM2~7, USART2~5, SPI2, I2C
                              └─ APB2(÷1) ─→ PCLK2 = 72 MHz ─→ GPIO, ADC, TIM1, SPI1, USART1
            ```

            **CubeMX 时钟配置路径**：
            Clock Configuration 标签页 → 拖动滑块或直接输入目标频率。
        """),
        _table("p1arch-tbl", "STM32F103C8T6 与 F103ZET6 资源对比",
            ["参数", "F103C8T6（小容量）", "F103ZET6（大容量）"],
            [
                ["Flash", "64 KB", "512 KB"],
                ["SRAM", "20 KB", "64 KB"],
                ["GPIO", "37个", "112个"],
                ["定时器", "TIM1~4", "TIM1~8"],
                ["ADC", "ADC1（10通道）", "ADC1~3（21通道）"],
                ["封装", "LQFP-48", "LQFP-144"],
                ["适用场景", "学习开发板（Blue Pill）", "工业产品开发"],
            ]
        ),
        _fc("p1arch-fc", "单片机结构记忆卡", [
            ("Cortex-M3 哈佛架构的含义？", "指令存储器和数据存储器分开访问：ICode总线取指令，DCode总线读写数据，两者并行不冲突"),
            ("APB1 上的定时器实际时钟是多少？", "72 MHz（APB1=36MHz，但定时器时钟=APB1×2=72MHz，前提是APB1分频系数≠1）"),
            ("Flash 从哪个地址开始？", "0x0800_0000，这也是程序的入口地址（向量表基地址）"),
            ("NVIC 的作用是什么？", "嵌套向量中断控制器，管理所有外部中断和内部异常的优先级与使能"),
        ]),
    ])

    # 1.3节 - 深化：开发流程与HAL库架构
    p1_flow = _page("p1-devflow", "1.3 · 进阶｜开发流程与HAL库架构", [
        _t("p1flow-t1", """\
            ## 1.3 · 进阶｜STM32 开发完整流程

            ### HAL 库架构层次
            ST 提供三种编程方式，从底层到高层：

            | 方式 | 抽象程度 | 可移植性 | 开发效率 | 推荐场景 |
            |-----|---------|---------|---------|---------|
            | 寄存器直接访问 | 最低 | 差 | 低 | 极致性能优化 |
            | LL 库（Low Layer） | 中等 | 一般 | 中 | 需要精确控制时序 |
            | **HAL 库** | **最高** | **好** | **高** | **教学 + 产品开发** |

            HAL 库文件命名规律：
            `stm32f1xx_hal_gpio.c` → GPIO 模块的 HAL 实现
            `stm32f1xx_hal_gpio.h` → GPIO 模块的 HAL 接口

            ### 标准开发流程（CubeMX → 代码 → 调试）

            ```
            ① 硬件设计
               └─ 原理图 → PCB → 制板焊接

            ② CubeMX 配置
               ├─ 选择芯片型号（STM32F103xx）
               ├─ 引脚功能分配（点击引脚图）
               ├─ 时钟树配置（HSE + PLL → 72MHz）
               ├─ 外设参数设置（波特率、分频系数等）
               └─ 生成代码（选择 CubeIDE 工程格式）

            ③ 编写应用代码
               ├─ 在 USER CODE BEGIN/END 注释之间写代码
               ├─ 禁止修改生成代码区域（再生成会覆盖）
               └─ 调用 HAL_xxx() 系列函数

            ④ 编译与烧录
               ├─ Build → 无错误
               ├─ ST-Link 连接（SWD：SWCLK + SWDIO + 3.3V + GND）
               └─ Run/Debug → 程序烧录到 Flash

            ⑤ 调试
               ├─ 断点 → 单步 → 查看变量
               ├─ SWV（Serial Wire Viewer）：实时数据追踪
               └─ 串口 printf → 打印调试信息
            ```

            ### USER CODE 区域规则
            CubeMX 生成的代码用特殊注释标记用户代码区：
        """),
        _code("p1flow-code", "c", """\
            /* USER CODE BEGIN Includes */
            #include "my_sensor.h"   // ← 这里加自己的头文件
            /* USER CODE END Includes */

            /* USER CODE BEGIN 0 */
            // 全局变量 / 函数声明
            uint32_t my_counter = 0;
            /* USER CODE END 0 */

            int main(void) {
              HAL_Init();
              SystemClock_Config();
              MX_GPIO_Init();   // CubeMX 生成，不要修改

              /* USER CODE BEGIN WHILE */
              while (1) {
                my_counter++;   // ← 用户逻辑写在这里
                HAL_Delay(1000);
              }
              /* USER CODE END WHILE */
            }
        """, fname="main.c"),
        _sum("p1flow-sum",
            ["STM32 HAL 库提供最高抽象层，推荐初学者使用",
             "CubeMX → 生成代码 → USER CODE 区域 → 编译烧录 是标准流程",
             "USER CODE BEGIN/END 之间的代码在重新生成时不会被覆盖",
             "SWD 四线（SWCLK/SWDIO/3.3V/GND）是最常用的烧录调试接口"],
            ["HAL库与LL库的主要区别是什么？",
             "CubeMX重新生成代码后，用户代码会丢失吗？为什么？",
             "APB1时钟36MHz的定时器，实际运行频率是多少？"]
        ),
    ])

    return p1_arch, p1_flow

# ═══════════════════════════════════════════════════════════
# 第3章  GPIO应用 — 额外子页面
# ═══════════════════════════════════════════════════════════

def build_ch3_extra_pages():
    """第3章扩充：3.2节 + 3.3节各增加一个代码实战页"""

    p3_led_code = _page("p3-led-code", "3.2 · 进阶｜LED实验代码精讲", [
        _t("p3lc-t1", """\
            ## 3.2 · 进阶｜LED 控制 HAL 库函数详解

            ### GPIO 初始化结构体
            CubeMX 生成 `MX_GPIO_Init()`，理解它的每个字段：
        """),
        _code("p3lc-code1", "c", """\
            // CubeMX 生成的 GPIO 初始化代码
            static void MX_GPIO_Init(void) {
              GPIO_InitTypeDef GPIO_InitStruct = {0};

              /* GPIO Ports Clock Enable */
              __HAL_RCC_GPIOC_CLK_ENABLE();  // ① 使能时钟（必须！）
              __HAL_RCC_GPIOA_CLK_ENABLE();

              /* PA5 → LED （推挽输出） */
              GPIO_InitStruct.Pin   = GPIO_PIN_5;          // ② 引脚号
              GPIO_InitStruct.Mode  = GPIO_MODE_OUTPUT_PP; // ③ 推挽输出
              GPIO_InitStruct.Pull  = GPIO_NOPULL;         // ④ 无上下拉
              GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW; // ⑤ 低速（2MHz）
              HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

              /* 初始状态：LED 熄灭（低电平） */
              HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_RESET);
            }
        """, fname="gpio.c"),
        _t("p3lc-t2", """\
            ### 常用 HAL GPIO 函数

            | 函数 | 功能 | 示例 |
            |-----|------|------|
            | `HAL_GPIO_WritePin(GPIO, PIN, STATE)` | 写引脚电平 | `HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_SET)` |
            | `HAL_GPIO_ReadPin(GPIO, PIN)` | 读引脚电平 | `if(HAL_GPIO_ReadPin(GPIOC, GPIO_PIN_13)==GPIO_PIN_RESET)` |
            | `HAL_GPIO_TogglePin(GPIO, PIN)` | 翻转引脚电平 | `HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_5)` |

            ### 流水灯实现（3 个 LED）
        """),
        _code("p3lc-code2", "c", """\
            // 流水灯：PA5, PA6, PA7 各亮 500ms
            #define LED1_PIN  GPIO_PIN_5
            #define LED2_PIN  GPIO_PIN_6
            #define LED3_PIN  GPIO_PIN_7
            #define LED_PORT  GPIOA

            void running_light_demo(void) {
                uint16_t leds[] = {LED1_PIN, LED2_PIN, LED3_PIN};
                for (int i = 0; i < 3; i++) {
                    HAL_GPIO_WritePin(LED_PORT, LED1_PIN|LED2_PIN|LED3_PIN, GPIO_PIN_RESET); // 全灭
                    HAL_GPIO_WritePin(LED_PORT, leds[i], GPIO_PIN_SET);  // 点亮第 i 个
                    HAL_Delay(500);
                }
            }

            // 呼吸灯（需配合 PWM，此处用软件模拟渐变）
            void breath_light_software(void) {
                for (int bright = 0; bright <= 100; bright += 5) {
                    HAL_GPIO_WritePin(LED_PORT, LED1_PIN, GPIO_PIN_SET);
                    HAL_Delay(bright);        // 亮 = bright ms
                    HAL_GPIO_WritePin(LED_PORT, LED1_PIN, GPIO_PIN_RESET);
                    HAL_Delay(100 - bright);  // 暗 = (100-bright) ms
                }
            }
        """, fname="led_demo.c"),
        _match("p3lc-match", "GPIO 函数与功能对应", [
            ("HAL_GPIO_WritePin(..., GPIO_PIN_SET)", "置高电平"),
            ("HAL_GPIO_WritePin(..., GPIO_PIN_RESET)", "置低电平"),
            ("HAL_GPIO_TogglePin(...)", "电平翻转"),
            ("HAL_GPIO_ReadPin(...)", "读取当前电平"),
            ("__HAL_RCC_GPIOA_CLK_ENABLE()", "使能GPIO时钟"),
        ]),
    ])

    p3_exti_code = _page("p3-exti-code", "3.3 · 进阶｜外部中断EXTI代码实战", [
        _t("p3ec-t1", """\
            ## 3.3 · 进阶｜外部中断（EXTI）完整实现

            ### EXTI 工作原理
            STM32F103x 有 16 个外部中断线（EXTI0~15），每条线对应所有端口的同一引脚号：
            - EXTI0 ← PA0 / PB0 / PC0 / ... （同一时刻只能用一个端口）
            - EXTI13 ← PA13 / PB13 / **PC13**（开发板 USER 按键通常接 PC13）

            ### 配置步骤（CubeMX）
            1. 点击 PC13 → 选择 `GPIO_EXTI13`
            2. GPIO 标签页 → PC13 → Pull-up，Trigger: `Falling edge`（按键按下产生下降沿）
            3. NVIC 标签页 → 使能 `EXTI line[15:10] interrupts`，Priority: 2/2
            4. 生成代码
        """),
        _code("p3ec-code1", "c", """\
            // 自动生成的 EXTI 配置（MX_GPIO_Init 内）
            GPIO_InitStruct.Pin  = GPIO_PIN_13;
            GPIO_InitStruct.Mode = GPIO_MODE_IT_FALLING;  // 下降沿触发
            GPIO_InitStruct.Pull = GPIO_PULLUP;            // 上拉（未按=高电平）
            HAL_GPIO_Init(GPIOC, &GPIO_InitStruct);

            HAL_NVIC_SetPriority(EXTI15_10_IRQn, 2, 0);  // 抢占2 子优先级0
            HAL_NVIC_EnableIRQ(EXTI15_10_IRQn);
        """, fname="gpio_exti_init.c"),
        _code("p3ec-code2", "c", """\
            // stm32f1xx_it.c 中的 IRQ Handler（HAL 自动生成）
            void EXTI15_10_IRQHandler(void) {
                HAL_GPIO_EXTI_IRQHandler(GPIO_PIN_13);  // 清中断标志 + 调用回调
            }

            // main.c 或 gpio.c 中实现回调函数
            void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin) {
                if (GPIO_Pin == GPIO_PIN_13) {
                    // 按键消抖：检测到下降沿后延时再确认
                    HAL_Delay(20);  // ⚠️ 中断中用 HAL_Delay 需确保 SysTick 优先级最高
                    if (HAL_GPIO_ReadPin(GPIOC, GPIO_PIN_13) == GPIO_PIN_RESET) {
                        // 确认按键按下
                        HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_5);  // 翻转 LED
                        static uint32_t cnt = 0;
                        cnt++;
                        // 可在此设置标志位，主循环检测处理
                    }
                }
            }

            /* ===== 推荐做法：中断中只设标志位，主循环处理 ===== */
            volatile uint8_t key_flag = 0;

            void HAL_GPIO_EXTI_Callback_v2(uint16_t GPIO_Pin) {
                if (GPIO_Pin == GPIO_PIN_13) {
                    key_flag = 1;  // 仅设标志，不做耗时操作
                }
            }

            // main.c while(1)
            while (1) {
                if (key_flag) {
                    key_flag = 0;
                    HAL_Delay(20);  // 消抖放主循环
                    if (HAL_GPIO_ReadPin(GPIOC, GPIO_PIN_13) == GPIO_PIN_RESET) {
                        HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_5);
                    }
                }
            }
        """, fname="exti_callback.c"),
        _sum("p3ec-sum",
            ["EXTI13 对应 PA13/PB13/PC13，同时只能用其中一个端口",
             "中断回调 HAL_GPIO_EXTI_Callback 中避免长时间阻塞",
             "推荐模式：中断只设标志位 key_flag，主循环读取并处理",
             "NVIC 优先级：SysTick 必须最高（0），否则 HAL_Delay 在中断中会卡死"],
            ["为什么按键需要上拉电阻？", "EXTI Callback 中能调用 HAL_Delay 吗？", "多个按键如何用同一个回调区分？"]
        ),
    ])

    return p3_led_code, p3_exti_code


# ═══════════════════════════════════════════════════════════
# 第6章  串口通信 — 额外子页面
# ═══════════════════════════════════════════════════════════

def build_ch6_extra_pages():
    """第6章扩充：6.1 + 6.2节各增加代码实战页"""

    p6_uart_code = _page("p6-uart-code", "6.1 · 进阶｜UART收发代码精讲", [
        _t("p6uc-t1", """\
            ## 6.1 · 进阶｜UART 发送与 printf 重定向实战

            ### UART 发送三种方式对比

            | 方式 | 函数 | 特点 |
            |-----|------|------|
            | 轮询发送 | `HAL_UART_Transmit()` | 阻塞，简单，适合少量数据 |
            | 中断发送 | `HAL_UART_Transmit_IT()` | 非阻塞，发送完产生中断 |
            | DMA发送 | `HAL_UART_Transmit_DMA()` | 非阻塞，CPU零参与，高效 |
        """),
        _code("p6uc-code1", "c", """\
            // ① CubeMX 配置：USART1, Mode=Asynchronous, Baud=115200, 8N1
            // 生成代码后自动创建 huart1 句柄

            /* ── 方法1：轮询发送字符串 ── */
            char buf[] = "Hello STM32!\\r\\n";
            HAL_UART_Transmit(&huart1, (uint8_t*)buf, strlen(buf), HAL_MAX_DELAY);

            /* ── 方法2：printf 重定向（推荐！） ── */
            // 在 main.c 或 usart.c 中添加：
            #include <stdio.h>

            // 重写 fputc（GCC 工具链用 _write）
            int __io_putchar(int ch) {
                HAL_UART_Transmit(&huart1, (uint8_t*)&ch, 1, 100);
                return ch;
            }
            // 或者使用 write 重定向（更通用）
            int _write(int file, char *ptr, int len) {
                HAL_UART_Transmit(&huart1, (uint8_t*)ptr, len, HAL_MAX_DELAY);
                return len;
            }

            // 之后就可以用 printf：
            printf("温度: %.2f°C, 湿度: %.1f%%\\r\\n", temp, humi);
            printf("计数: %lu\\r\\n", HAL_GetTick());
        """, fname="uart_printf.c"),
        _code("p6uc-code2", "c", """\
            /* ── 接收：轮询模式（阻塞，不推荐实际使用）── */
            uint8_t rx_byte;
            HAL_UART_Receive(&huart1, &rx_byte, 1, 100);  // 超时 100ms

            /* ── 接收：中断模式（推荐）── */
            uint8_t rx_buf[64];
            uint8_t rx_index = 0;
            uint8_t rx_tmp;  // 单字节缓冲

            // 1. 在 MX_USART1_UART_Init() 后启动中断接收
            HAL_UART_Receive_IT(&huart1, &rx_tmp, 1);

            // 2. 每收到1字节触发回调
            void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart) {
                if (huart->Instance == USART1) {
                    if (rx_tmp == '\\n' || rx_index >= 63) {
                        rx_buf[rx_index] = '\\0';
                        // TODO: 解析 rx_buf 中的命令
                        rx_index = 0;
                    } else {
                        rx_buf[rx_index++] = rx_tmp;
                    }
                    // 关键：重新启动接收，否则只收一次！
                    HAL_UART_Receive_IT(&huart1, &rx_tmp, 1);
                }
            }
        """, fname="uart_receive.c"),
        _match("p6uc-match", "UART 相关知识匹配", [
            ("波特率 115200", "每秒传输 115200 个二进制位"),
            ("8N1 格式", "8位数据位 + 无奇偶校验 + 1位停止位"),
            ("HAL_UART_Receive_IT", "中断模式接收，非阻塞"),
            ("__io_putchar 重写", "printf 重定向到 UART"),
            ("回调中再次调用 Receive_IT", "使中断接收持续工作"),
        ]),
    ])

    return (p6_uart_code,)


# ═══════════════════════════════════════════════════════════
# 第9章  环境监测 — 额外子页面
# ═══════════════════════════════════════════════════════════

def build_ch9_extra_pages():
    """第9章扩充：I2C 协议详解页"""

    p9_i2c = _page("p9-i2c-proto", "9.2 · 进阶｜I2C协议与传感器驱动", [
        _t("p9i2c-t1", """\
            ## 9.2 · 进阶｜I2C 总线协议详解

            ### I2C 帧格式
            I2C 是两线串行总线：**SDA**（数据）+ **SCL**（时钟），支持多主机多从机。

            一次完整的 I2C 写事务：
            ```
            START → [设备地址(7bit) + W(0)] → ACK → [寄存器地址] → ACK → [数据] → ACK → STOP
            ```

            一次完整的 I2C 读事务：
            ```
            START → [设备地址 + W] → ACK → [寄存器地址] → ACK →
            RE-START → [设备地址 + R(1)] → ACK → [数据] → NACK → STOP
            ```

            > 💡 **HAL 库地址要左移1位**：I2C 7位地址在传输时与 R/W 位组成8位，HAL 函数要求传入左移后的8位地址。
            > 例：BH1750 地址 0x23 → `HAL_I2C_Master_Transmit(&hi2c1, 0x23<<1, ...)`

            ### 三个传感器的驱动代码
        """),
        _code("p9i2c-code1", "c", """\
            /* ══ BH1750 光照传感器 (I2C 0x23) ══ */
            #define BH1750_ADDR  (0x23 << 1)   // 7位地址左移
            #define BH1750_HRES  0x10           // High-Resolution 模式命令

            uint16_t BH1750_ReadLux(void) {
                uint8_t cmd = BH1750_HRES;
                uint8_t data[2];

                // 发送测量命令
                HAL_I2C_Master_Transmit(&hi2c1, BH1750_ADDR, &cmd, 1, 100);
                HAL_Delay(180);   // H-Res 模式需要 120ms（建议等 180ms）

                // 读取2字节结果
                HAL_I2C_Master_Receive(&hi2c1, BH1750_ADDR, data, 2, 100);

                // 计算 lux：(高字节<<8 | 低字节) / 1.2
                uint16_t raw = ((uint16_t)data[0] << 8) | data[1];
                return (uint16_t)(raw / 1.2f);
            }
        """, fname="bh1750.c"),
        _code("p9i2c-code2", "c", """\
            /* ══ HDC1080 温湿度传感器 (I2C 0x40) ══ */
            #define HDC1080_ADDR  (0x40 << 1)
            #define HDC1080_TEMP  0x00
            #define HDC1080_HUMI  0x01
            #define HDC1080_CONF  0x02

            void HDC1080_Init(void) {
                // 配置寄存器：14位精度，独立温湿度测量
                uint8_t conf[3] = {HDC1080_CONF, 0x00, 0x00};
                HAL_I2C_Master_Transmit(&hi2c1, HDC1080_ADDR, conf, 3, 100);
            }

            float HDC1080_ReadTemp(void) {
                uint8_t reg = HDC1080_TEMP;
                uint8_t data[2];
                HAL_I2C_Master_Transmit(&hi2c1, HDC1080_ADDR, &reg, 1, 100);
                HAL_Delay(7);   // 14位测量需要 6.35ms
                HAL_I2C_Master_Receive(&hi2c1, HDC1080_ADDR, data, 2, 100);
                uint16_t raw = ((uint16_t)data[0] << 8) | data[1];
                return (raw / 65536.0f) * 165.0f - 40.0f;  // 公式：T = raw/2^16 * 165 - 40
            }

            float HDC1080_ReadHumi(void) {
                uint8_t reg = HDC1080_HUMI;
                uint8_t data[2];
                HAL_I2C_Master_Transmit(&hi2c1, HDC1080_ADDR, &reg, 1, 100);
                HAL_Delay(7);
                HAL_I2C_Master_Receive(&hi2c1, HDC1080_ADDR, data, 2, 100);
                uint16_t raw = ((uint16_t)data[0] << 8) | data[1];
                return (raw / 65536.0f) * 100.0f;  // 公式：RH = raw/2^16 * 100
            }
        """, fname="hdc1080.c"),
        _table("p9i2c-tbl", "三种传感器接口对比",
            ["传感器", "接口", "地址", "测量量", "精度", "预热"],
            [
                ["MQ-2 烟雾", "ADC 模拟", "PA0（ADC通道）", "气体浓度", "约5%", ">5分钟"],
                ["BH1750 光照", "I2C", "0x23/0x5C", "光照强度", "±20%", "无需"],
                ["HDC1080 温湿", "I2C", "0x40", "温度+湿度", "±0.2°C/±2%", "无需"],
            ]
        ),
    ])

    return (p9_i2c,)


# ═══════════════════════════════════════════════════════════
# 第12章  追光控制系统 — 额外子页面
# ═══════════════════════════════════════════════════════════

def build_ch12_extra_pages():
    """第12章扩充：PID 算法代码实战页"""

    p12_pid = _page("p12-pid-code", "12.3 · 进阶｜PID算法C语言实现", [
        _t("p12pid-t1", """\
            ## 12.3 · 进阶｜离散 PID 控制器完整实现

            ### 离散 PID 公式推导
            连续域 PID 控制律：
            `u(t) = Kp·e(t) + Ki·∫e(t)dt + Kd·de(t)/dt`

            离散化（采样周期 T）：
            - 积分项：`∫e dt ≈ Σe·T`（矩形积分）
            - 微分项：`de/dt ≈ (e(k) - e(k-1)) / T`

            离散 PID 位置式：
            ```
            u(k) = Kp·e(k) + Ki·T·Σe + Kd/T·(e(k) - e(k-1))
            ```

            实际代码中通常令 `Ki_eff = Ki·T`，`Kd_eff = Kd/T`，在调参时直接调整。
        """),
        _code("p12pid-code1", "c", """\
            /* ══ 完整 PID 控制器（位置式 + 积分限幅 + 输出限幅）══ */

            typedef struct {
                float Kp, Ki, Kd;         // PID 三个系数
                float integral;            // 积分累积量
                float prev_error;          // 上次误差（用于计算微分）
                float integral_max;        // 积分限幅（防止积分饱和）
                float output_min;          // 输出下限
                float output_max;          // 输出上限
                float deadband;            // 死区（误差绝对值 < deadband 时不动作）
            } PID_t;

            /* 初始化 PID */
            void PID_Init(PID_t *pid, float Kp, float Ki, float Kd,
                          float intg_max, float out_min, float out_max, float dead) {
                pid->Kp = Kp; pid->Ki = Ki; pid->Kd = Kd;
                pid->integral = 0; pid->prev_error = 0;
                pid->integral_max = intg_max;
                pid->output_min = out_min;
                pid->output_max = out_max;
                pid->deadband = dead;
            }

            /* 计算 PID 输出（每个采样周期调用一次）*/
            float PID_Compute(PID_t *pid, float setpoint, float measured) {
                float error = setpoint - measured;

                // 死区处理：误差很小时不动作
                if (fabsf(error) < pid->deadband) {
                    return 0.0f;
                }

                // P 分量
                float p_term = pid->Kp * error;

                // I 分量（带限幅）
                pid->integral += pid->Ki * error;
                if (pid->integral > pid->integral_max) pid->integral = pid->integral_max;
                if (pid->integral < -pid->integral_max) pid->integral = -pid->integral_max;

                // D 分量
                float d_term = pid->Kd * (error - pid->prev_error);
                pid->prev_error = error;

                // 总输出 + 限幅
                float output = p_term + pid->integral + d_term;
                if (output > pid->output_max) output = pid->output_max;
                if (output < pid->output_min) output = pid->output_min;

                return output;
            }
        """, fname="pid.c"),
        _code("p12pid-code2", "c", """\
            /* ══ 追光系统主控循环 ══ */
            PID_t pid_x, pid_y;   // 水平轴、垂直轴各一个 PID

            void SunTracker_Init(void) {
                // 水平轴：舵机范围 0~180°，死区 ±30（ADC 差值）
                PID_Init(&pid_x, 0.8f, 0.01f, 0.3f, 200, -30, 30, 30);
                // 垂直轴类似
                PID_Init(&pid_y, 0.8f, 0.01f, 0.3f, 200, -20, 20, 20);

                // 初始化舵机到 90°（中位）
                Servo_SetAngle(SERVO_X, 90);
                Servo_SetAngle(SERVO_Y, 90);
            }

            void SunTracker_Loop(void) {
                // 读取四象限光敏传感器（ADC 通道 0~3）
                uint16_t tl = ADC_Read(0);  // 左上
                uint16_t tr = ADC_Read(1);  // 右上
                uint16_t bl = ADC_Read(2);  // 左下
                uint16_t br = ADC_Read(3);  // 右下

                // 计算光照差：正值→光源偏右，负值→光源偏左
                int16_t error_x = (int16_t)((tr + br) - (tl + bl));
                int16_t error_y = (int16_t)((tl + tr) - (bl + br));

                // PID 计算偏转量（单位：度）
                float delta_x = PID_Compute(&pid_x, 0, error_x);  // 目标：差值=0
                float delta_y = PID_Compute(&pid_y, 0, error_y);

                // 更新舵机角度（限制在 10°~170° 避免机械极限）
                static float angle_x = 90, angle_y = 90;
                angle_x = fmaxf(10, fminf(170, angle_x + delta_x));
                angle_y = fmaxf(10, fminf(170, angle_y + delta_y));

                Servo_SetAngle(SERVO_X, (uint8_t)angle_x);
                Servo_SetAngle(SERVO_Y, (uint8_t)angle_y);
            }

            // 主循环：每 50ms 执行一次
            while (1) {
                SunTracker_Loop();
                HAL_Delay(50);  // 20Hz 控制频率
            }
        """, fname="sun_tracker.c"),
        _fc("p12pid-fc", "PID 调参指南记忆卡", [
            ("Kp 太大会怎样？", "系统振荡（来回摆动），超调量大，减小Kp到临界值的一半"),
            ("Ki 的作用是什么？", "消除稳态误差，代价是响应变慢和可能引起积分饱和"),
            ("Kd 对噪声有什么影响？", "微分放大高频噪声，传感器噪声大时Kd要小或加低通滤波"),
            ("积分限幅的必要性？", "防止积分饱和：当执行器已到极限仍积分，导致反向时响应极慢"),
            ("死区设置多大合适？", "通常设为传感器噪声幅度的2~3倍，过大导致稳态误差，过小导致颤振"),
        ]),
    ])

    return (p12_pid,)


