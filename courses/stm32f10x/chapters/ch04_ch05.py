# -*- coding: utf-8 -*-
"""
build_p4_pages / build_p5_pages
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
    mermaid_block,
)
from manifest.factories import quick_page  # noqa: E402

# 注入 gen_manifest.py 中的 page/quiz 等基础函数（exec 兼容模式）
_GM_PATH = _os.path.join(_PUBLIC_DIR, 'gen_manifest.py')
exec(open(_GM_PATH, encoding='utf-8').read(), globals())

# ─── 项目4：定时器应用 ─────────────────────────────────────────────
def build_p4_pages():
    return [quick_page(
        "p4-timer", "4.1 定时器原理与应用",
        md_body="""\
            # 4.1 STM32 定时器原理与应用

            ## 4.1.1 定时器基本结构

            STM32F103的定时器核心是一个**16位自动重装载计数器（CNT）**，
            配合预分频器（PSC）和自动重装载寄存器（ARR）实现精确定时。

            ### 三个核心寄存器

            | 寄存器 | 全称 | 作用 | 范围 |
            |--------|------|------|------|
            | **PSC** | Prescaler | 预分频，降低计数时钟频率 | 0~65535 |
            | **ARR** | Auto-Reload Register | 设定溢出计数值 | 0~65535 |
            | **CNT** | Counter | 当前计数值（只读） | 0~ARR |

            ### 计算公式

            ```
            计数时钟频率 = 总线时钟 / (PSC + 1)
            溢出周期(s)  = (ARR + 1) / 计数时钟频率
                         = (ARR + 1) × (PSC + 1) / 总线时钟
            ```

            ### 常用定时参数速查表（72MHz时钟）

            | 目标周期 | PSC | ARR | 实际频率 |
            |---------|-----|-----|---------|
            | 1ms | 71 | 999 | 1kHz |
            | 10ms | 719 | 999 | 100Hz |
            | 100ms | 7199 | 999 | 10Hz |
            | 1s | 7199 | 9999 | 1Hz |
            | 20ms（舵机） | 71 | 19999 | 50Hz |

            > 💡 **技巧**：PSC和ARR都是16位，最大65535。
            > 若需要更长周期，可以在回调中用软件计数器再分频。

            ## 4.1.2 STM32F103 定时器分类

            | 类型 | 实例 | 总线 | 特有功能 |
            |------|------|------|---------|
            | **高级定时器** | TIM1, TIM8 | APB2(72MHz) | 死区控制、刹车输入、互补PWM |
            | **通用定时器** | TIM2~5 | APB1(36MHz×2=72MHz) | PWM输出、输入捕获、编码器 |
            | **基础定时器** | TIM6, TIM7 | APB1 | 仅计数，可触发DAC |

            > ⚠️ **注意**：TIM2~5挂在APB1总线，但APB1分频≠1时，定时器时钟=APB1×2=72MHz。

            ## 4.1.3 HAL库定时器中断配置

            ### CubeMX配置步骤
            1. **Timers → TIM2 → Clock Source = Internal Clock**
            2. **Parameter Settings**：PSC=7199，ARR=9999（定时1s）
            3. **NVIC Settings**：勾选 **TIM2 global interrupt**
            4. Generate Code

            ### 代码实现
            ```c
            /* main.c USER CODE BEGIN 2 */
            HAL_TIM_Base_Start_IT(&htim2);  /* 启动定时器中断 */

            /* 定时器溢出回调（每1s自动调用）*/
            void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim) {
                if (htim->Instance == TIM2) {
                    /* 每1s执行一次 */
                    HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);
                    /* 可以在这里更新显示、采集传感器等 */
                }
            }
            ```

            ## 4.1.4 数码管控制原理

            数码管是由7段LED组成的显示器件，通过控制各段的亮灭显示数字。

            ### 共阴极 vs 共阳极

            | 类型 | 公共端 | 点亮方式 | 段码逻辑 |
            |------|--------|---------|---------|
            | 共阴极 | 接GND | 段引脚输出高电平 | 1=亮，0=灭 |
            | 共阳极 | 接VCC | 段引脚输出低电平 | 0=亮，1=灭 |

            ### 数字0~9的段码（共阴极）
            ```c
            /* a b c d e f g dp */
            const uint8_t seg_code[10] = {
                0x3F, /* 0: 0b00111111 */
                0x06, /* 1: 0b00000110 */
                0x5B, /* 2: 0b01011011 */
                0x4F, /* 3: 0b01001111 */
                0x66, /* 4: 0b01100110 */
                0x6D, /* 5: 0b01101101 */
                0x7D, /* 6: 0b01111101 */
                0x07, /* 7: 0b00000111 */
                0x7F, /* 8: 0b01111111 */
                0x6F, /* 9: 0b01101111 */
            };
            ```

            ### 多位数码管动态扫描
            ```c
            /* 4位数码管，每位显示1ms，刷新率250Hz（人眼无闪烁感）*/
            void seg_scan_task(void) {  /* 在1ms定时器中断中调用 */
                static uint8_t digit = 0;
                /* 关闭所有位选 */
                HAL_GPIO_WritePin(GPIOB, 0x000F, GPIO_PIN_SET);
                /* 输出当前位的段码 */
                GPIOA->ODR = (GPIOA->ODR & 0xFF00) | seg_code[display_buf[digit]];
                /* 打开当前位选（低有效）*/
                HAL_GPIO_WritePin(GPIOB, (1 << digit), GPIO_PIN_RESET);
                digit = (digit + 1) % 4;
            }
            ```
        """,
        mm_root={"text": "STM32定时器", "children": [
            {"text": "计数原理", "children": [{"text": "PSC预分频"}, {"text": "ARR自动重装"}, {"text": "溢出中断"}]},
            {"text": "定时器类型", "children": [{"text": "基础TIM6/7"}, {"text": "通用TIM2-5"}, {"text": "高级TIM1/8"}]},
            {"text": "应用场景", "children": [{"text": "精确延时"}, {"text": "PWM输出"}, {"text": "输入捕获"}, {"text": "编码器"}]},
        ]},
        anim_scenes=[
            {"icon": "⏱️", "t": "定时器工作原理", "d": "PSC预分频器降低计数频率，CNT从0开始累加，到ARR时溢出→产生中断→CNT重置为0，如此循环"},
            {"icon": "🔢", "t": "计算定时周期", "d": "溢出周期=(ARR+1)/(总线频率/(PSC+1))。72MHz，PSC=7199，ARR=9999时：溢出周期=1秒"},
            {"icon": "💡", "t": "定时器中断应用", "d": "启动HAL_TIM_Base_Start_IT()后，每次溢出触发HAL_TIM_PeriodElapsedCallback回调，在此实现周期性任务"},
            {"icon": "🎯", "t": "三类定时器对比", "d": "基础定时器（TIM6/7）只计数；通用定时器（TIM2-5）支持PWM/捕获；高级定时器（TIM1/8）还有死区控制（用于电机驱动）"},
        ],
        games=[
            fill_blank("p4-tim-i1", "计算：72MHz主频下，PSC=71，ARR=999，定时周期是多少ms？",
                ["计数频率 = 72MHz / (", {"blank": True, "answer": "72", "hint": "PSC+1"}, ") = ",
                 {"blank": True, "answer": "1MHz", "hint": "计算结果"},
                 "\n溢出周期 = ", {"blank": True, "answer": "1000", "hint": "ARR+1"},
                 " / 1MHz = ", {"blank": True, "answer": "1ms", "hint": "最终答案"}]),
            matching("p4-tim-i2", "连线：定时器参数与作用", [
                ("PSC（预分频器）", "降低计数时钟频率"),
                ("ARR（自动重装）", "设定溢出计数值"),
                ("CNT（计数器）", "当前计数值寄存器"),
                ("TIM_PeriodElapsedCallback", "溢出中断回调函数"),
                ("HAL_TIM_Base_Start_IT()", "启动定时器中断"),
                ("htim->Instance == TIM2", "判断是哪个定时器触发"),
            ]),
            ordering("p4-tim-i3", "定时器中断配置步骤排序：", [
                "CubeMX中选择TIM2，启用计数模式",
                "设置PSC和ARR计算定时周期",
                "在NVIC中使能TIM2全局中断",
                "Generate Code，在代码中调用HAL_TIM_Base_Start_IT()",
                "实现HAL_TIM_PeriodElapsedCallback()回调",
                "在回调中判断htim->Instance后执行任务",
            ]),
            classification("p4-tim-i4", "分类：属于哪类定时器？",
                {"basic": "基础定时器", "general": "通用定时器", "adv": "高级定时器"},
                [("t1", "TIM2（支持PWM输出）", "general"),
                 ("t2", "TIM6（只有计数，无输出比较）", "basic"),
                 ("t3", "TIM1（带死区控制，电机驱动）", "adv"),
                 ("t4", "TIM3（支持输入捕获）", "general"),
                 ("t5", "TIM7（DAC触发定时器）", "basic"),
                 ("t6", "TIM8（高级控制，互补PWM）", "adv")]),
            flashcard("p4-tim-i5", "📚 定时器核心参数卡", [
                ("PSC=71，时钟72MHz，计数频率=？", "72MHz/(71+1)=1MHz，每μs计数1次"),
                ("ARR=999，计数频率1MHz，溢出周期=？", "1000/1MHz = 1ms，每1ms中断一次"),
                ("通用定时器TIM2~5支持几路PWM？", "4路（Channel1~4），每路可独立设置占空比"),
                ("高级定时器TIM1比TIM2多什么功能？", "互补PWM输出（带死区）、刹车输入、重复计数器"),
            ]),
        ],
        quiz_ref="q-p4-timer",
        sum_pts=["定时器溢出周期=(ARR+1)/计数频率，计数频率=总线频率/(PSC+1)",
                 "HAL_TIM_Base_Start_IT()启动中断，PeriodElapsedCallback()是溢出回调",
                 "TIM2~5是最常用的通用定时器，支持PWM输出和输入捕获",
                 "定时器计算：72MHz，PSC=7199，ARR=9999 → 精确1s周期"],
        dh_script="定时器是单片机的心脏节拍。从精确1ms延时到PWM波形输出，从串口波特率生成到编码器测速，定时器无处不在。计算公式记住：溢出周期=(ARR+1)/计数频率。",
        dh_faq=[{"q": "为什么PSC=71而不是72？",
                 "a": "因为实际分频比是PSC+1。PSC=71时分频比为72，72MHz/72=1MHz。HAL库自动处理+1，但要理解这背后的硬件行为。"},
                {"q": "HAL_Delay()和定时器有什么区别？",
                 "a": "HAL_Delay()基于SysTick，阻塞CPU；定时器中断是非阻塞的，CPU可以做其他事情。实际项目中应尽量用定时器，少用HAL_Delay()。"}],
        objectives=["理解定时器PSC/ARR/CNT参数意义", "计算定时周期", "实现定时器中断周期性任务"],
        minutes=40, tags=["timer", "interrupt", "hal"],
        extra_blocks_before_exp=[

            code_block("p4-timer-code", "c", """\
            /* TIM2定时器中断：精确1秒翻转LED */
            #include "main.h"

            /* 在 main() 中 USER CODE BEGIN 2 添加 */
            void timer_init(void) {
                /* PSC=7199, ARR=9999, 72MHz→10kHz→1s溢出 */
                HAL_TIM_Base_Start_IT(&htim2);
            }

            /* 定时器溢出回调（每1s调用一次） */
            void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim) {
                if (htim->Instance == TIM2) {
                    HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13); /* 1s翻转 */
                }
            }

            /* 进阶：软件定时，1ms中断计数实现多路定时 */
            static uint32_t cnt_led = 0;
            static uint32_t cnt_uart = 0;
            void HAL_TIM_PeriodElapsedCallback_multi(TIM_HandleTypeDef *htim) {
                if (htim->Instance == TIM3) { /* TIM3: 1ms */
                    if (++cnt_led >= 500) { cnt_led=0;
                        HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13); }
                    if (++cnt_uart >= 1000) { cnt_uart=0;
                        /* 每1s发送一次串口数据 */ }
                }
            }
        """, "timer_demo.c", [6, 11, 18])],
        exp_steps=[
            step(1, "配置TIM2", "CubeMX：TIM2→Activated，PSC=7199，ARR=999（定时10ms），使能TIM2全局中断。", chk=True),
            step(2, "启动定时器", "在main.c的USER CODE中添加HAL_TIM_Base_Start_IT(&htim2);", "HAL_TIM_Base_Start_IT(&htim2);", True),
            step(3, "实现回调", "实现PeriodElapsedCallback，用计数变量实现精确1s翻转LED。",
                 "static uint32_t cnt=0;\nif(++cnt>=100){cnt=0; HAL_GPIO_TogglePin(GPIOC,GPIO_PIN_13);}", True),
        ]
    )]


# ─── 项目5：PWM输出 ────────────────────────────────────────────────
def build_p5_pages():
    return [quick_page(
        "p5-pwm", "5.1 PWM输出与LED呼吸灯",
        md_body="""\
            # 5.1 PWM输出与LED呼吸灯

            ## 5.1.1 PWM基本原理

            **PWM（Pulse Width Modulation，脉冲宽度调制）** 是一种通过改变数字方波的
            高电平持续时间（脉冲宽度）来模拟模拟信号的技术。

            ### 核心参数

            | 参数 | 定义 | 公式 |
            |------|------|------|
            | **周期（T）** | 一个完整波形的时间 | T = 1/f |
            | **频率（f）** | 每秒重复次数 | f = 72MHz/((PSC+1)×(ARR+1)) |
            | **占空比（D）** | 高电平时间/总周期 | D = CCR/(ARR+1) × 100% |
            | **等效电压** | 平均输出电压 | V_avg = V_cc × D |

            ### 直观理解

            ```
            占空比25%：▐░░░▐░░░▐░░░  等效电压 = 3.3V × 25% = 0.825V
            占空比50%：▐▐░░▐▐░░▐▐░░  等效电压 = 3.3V × 50% = 1.65V
            占空比75%：▐▐▐░▐▐▐░▐▐▐░  等效电压 = 3.3V × 75% = 2.475V
            ```

            > 💡 **为什么PWM能控制亮度？** LED的亮度取决于平均电流，
            > 而平均电流正比于占空比。人眼对>50Hz的闪烁无法分辨，
            > 看到的是平均亮度效果。

            ## 5.1.2 STM32 PWM配置详解

            ### CubeMX配置步骤
            1. **Timers → TIM2 → Channel1 = PWM Generation CH1**
            2. **Parameter Settings**：
               - PSC = 71（计数频率 = 72MHz/72 = 1MHz）
               - ARR = 999（PWM频率 = 1MHz/1000 = 1kHz）
               - Pulse（CCR）= 500（初始占空比50%）
            3. **PA0** 自动配置为 TIM2_CH1 复用推挽输出
            4. Generate Code

            ### 关键参数计算

            ```
            PWM频率 = 72MHz / ((PSC+1) × (ARR+1))
                    = 72MHz / (72 × 1000) = 1kHz

            占空比 = CCR / (ARR+1) × 100%
                   = 500 / 1000 × 100% = 50%

            等效电压 = 3.3V × 50% = 1.65V
            ```

            ### HAL库操作
            ```c
            /* 启动PWM输出（必须在初始化后调用）*/
            HAL_TIM_PWM_Start(&htim2, TIM_CHANNEL_1);

            /* 动态修改占空比（0~ARR）*/
            __HAL_TIM_SET_COMPARE(&htim2, TIM_CHANNEL_1, ccr_value);

            /* 停止PWM输出 */
            HAL_TIM_PWM_Stop(&htim2, TIM_CHANNEL_1);
            ```

            ## 5.1.3 LED呼吸灯实现

            呼吸灯通过平滑改变PWM占空比实现亮度渐变效果：

            ```c
            void led_breath_task(void) {
                static int16_t ccr = 0;
                static int8_t  dir = 1;   /* 1=渐亮，-1=渐暗 */

                ccr += dir * 10;           /* 每次步进10（共100步）*/
                if (ccr >= 1000) { ccr = 1000; dir = -1; }  /* 到顶反向 */
                if (ccr <= 0)    { ccr = 0;    dir =  1; }  /* 到底反向 */

                __HAL_TIM_SET_COMPARE(&htim2, TIM_CHANNEL_1, ccr);
            }
            /* 在10ms定时器中断中调用，呼吸周期 = 100步×10ms×2 = 2s */
            ```

            ## 5.1.4 PWM典型应用参数

            | 应用 | 频率 | PSC | ARR | 说明 |
            |------|------|-----|-----|------|
            | LED调光 | 1kHz | 71 | 999 | 人眼无闪烁感 |
            | 蜂鸣器 | 2.7kHz | 26 | 999 | 标准蜂鸣频率 |
            | 舵机控制 | 50Hz | 71 | 19999 | 周期20ms |
            | 直流电机 | 10kHz | 7 | 899 | 减少噪音 |
            | 无刷电机 | 20kHz | 3 | 899 | 超声波频率，无噪音 |

            ### 舵机PWM详解
            ```c
            /* 舵机：50Hz，PSC=71，ARR=19999 */
            /* 脉宽0.5ms=0°，1.5ms=90°，2.5ms=180° */
            /* CCR = 脉宽(ms) × 1000（因为计数频率1MHz）*/
            void servo_set_angle(uint8_t angle) {  /* 0~180° */
                uint32_t ccr = 500 + (uint32_t)angle * 2000 / 180;
                /* angle=0  → ccr=500  (0.5ms) */
                /* angle=90 → ccr=1500 (1.5ms) */
                /* angle=180→ ccr=2500 (2.5ms) */
                __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_1, ccr);
            }
            ```
        """,
        mm_root={"text": "PWM输出", "children": [
            {"text": "基本原理", "children": [{"text": "占空比=CCR/(ARR+1)"}, {"text": "等效电压"}, {"text": "频率=72M/((PSC+1)(ARR+1))"}]},
            {"text": "HAL配置", "children": [{"text": "TIM2_CH1"}, {"text": "PWM_Start()"}, {"text": "SET_COMPARE()"}]},
            {"text": "应用场景", "children": [{"text": "LED呼吸灯"}, {"text": "舵机控制"}, {"text": "电机调速"}, {"text": "蜂鸣器"}]},
        ]},
        anim_scenes=[
            {"icon": "📊", "t": "PWM波形与占空比", "d": "方波高电平持续时间/总周期=占空比。50%占空比时，等效直流电压=电源电压的50%，LED亮度约为最大值的50%"},
            {"icon": "💡", "t": "LED呼吸灯实现", "d": "CCR从0渐增到ARR（渐亮），再从ARR渐减到0（渐暗），配合Delay控制速度，人眼看到自然的呼吸效果"},
            {"icon": "🔧", "t": "STM32 PWM寄存器关系", "d": "PSC控制频率，ARR决定周期分辨率，CCR决定高电平时间。ARR=999时分辨率0.1%，ARR=9999时分辨率0.01%"},
            {"icon": "🎛️", "t": "PWM应用：舵机控制", "d": "舵机需要50Hz（20ms周期）的PWM。脉宽0.5ms=最左转，1.5ms=中位，2.5ms=最右转。对应CCR=25、75、125（ARR=999，50Hz）"},
        ],
        games=[
            fill_blank("p5-pwm-i1", "计算：TIM2，PSC=71，ARR=999，当CCR=250时，占空比是多少？",
                ["PWM频率 = 72MHz/(72×", {"blank": True, "answer": "1000", "hint": "ARR+1"}, ") = ",
                 {"blank": True, "answer": "1kHz", "hint": "计算结果"},
                 "\n占空比 = ", {"blank": True, "answer": "250", "hint": "CCR值"},
                 " / (ARR+1) × 100% = ", {"blank": True, "answer": "25%", "hint": "百分比"}]),
            matching("p5-pwm-i2", "连线：PWM参数与含义", [
                ("PSC（预分频）", "控制PWM频率"),
                ("ARR（自动重装）", "决定占空比分辨率"),
                ("CCR（比较寄存器）", "设定占空比"),
                ("__HAL_TIM_SET_COMPARE()", "动态修改占空比"),
                ("HAL_TIM_PWM_Start()", "开始输出PWM波形"),
                ("TIM_CHANNEL_1", "选择定时器通道"),
            ]),
            ordering("p5-pwm-i3", "LED呼吸灯程序步骤排序：", [
                "CubeMX配置TIM2 CH1为PWM模式，PA0复用",
                "设置PSC和ARR确定PWM频率（如1kHz）",
                "Generate Code",
                "调用HAL_TIM_PWM_Start(&htim2, TIM_CHANNEL_1)",
                "for循环中递增CCR实现渐亮效果",
                "for循环中递减CCR实现渐暗效果",
            ]),
            classification("p5-pwm-i4", "分类：以下PWM应用的频率要求",
                {"low": "低频（<1kHz）", "mid": "中频（1~20kHz）", "high": "高频（>20kHz）"},
                [("pw1", "舵机控制（50Hz）", "low"),
                 ("pw2", "LED调光（1kHz）", "mid"),
                 ("pw3", "无刷电机（20kHz）", "mid"),
                 ("pw4", "超声波清洗（40kHz）", "high"),
                 ("pw5", "音频D类功放（44.1kHz+）", "high"),
                 ("pw6", "蜂鸣器驱动（2.7kHz）", "mid")]),
            flashcard("p5-pwm-i5", "📚 PWM核心知识卡", [
                ("PWM占空比公式？", "占空比=CCR/(ARR+1)×100%"),
                ("如何控制LED亮度？", "改变CCR值：CCR越大占空比越高，LED越亮"),
                ("舵机需要什么样的PWM？", "50Hz（20ms周期），脉宽0.5~2.5ms对应0°~180°"),
                ("PWM驱动电机为什么用高频？", "高频PWM减少电机电感引起的电流纹波，降低振动噪音和发热"),
            ]),
        ],
        quiz_ref="q-p5-pwm",
        sum_pts=["PWM占空比=CCR/(ARR+1)，通过改变CCR动态调节等效输出电压",
                 "HAL_TIM_PWM_Start()启动PWM，__HAL_TIM_SET_COMPARE()动态调节占空比",
                 "呼吸灯=CCR从0→ARR（渐亮）→0（渐暗），循环执行",
                 "PWM应用广泛：LED调光/舵机/电机调速/音频输出"],
        dh_script="PWM是模拟世界和数字世界之间的桥梁。单片机只能输出0V和3.3V，但通过PWM，我们可以模拟出任意中间电压，驱动LED产生无限级别的亮度变化。",
        dh_faq=[{"q": "占空比100%和直接给高电平有什么区别？",
                 "a": "功能等效，效果相同。但PWM可以通过软件动态修改占空比，而普通GPIO不能实时调节电压。PWM的价值在于'可编程可变'的特性。"},
                {"q": "如何控制舵机转到90度？",
                 "a": "50Hz PWM，20ms周期。中位对应1.5ms脉宽：CCR = ARR×1.5/20 = 999×0.075 = 75（ARR=999时）"}],
        objectives=["理解PWM占空比与等效电压关系", "配置TIM2 PWM输出", "实现LED呼吸灯效果"],
        minutes=40, tags=["pwm", "timer", "led"],
        extra_blocks_before_exp=[code_block("p5-pwm-code", "c", """\
            /* TIM2 PWM输出：LED呼吸灯 + 舵机控制 */
            #include "main.h"

            /* 启动PWM输出（CubeMX已配置TIM2_CH1→PA0） */
            void pwm_init(void) {
                HAL_TIM_PWM_Start(&htim2, TIM_CHANNEL_1);
            }

            /* 设置占空比（0~100，百分比）*/
            void pwm_set_duty(uint8_t duty_pct) {
                /* PSC=71,ARR=999时，ARR+1=1000 */
                uint32_t ccr = duty_pct * 1000 / 100;
                __HAL_TIM_SET_COMPARE(&htim2, TIM_CHANNEL_1, ccr);
            }

            /* LED呼吸灯主循环 */
            void led_breath_pwm(void) {
                while (1) {
                    for (int d = 0; d <= 100; d++) { /* 渐亮 */
                        pwm_set_duty(d);
                        HAL_Delay(10);  /* 每步10ms，1s完成渐亮 */
                    }
                    for (int d = 100; d >= 0; d--) { /* 渐暗 */
                        pwm_set_duty(d);
                        HAL_Delay(10);
                    }
                }
            }

            /* 舵机控制（50Hz，PSC=71,ARR=19999）*/
            /* 脉宽=CCR/(ARR+1)*20ms：CCR=500→0.5ms=0°，CCR=1500→1.5ms=90° */
            void servo_set_angle(uint8_t angle) {  /* 0~180 */
                uint32_t ccr = 500 + angle * (2000-500)/180;
                __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_1, ccr);
            }
        """, "pwm_demo.c", [6, 10, 17, 31])],
        exp_steps=[
            step(1, "配置TIM2 PWM", "CubeMX：TIM2→PWM Generation CH1，PSC=71，ARR=999，PA0=TIM2_CH1复用。", chk=True),
            step(2, "启动PWM", "HAL_TIM_PWM_Start(&htim2, TIM_CHANNEL_1);", "HAL_TIM_PWM_Start(&htim2, TIM_CHANNEL_1);", True),
            step(3, "实现呼吸灯", "for循环CCR 0→999→0，每步Delay(2ms)。",
                 "for(int i=0;i<=999;i++){__HAL_TIM_SET_COMPARE(&htim2,TIM_CHANNEL_1,i);HAL_Delay(2);}", True),
        ]
    )]


