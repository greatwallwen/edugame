# -*- coding: utf-8 -*-
"""
build_p8_pages / build_p9_pages
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
from manifest.factories import make_simple_page  # noqa: E402

# 注入 gen_manifest.py 中的 page/quiz 等基础函数（exec 兼容模式）
_GM_PATH = _os.path.join(_PUBLIC_DIR, 'gen_manifest.py')
exec(open(_GM_PATH, encoding='utf-8').read(), globals())

# ─── 项目8-12 快速页面 ────────────────────────────────────────────
def build_p8_pages():
    """项目8：DAC实验"""
    return [make_simple_page(
        "p8-dac", "8.1 DAC数模转换与波形输出", "DAC数模转换",
        key_points=[
            "DAC将数字值（0~4095）转换为模拟电压（0~3.3V）",
            "STM32F103C8T6集成2路12位DAC（DAC1_CH1/DAC1_CH2）",
            "基本公式：输出电压 = VREF × DAC_Value / 4096",
            "定时器触发DAC可实现精确频率的波形输出（正弦/三角/锯齿波）",
            "DMA传输预先计算的波形表，DAC自动输出周期性波形，CPU零负担",
        ],
        md_body="""\
            # 8.1 DAC数模转换与波形输出

            ## 8.1.1 DAC基本原理

            DAC（Digital-to-Analog Converter，数模转换器）将数字值转换为模拟电压，
            与ADC功能相反。STM32F103集成了高性能DAC模块。

            ### STM32F103 DAC规格

            | 参数 | 规格值 | 说明 |
            |------|--------|------|
            | 分辨率 | **12位** | 量化级数 = 4096 |
            | 通道数 | 2路（CH1/CH2） | PA4=CH1，PA5=CH2 |
            | 参考电压 | VREF+ = 3.3V | 满量程输出3.3V |
            | 输出范围 | 0.2V ~ VREF-0.2V | 约0.2~3.1V（有死区） |
            | 建立时间 | ~3μs | 从写入到稳定输出 |
            | 输出缓冲 | 可选（增强驱动能力） | 使能后可驱动外部负载 |

            ### 电压转换公式

            ```
            输出电压(V) = VREF × DAC_Value / 4096
                        = 3.3 × DAC_Value / 4096

            示例：
            DAC_Value = 0    → 输出 ≈ 0V
            DAC_Value = 2048 → 输出 ≈ 1.65V（满量程50%）
            DAC_Value = 4095 → 输出 ≈ 3.299V（接近满量程）
            ```

            ## 8.1.2 DAC基本输出配置

            ### CubeMX配置步骤
            1. **DAC** → OUT1 Configuration → **Connected to external pin only**
            2. Output Buffer → **Enable**（增强驱动能力）
            3. Trigger → **None**（软件触发，直接写值）
            4. PA4自动配置为模拟输出

            ### HAL库操作
            ```c
            /* 启动DAC通道1 */
            HAL_DAC_Start(&hdac, DAC_CHANNEL_1);

            /* 输出固定电压（12位右对齐）*/
            HAL_DAC_SetValue(&hdac, DAC_CHANNEL_1, DAC_ALIGN_12B_R, 2048);
            /* PA4输出约1.65V */

            /* 读取当前DAC值 */
            uint32_t val = HAL_DAC_GetValue(&hdac, DAC_CHANNEL_1);
            ```

            ## 8.1.3 波形生成原理

            通过**定时器触发 + DMA传输波形表**，DAC可自动输出周期性波形，CPU零负担。

            ```
            定时器TIM2 ──→ 触发DAC ──→ DMA从波形表取下一个值 ──→ DAC输出
                ↑                                                      │
                └──────────────── 循环 ─────────────────────────────────┘
            ```

            **波形频率计算**：
            ```
            波形频率 = 定时器触发频率 / 波形表点数
            定时器触发频率 = 72MHz / ((PSC+1) × (ARR+1))

            示例：PSC=0, ARR=27, 波形表256点
            触发频率 = 72MHz/28 ≈ 2.571MHz
            波形频率 = 2.571MHz/256 ≈ 10kHz
            ```

            ## 8.1.4 正弦波生成

            ```c
            #include <math.h>
            #define SINE_POINTS 256
            uint16_t sine_table[SINE_POINTS];

            /* 预计算正弦波表（0~4095，中心2048）*/
            void sine_table_init(void) {
                for (int i = 0; i < SINE_POINTS; i++) {
                    sine_table[i] = (uint16_t)(2048 + 2047 * sinf(2*M_PI*i/SINE_POINTS));
                }
                /* sine_table[0]=2048, 最大≈4095, 最小≈1 */
            }

            /* 启动DAC+DMA输出正弦波 */
            void dac_sine_start(void) {
                sine_table_init();
                HAL_DAC_Start_DMA(&hdac, DAC_CHANNEL_1,
                    (uint32_t*)sine_table, SINE_POINTS, DAC_ALIGN_12B_R);
                HAL_TIM_Base_Start(&htim2);  /* 启动触发定时器 */
            }
            ```

            ## 8.1.5 多种波形对比

            | 波形 | 生成方法 | 特点 | 应用 |
            |------|---------|------|------|
            | 正弦波 | sin()函数查表 | 平滑，频谱纯净 | 音频测试、信号源 |
            | 三角波 | 线性递增/递减 | 简单，谐波丰富 | 扫频测试 |
            | 锯齿波 | 单向线性 | 不对称 | 示波器扫描 |
            | 方波 | 0/4095交替 | 边沿陡峭 | 数字信号测试 |

            ```c
            /* 三角波表生成 */
            for (int i = 0; i < SINE_POINTS/2; i++)
                tri_table[i] = i * 4095 / (SINE_POINTS/2);      /* 上升 */
            for (int i = 0; i < SINE_POINTS/2; i++)
                tri_table[SINE_POINTS/2+i] = 4095 - i * 4095 / (SINE_POINTS/2); /* 下降 */
            ```

            > 💡 **实验技巧**：用示波器测量PA4引脚，调整TIM2的ARR值改变波形频率，
            > 观察频率变化。也可以用串口发送命令切换波形类型。
        """,
        games_data=[
            ("matching", "连线：DAC与ADC对比", [
                ("ADC", "模拟→数字（采集传感器）"),
                ("DAC", "数字→模拟（输出信号）"),
                ("ADC精度", "0.8mV/LSB（12位，3.3V）"),
                ("DAC精度", "0.8mV/LSB（与ADC相同）"),
                ("ADC应用", "读取传感器电压值"),
                ("DAC应用", "产生音频/控制模拟"),
            ]),
            ("ordering", "DAC输出正弦波步骤：", [
                "预先计算256点正弦波数据表（0~4095）",
                "CubeMX配置DAC1_CH1，触发源选TIM2",
                "配置TIM2频率=目标波形频率×256（采样点数）",
                "配置DMA：Memory→DAC，循环模式",
                "启动TIM2和DAC+DMA",
                "示波器验证输出波形频率和幅度",
            ]),
            ("flashcard", "DAC关键知识卡", [
                ("DAC输出公式？", "Vout = VREF × DAC_Value / 4096（VREF=3.3V）"),
                ("如何用DAC输出1kHz正弦波？", "准备256点正弦表，TIM2频率=256kHz触发DAC，DMA循环传输"),
                ("STM32F103的DAC有几路？", "2路（DAC1_CH1和DAC1_CH2），均为12位精度"),
                ("DAC和PWM控制模拟量有何不同？", "DAC真正输出模拟电压，PWM是数字方波（需RC滤波才像模拟信号）"),
            ]),
            ("classification", "分类：哪些用DAC输出？哪些用PWM？",
                {"dac": "用DAC更合适", "pwm": "用PWM更合适"},
                [("d1", "音频信号输出（高保真）", "dac"),
                 ("d2", "LED调光控制", "pwm"),
                 ("d3", "仪器模拟参考电压", "dac"),
                 ("d4", "直流电机调速", "pwm"),
                 ("d5", "信号发生器正弦波", "dac"),
                 ("d6", "舵机位置控制", "pwm")]),
        ],
        quiz_ref="q-p8-dac",
        mm_children=[
            {"text": "DAC基础", "children": [{"text": "12位精度"}, {"text": "0~3.3V输出"}, {"text": "Vout=VREF×Val/4096"}]},
            {"text": "波形输出", "children": [{"text": "正弦波表256点"}, {"text": "TIM2触发"}, {"text": "DMA循环"}]},
            {"text": "应用场景", "children": [{"text": "音频DAC"}, {"text": "参考电压"}, {"text": "信号发生器"}]},
        ],
        anim_data=[
            {"icon": "🔊", "t": "DAC基本工作原理", "d": "数字值→R-2R电阻网络→模拟电压。4096对应3.3V，2048对应1.65V，0对应0V。精度与ADC相同（0.8mV/LSB）"},
            {"icon": "🌊", "t": "正弦波生成原理", "d": "预计算256个正弦值存入数组，TIM2每隔1/256T触发一次DAC更新，DMA自动搬移下一个点，如此循环输出连续正弦波"},
            {"icon": "🎵", "t": "DAC音频应用", "d": "44.1kHz采样率，16位PCM数据通过DAC输出，接功放驱动扬声器。STM32F103可胜任8kHz单声道简单音频播放"},
        ],
        tags=["dac", "analog", "waveform"],
        code_lang="c", code_filename="dac_sine.c", code_snippet="""\
            /* DAC输出正弦波（256点表 + DMA循环）*/
            #include "main.h"
            #include <math.h>

            #define SINE_POINTS 256
            uint16_t sine_table[SINE_POINTS];

            /* 预计算正弦波数据表（0~4095） */
            void sine_table_init(void) {
                for (int i = 0; i < SINE_POINTS; i++) {
                    sine_table[i] = (uint16_t)(2048 + 2047 * sin(2*M_PI*i/SINE_POINTS));
                }
            }

            /* 启动DAC+DMA输出正弦波
             * 波形频率 = TIM触发频率 / 256
             * TIM触发频率 = 72MHz / ((PSC+1)*(ARR+1))
             * 示例：PSC=0,ARR=27 → 触发频率≈2.57MHz → 波形频率≈10kHz
             */
            void dac_sine_start(void) {
                sine_table_init();
                HAL_DAC_Start_DMA(&hdac, DAC_CHANNEL_1,
                    (uint32_t*)sine_table, SINE_POINTS,
                    DAC_ALIGN_12B_R);
                HAL_TIM_Base_Start(&htim2);  /* 触发TIM */
            }
        """,
        exp_steps_simple=[
            step(1, "CubeMX配置DAC", "DAC1→Channel1，触发源选TIM2 TRGO，使能DMA（Memory→DAC，Half-Word）。", chk=True),
            step(2, "配置TIM2触发", "TIM2→Master Mode=Update，PSC=0，ARR=27（触发频率≈2.57MHz）。", chk=True),
            step(3, "计算正弦表并启动", "调用sine_table_init()，然后HAL_DAC_Start_DMA，用示波器测PA4。",
                 "sine_table_init();\nHAL_DAC_Start_DMA(&hdac,DAC_CHANNEL_1,(uint32_t*)sine_table,256,DAC_ALIGN_12B_R);\nHAL_TIM_Base_Start(&htim2);", True),
            step(4, "调节波形频率", "修改TIM2的ARR值改变触发频率，观察示波器上正弦波频率变化。", chk=False),
        ]
    )]


def build_p9_pages():
    """项目9：环境监测系统"""
    return [make_simple_page(
        "p9-env", "9.1 环境监测系统设计", "环境监测系统",
        key_points=[
            "MQ-2烟雾传感器：ADC采样，检测300~10000ppm，预热>5分钟",
            "BH1750光照传感器：I2C接口(0x23)，1~65535lux，分辨率1lux",
            "HDC1080温湿度传感器：I2C接口(0x40)，精度±0.2°C/±2%RH",
            "多传感器融合：主循环按时间片轮流采集各传感器数据",
            "数据滤波：滑动平均滤波消除传感器噪声，提高显示稳定性",
        ],
        md_body="""\
            # 9.1 环境监测系统设计

            ## 9.1.1 系统概述

            本项目基于STM32F103，集成三种环境传感器，实现对烟雾浓度、光照强度、温湿度的实时监测。
            系统通过串口输出数据，并在LCD上实时显示。

            ### 系统架构

            ```
            ┌─────────────┐     ┌──────────────┐     ┌──────────┐
            │ MQ-2 (ADC)  │────→│              │────→│ UART串口 │→ 上位机
            │ BH1750 (I2C)│────→│  STM32F103   │────→│ LCD显示  │
            │ HDC1080(I2C)│────→│              │────→│ LED报警  │
            └─────────────┘     └──────────────┘     └──────────┘
            ```

            ## 9.1.2 MQ-2烟雾传感器

            | 参数 | 规格值 | 说明 |
            |------|--------|------|
            | 检测气体 | LPG/丙烷/氢气/甲烷/烟雾 | 广谱气体检测 |
            | 检测浓度 | 300~10000 ppm | 对数响应特性 |
            | 工作电压 | 5V DC（加热电阻） | 不能用3.3V供电！ |
            | AO输出 | 0~5V模拟电压 | 需分压到3.3V |
            | DO输出 | 高/低电平（可调阈值） | 电位器调节灵敏度 |
            | 预热时间 | 首次>24h，日常>5min | 预热不足读数不准 |
            | 响应时间 | <10s | 从清洁空气到检测浓度 |

            **接线方案**（AO模拟输出→ADC）：
            ```
            MQ-2 AO ──[2kΩ]──┬──[3kΩ]── GND
                              │
                              └── PA0 (ADC1_IN0)  ← 分压后最大3.3V
            ```

            **浓度估算**：Rs/R0 = f(ppm)，需要标定曲线。简化方案：
            ```c
            float voltage = adc_val * 3.3f / 4096.0f;
            /* 经验公式（需根据实际标定调整）*/
            uint32_t ppm_approx = (uint32_t)(voltage * 3000.0f / 3.3f);
            if (ppm_approx > 1000) { /* 报警！*/ }
            ```

            ## 9.1.3 BH1750光照传感器

            BH1750是数字光照强度传感器，直接输出lux值，无需ADC转换。

            | 参数 | 规格值 |
            |------|--------|
            | 接口 | I2C（ADDR=L时地址**0x23**，ADDR=H时0x5C） |
            | 测量范围 | 1~65535 lux |
            | 分辨率 | 1 lux（H-Resolution模式） |
            | 测量时间 | 120ms（H模式）/ 16ms（L模式） |
            | 工作电压 | 2.4~3.6V |
            | 光谱响应 | 接近人眼视觉灵敏度曲线 |

            **I2C通信流程**：
            ```c
            /* 1. 发送测量命令：0x10 = 连续H分辨率模式 */
            uint8_t cmd = 0x10;
            HAL_I2C_Master_Transmit(&hi2c1, 0x23<<1, &cmd, 1, 100);

            /* 2. 等待测量完成（H模式需120ms）*/
            HAL_Delay(180);

            /* 3. 读取2字节数据 */
            uint8_t data[2];
            HAL_I2C_Master_Receive(&hi2c1, 0x23<<1, data, 2, 100);

            /* 4. 计算lux值 */
            uint16_t raw = (data[0] << 8) | data[1];
            float lux = raw / 1.2f;  /* 手册规定除以1.2 */
            ```

            ## 9.1.4 HDC1080温湿度传感器

            HDC1080是高精度数字温湿度传感器，I2C接口，单芯片集成温度和湿度测量。

            | 参数 | 规格值 |
            |------|--------|
            | I2C地址 | **0x40**（固定，不可更改） |
            | 温度范围 | -40~+125°C，精度**±0.2°C** |
            | 湿度范围 | 0~100%RH，精度**±2%RH** |
            | 转换时间 | 温度6.35ms，湿度6.5ms |
            | 工作电压 | 2.7~5.5V |

            **寄存器映射**：
            - 0x00：温度寄存器（16位无符号）
            - 0x01：湿度寄存器（16位无符号）
            - 0x02：配置寄存器

            **数据转换公式**：
            ```c
            /* 温度 = raw / 65536 × 165 - 40 */
            float temp = (float)raw_temp / 65536.0f * 165.0f - 40.0f;

            /* 湿度 = raw / 65536 × 100 */
            float humi = (float)raw_humi / 65536.0f * 100.0f;
            ```

            ## 9.1.5 多传感器系统集成

            **采集策略**：按时间片轮询，避免I2C总线冲突
            ```c
            void env_task(void) {  /* 每1秒调用一次 */
                static uint8_t phase = 0;
                switch (phase++ % 3) {
                    case 0: read_mq2();    break;  /* ADC采样，<1ms */
                    case 1: read_bh1750(); break;  /* I2C，需180ms */
                    case 2: read_hdc1080();break;  /* I2C，需15ms */
                }
                lcd_update();  /* 刷新显示 */
                uart_report(); /* 串口上报 */
            }
            ```

            > 💡 **设计要点**：BH1750测量需要120ms，不能在同一个循环中连续读取所有I2C设备，
            > 否则会阻塞主循环。建议用状态机分时采集。
        """,
        games_data=[
            ("matching", "连线：环境传感器与接口协议", [
                ("DHT11", "单总线（1-Wire自定义协议）"),
                ("BMP280", "I2C（400kHz快速模式）"),
                ("TFT-LCD", "SPI（通常8~16MHz）"),
                ("DS18B20", "单总线（Dallas 1-Wire）"),
                ("MPU6050", "I2C（6轴IMU）"),
                ("W25Q64 Flash", "SPI（存储配置参数）"),
            ]),
            ("ordering", "环境监测系统开发步骤：", [
                "硬件连接：DHT11→PA0，BMP280→I2C1，LCD→SPI1",
                "移植DHT11单总线驱动库",
                "配置I2C，读取BMP280原始数据并换算",
                "初始化LCD，创建UI界面布局",
                "主循环：每秒采集一次数据，刷新LCD显示",
                "加入滑动平均滤波，使显示数值平滑稳定",
            ]),
            ("classification", "传感器接口类型分类：",
                {"i2c": "I2C接口", "spi": "SPI接口", "uart": "UART接口", "onewire": "单总线"},
                [("s1", "DHT11温湿度", "onewire"),
                 ("s2", "BMP280气压", "i2c"),
                 ("s3", "TFT-LCD显示屏", "spi"),
                 ("s4", "GPS模块NEO-6M", "uart"),
                 ("s5", "OLED显示屏（SSD1306）", "i2c"),
                 ("s6", "DS18B20数字温度", "onewire")]),
            ("flashcard", "环境监测系统关键知识", [
                ("DHT11数据格式？", "40位数据：8位湿度整数+8位湿度小数+8位温度整数+8位温度小数+8位校验和"),
                ("滑动平均滤波原理？", "保存最近N次采样值，取平均作为输出。N越大越稳定但响应越慢，通常N=8"),
                ("I2C地址冲突怎么解决？", "I2C设备地址最低位通常可通过AD0引脚切换，同一总线可挂多个地址不同的设备"),
                ("LCD刷新频率怎么选？", "超过30fps人眼感觉流畅，嵌入式显示通常10~30fps，传感器数据1Hz刷新即可"),
            ]),
            ("memory", "传感器特性配对", [
                ("DHT11精度", "±2°C/±5%RH"),
                ("DHT22精度", "±0.5°C/±2%RH（更高）"),
                ("BMP280气压精度", "±1hPa，海拔精度±1m"),
                ("NTC测温范围", "-55°C到+150°C"),
                ("DS18B20精度", "±0.5°C（12位模式）"),
                ("MPU6050陀螺仪", "量程±250/500/1000/2000°/s"),
            ]),
        ],
        quiz_ref="q-p9-env",
        mm_children=[
            {"text": "传感器", "children": [{"text": "DHT11温湿度"}, {"text": "BMP280气压"}, {"text": "光照传感器"}]},
            {"text": "通信接口", "children": [{"text": "1-Wire单总线"}, {"text": "I2C"}, {"text": "SPI"}]},
            {"text": "数据处理", "children": [{"text": "滑动平均滤波"}, {"text": "单位换算"}, {"text": "LCD显示"}]},
        ],
        anim_data=[
            {"icon": "🌡️", "t": "DHT11单总线通信时序", "d": "MCU拉低18ms发起请求→DHT11回应80μs低+80μs高→发送40位数据（0=50+28μs，1=50+70μs）→最后校验和"},
            {"icon": "🔵", "t": "I2C总线读取BMP280", "d": "SCL时钟+SDA数据，7位地址（0x76）+读/写位→寄存器地址→读取原始温压值→通过补偿公式换算为摄氏度/帕斯卡"},
            {"icon": "📊", "t": "数据滤波：滑动平均", "d": "new_avg = (avg×(N-1) + new_sample) / N。N=8时，突变数据8次后才完全反映在输出上，有效消除尖峰噪声"},
            {"icon": "🖥️", "t": "多传感器系统架构", "d": "主循环时间片调度：10ms→读DHT11→100ms→读BMP280→50ms→刷新LCD，各模块独立运行，互不阻塞"},
        ],
        tags=["sensor", "i2c", "spi", "lcd", "environment"], minutes=60, difficulty="intermediate",
        code_lang="c", code_filename="env_monitor.c", code_snippet="""\
            /* 环境监测主循环（简化版）*/
            #include "main.h"
            #include "dht11.h"   /* 自定义单总线驱动 */
            #include "bmp280.h"  /* I2C驱动 */
            #include "lcd.h"     /* SPI LCD驱动 */

            typedef struct { uint8_t temp, humi; int32_t pressure; } EnvData;

            EnvData env_read(void) {
                EnvData d = {0};
                DHT11_Read(&d.temp, &d.humi);   /* 单总线，约20ms */
                d.pressure = BMP280_ReadPressure(); /* I2C读取，约5ms */
                return d;
            }

            /* 滑动平均滤波 N=8 */
            uint8_t temp_filter(uint8_t new_val) {
                static uint8_t buf[8] = {25};
                static uint8_t idx = 0;
                buf[idx++ % 8] = new_val;
                uint16_t sum = 0;
                for(int i=0;i<8;i++) sum+=buf[i];
                return sum / 8;
            }

            void env_task(void) {       /* 每1s调用一次 */
                EnvData d = env_read();
                uint8_t tf = temp_filter(d.temp);
                LCD_Printf(0,0,"Temp: %dC  Humi:%d%%", tf, d.humi);
                LCD_Printf(0,16,"Press:%ldPa", d.pressure);
            }
        """,
        exp_steps_simple=[
            step(1, "接线DHT11", "PA0→DHT11 DATA（接4.7kΩ上拉到3.3V），VCC→3.3V，GND→GND。", chk=True),
            step(2, "I2C连接BMP280", "I2C1（PB6=SCL，PB7=SDA）接BMP280，地址0x76。", chk=True),
            step(3, "读取并显示", "主循环中每1s调用env_task()，串口打印温度/湿度/气压，LCD刷新显示。", chk=True),
            step(4, "验证滤波效果", "用嘴对DHT11哈气，观察温度滑动平均值与原始值的差异（平滑延迟）。", chk=False),
        ]
    )]


