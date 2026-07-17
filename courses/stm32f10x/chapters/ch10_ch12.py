# -*- coding: utf-8 -*-
"""
build_p10_pages / build_p11_pages / build_p12_pages
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

def build_p10_pages():
    """项目10：无人停车场"""
    return [make_simple_page(
        "p10-parking", "10.1 无人停车场控制系统", "无人停车场系统",
        key_points=[
            "HC-SR04超声波测距：TRIG发10μs脉冲→ECHO高电平时间×0.034/2=距离(cm)",
            "SPI通信协议：4线同步（MOSI/MISO/SCK/CS），全双工，速率可达18Mbps",
            "NFC模块（RC522）：SPI接口，读取IC卡UID实现身份识别",
            "舵机控制闸机：50Hz PWM，脉宽0.5ms(0°)~2.5ms(180°)",
            "状态机设计：IDLE→DETECT→OPEN→WAIT→CLOSE，防止并发冲突",
        ],
        md_body="""\
            # 10.1 无人停车场控制系统

            ## 10.1.1 SPI通信协议

            SPI（Serial Peripheral Interface）是一种高速同步串行通信协议，由Motorola提出。

            ### SPI四线定义

            | 信号线 | 方向 | 功能 |
            |--------|------|------|
            | MOSI | 主→从 | Master Out Slave In，主设备发送数据 |
            | MISO | 从→主 | Master In Slave Out，从设备返回数据 |
            | SCK | 主→从 | 时钟信号，由主设备产生 |
            | CS/NSS | 主→从 | 片选，低电平有效，选中从设备 |

            ### SPI vs I2C vs UART 对比

            | 特性 | SPI | I2C | UART |
            |------|-----|-----|------|
            | 线数 | 4线（+每从设备1根CS） | 2线（SDA+SCL） | 2线（TX+RX） |
            | 速率 | 最高18Mbps | 标准100k/快速400k | 通常≤1Mbps |
            | 拓扑 | 一主多从（独立CS） | 多主多从（地址寻址） | 点对点 |
            | 全双工 | ✅ 是 | ❌ 半双工 | ✅ 是 |
            | 复杂度 | 低（无地址/应答） | 中（地址+ACK） | 低 |

            ### STM32 SPI配置要点
            ```c
            /* CubeMX配置：SPI1, Full-Duplex Master */
            /* SCK=PA5, MISO=PA6, MOSI=PA7, CS=PA4(GPIO) */
            /* Prescaler=16 → 72MHz/16 = 4.5MHz */
            /* CPOL=0, CPHA=0 (Mode 0，最常用) */

            /* 手动控制CS（HAL不自动管理NSS） */
            HAL_GPIO_WritePin(GPIOA, GPIO_PIN_4, GPIO_PIN_RESET); /* CS拉低 */
            HAL_SPI_TransmitReceive(&hspi1, tx_buf, rx_buf, len, 100);
            HAL_GPIO_WritePin(GPIOA, GPIO_PIN_4, GPIO_PIN_SET);   /* CS拉高 */
            ```

            ## 10.1.2 HC-SR04超声波传感器

            | 参数 | HC-SR04规格 |
            |------|------------|
            | 工作电压 | 5V DC |
            | 静态电流 | <2mA |
            | 测距范围 | **2cm~400cm** |
            | 精度 | ±3mm |
            | 感应角度 | <15° |
            | 触发信号 | 10μs TTL高电平脉冲 |
            | 回响信号 | 与距离成正比的TTL高电平 |

            ### 测距原理

            ```
            MCU发送 ──→ [TRIG 10μs高脉冲] ──→ HC-SR04发射8个40kHz超声波
                                                    ↓
            MCU接收 ←── [ECHO高电平持续时间t] ←── 超声波遇障碍物反射回来
            ```

            **距离计算**：
            ```
            距离(cm) = ECHO高电平时间(μs) × 声速(340m/s) / 2
                     = t(μs) × 0.034 / 2
                     = t(μs) / 58.8

            示例：ECHO持续580μs → 距离 = 580/58.8 ≈ 9.86cm ≈ 10cm
            ```

            > ⚠️ **注意**：HC-SR04的ECHO输出为5V电平！STM32是3.3V系统，必须用分压电路：
            > ECHO → [1kΩ] → PA1 → [2kΩ] → GND（分压后最大3.3V）

            ## 10.1.3 NFC模块（MFRC522）

            MFRC522是NXP的非接触式读卡芯片，支持ISO14443A标准，通过SPI与MCU通信。

            **关键操作流程**：
            1. 寻卡（PICC_REQIDL）→ 返回卡类型
            2. 防冲突（PICC_ANTICOLL）→ 获取4字节UID
            3. 选卡（PICC_SElECTTAG）→ 建立通信
            4. 认证（PICC_AUTHENT1A）→ 密钥验证
            5. 读写数据块

            ## 10.1.4 停车场状态机设计

            ```c
            typedef enum {
                STATE_IDLE,      /* 空闲：等待车辆 */
                STATE_DETECT,    /* 检测：确认车辆存在（防误触发）*/
                STATE_NFC_WAIT,  /* 等待刷卡（超时10s自动取消）*/
                STATE_GATE_OPEN, /* 开闸：舵机转90° */
                STATE_PASSING,   /* 通行中：等待车辆通过 */
                STATE_GATE_CLOSE /* 关闸：舵机回0° */
            } ParkingState;
            ```

            **状态转换条件**：
            - IDLE→DETECT：超声波距离<20cm持续200ms
            - DETECT→NFC_WAIT：确认车辆存在
            - NFC_WAIT→GATE_OPEN：读到有效NFC卡UID
            - GATE_OPEN→PASSING：延时2s后检测车辆是否通过
            - PASSING→GATE_CLOSE：超声波距离>50cm（车已通过）
            - GATE_CLOSE→IDLE：舵机回位完成
        """,
        games_data=[
            ("ordering", "停车场系统开发步骤：", [
                "HC-SR04接入PA0（TRIG）和PA1（ECHO）",
                "用输入捕获或Delay测量ECHO高电平时间",
                "计算距离：distance = time_us × 0.034 / 2（cm）",
                "距离<20cm时触发进出车检测逻辑",
                "控制舵机PWM开关闸机",
                "更新LCD显示剩余车位数",
            ]),
            ("matching", "超声波传感器信号连线：", [
                ("TRIG", "触发引脚，接受10μs脉冲"),
                ("ECHO", "回波引脚，输出高电平时间"),
                ("高电平持续时间", "正比于距离"),
                ("距离公式", "time_us × 340 / 2 (mm)"),
                ("最大测量距离", "约4米（HC-SR04）"),
                ("盲区距离", "约2cm内无法检测"),
            ]),
            ("classification", "停车场状态机状态分类：",
                {"idle": "空闲状态", "active": "活动状态", "error": "异常状态"},
                [("st1", "无车辆，等待检测", "idle"),
                 ("st2", "检测到障碍物，触发计数", "active"),
                 ("st3", "闸机正在开启", "active"),
                 ("st4", "车位已满，拒绝进入", "error"),
                 ("st5", "传感器超时未响应", "error"),
                 ("st6", "车辆通过，闸机关闭", "idle")]),
            ("flashcard", "停车场系统知识卡", [
                ("HC-SR04测距原理？", "发出40kHz超声波脉冲，测量回波时间，距离=时间×声速/2=时间×0.034/2(cm)"),
                ("舵机控制信号要求？", "50Hz（20ms周期），脉宽0.5ms=0°，1.5ms=90°，2.5ms=180°"),
                ("状态机的优势是什么？", "明确的状态转换逻辑，避免竞争条件，易于调试和维护"),
                ("如何防止假触发？", "连续N次检测到距离<阈值才确认，消除短暂干扰"),
            ]),
        ],
        quiz_ref="q-p10-parking",
        mm_children=[
            {"text": "传感器", "children": [{"text": "HC-SR04超声波"}, {"text": "红外对管（可选）"}]},
            {"text": "执行器", "children": [{"text": "舵机闸机"}, {"text": "LCD显示"}, {"text": "蜂鸣器提示"}]},
            {"text": "控制逻辑", "children": [{"text": "状态机"}, {"text": "车位计数"}, {"text": "满位保护"}]},
        ],
        anim_data=[
            {"icon": "🔊", "t": "超声波测距工作原理", "d": "TRIG输出10μs高电平触发→传感器发出8个40kHz超声波→声波遇障碍物反射→ECHO输出高电平（持续时间=声波往返时间）"},
            {"icon": "🚧", "t": "闸机舵机控制", "d": "50Hz PWM，周期20ms。脉宽0.5ms→0°（关）→1.5ms→90°（中位）→2.0ms（开）。HAL_TIM_SET_COMPARE控制脉宽"},
            {"icon": "🚗", "t": "车辆进出状态机", "d": "IDLE：等待→DETECT：超声波<20cm→OPEN：舵机开启→WAIT：等待车辆通过→CLOSE：关闭→计数更新→IDLE"},
            {"icon": "📊", "t": "系统整体架构", "d": "主循环：100ms检测超声波→判断状态→控制舵机→更新LCD。定时器中断：精确计时ECHO脉宽"},
        ],
        tags=["ultrasonic", "servo", "state-machine", "parking"], minutes=60, difficulty="intermediate",
        code_lang="c", code_filename="parking.c", code_snippet="""\
            /* 停车场核心逻辑 */
            #include "main.h"

            #define TRIG_PIN GPIO_PIN_0
            #define ECHO_PIN GPIO_PIN_1
            #define MAX_SPACES 10

            int spaces = MAX_SPACES;  /* 剩余车位数 */

            /* HC-SR04测距（cm），需要Delay_us支持 */
            float hcsr04_measure(void) {
                /* 发10us触发脉冲 */
                HAL_GPIO_WritePin(GPIOA, TRIG_PIN, GPIO_PIN_SET);
                delay_us(10);
                HAL_GPIO_WritePin(GPIOA, TRIG_PIN, GPIO_PIN_RESET);
                /* 等待ECHO上升沿 */
                uint32_t t = HAL_GetTick();
                while(!HAL_GPIO_ReadPin(GPIOA,ECHO_PIN) && HAL_GetTick()-t<50);
                uint32_t start = DWT->CYCCNT;  /* 精确计时（需使能DWT）*/
                while( HAL_GPIO_ReadPin(GPIOA,ECHO_PIN) && HAL_GetTick()-t<100);
                uint32_t end = DWT->CYCCNT;
                float us = (end-start) / 72.0f;  /* 72MHz → us */
                return us * 0.034f / 2.0f;        /* 单位 cm */
            }

            /* 状态机主循环 */
            typedef enum{IDLE,DETECT,OPEN,WAIT,CLOSE} State;
            void parking_task(void) {
                static State state = IDLE;
                static uint32_t t_open = 0;
                float dist = hcsr04_measure();
                switch(state) {
                    case IDLE:
                        if(dist < 20.0f && spaces > 0) { state=DETECT; }
                        break;
                    case DETECT:
                        if(dist < 20.0f) {
                            servo_set_angle(90);  /* 开闸 */
                            spaces--;  t_open=HAL_GetTick(); state=OPEN;
                        } else state=IDLE;
                        break;
                    case OPEN:
                        if(HAL_GetTick()-t_open > 3000) state=CLOSE;
                        break;
                    case CLOSE:
                        servo_set_angle(0); /* 关闸 */ state=IDLE;
                        break;
                }
                lcd_show_spaces(spaces);
            }
        """,
        exp_steps_simple=[
            step(1, "连接HC-SR04", "TRIG→PA0，ECHO→PA1，VCC→5V，GND→GND。注意ECHO输出5V，需要分压到3.3V（1kΩ+2kΩ）。", chk=True),
            step(2, "连接舵机", "舵机信号线→TIM2_CH1(PA0复用），红线→5V，棕线→GND。", chk=True),
            step(3, "测试测距", "先单独测试hcsr04_measure()，串口打印距离，用手挡测验证值。", chk=True),
            step(4, "完整测试", "运行parking_task()，用手模拟车辆进出，观察LCD车位数变化和舵机动作。", chk=True),
        ]
    )]


def build_p11_pages():
    """项目11：运动手环"""
    p11_band = make_simple_page(
        "p11-band", "11.1 运动手环设计与实现", "运动手环系统",
        key_points=[
            "LSM6DS3六轴IMU：I2C接口(0x6A)，加速度±2/4/8/16g，陀螺仪±125~2000dps",
            "PPG光电容积传感器：绿光LED+光电二极管，检测血液容积变化提取心率",
            "峰值检测计步算法：合加速度>阈值且前后值小→计步+1（需300ms防抖）",
            "OLED显示（SSD1306 I2C）：128×64像素，显示步数/心率/卡路里",
            "低功耗设计：STOP模式<50μA，加速度中断唤醒（WOM功能）",
        ],
        md_body="""\
            # 11.1 运动手环设计与实现

            ## 11.1.1 LSM6DS3六轴传感器

            LSM6DS3是STMicroelectronics生产的高性能6轴惯性测量单元（IMU），集成3轴加速度计和3轴陀螺仪。

            | 参数 | LSM6DS3规格 |
            |------|------------|
            | 接口 | I2C（地址**0x6A**/0x6B）或 SPI |
            | 加速度量程 | ±2g / ±4g / ±8g / ±16g |
            | 陀螺仪量程 | ±125 / ±245 / ±500 / ±1000 / ±2000 dps |
            | ODR（输出数据率） | 12.5Hz ~ 6.66kHz |
            | 工作电压 | 1.71~3.6V |
            | 功耗 | 0.9mA（高性能模式）/ 0.4mA（低功耗） |
            | WHO_AM_I (0x0F) | 返回 **0x69** |
            | 温度传感器 | 内置，精度±1°C |

            ### 关键寄存器

            | 地址 | 名称 | 功能 |
            |------|------|------|
            | 0x0F | WHO_AM_I | 器件ID（读到0x69确认连接正常） |
            | 0x10 | CTRL1_XL | 加速度计控制（ODR+量程） |
            | 0x11 | CTRL2_G | 陀螺仪控制（ODR+量程） |
            | 0x28~0x2D | OUTX/Y/Z_L/H_XL | 加速度数据（6字节） |
            | 0x22~0x27 | OUTX/Y/Z_L/H_G | 陀螺仪数据（6字节） |

            ### I2C初始化代码
            ```c
            /* 检测连接 */
            uint8_t who = 0;
            HAL_I2C_Mem_Read(&hi2c1, 0x6A<<1, 0x0F, 1, &who, 1, 100);
            if (who != 0x69) { /* 连接失败！检查接线 */ }

            /* 配置：加速度104Hz/±8g，陀螺仪104Hz/±500dps */
            uint8_t ctrl1 = 0x44; /* ODR=104Hz, FS=±8g */
            HAL_I2C_Mem_Write(&hi2c1, 0x6A<<1, 0x10, 1, &ctrl1, 1, 100);
            uint8_t ctrl2 = 0x44; /* ODR=104Hz, FS=±500dps */
            HAL_I2C_Mem_Write(&hi2c1, 0x6A<<1, 0x11, 1, &ctrl2, 1, 100);
            ```

            ## 11.1.2 PPG光电容积传感器

            PPG（Photoplethysmography）通过光学原理测量血液容积变化：

            **工作原理**：
            1. 绿光LED（波长520~560nm）照射皮肤
            2. 血液中血红蛋白吸收绿光，吸收率随心跳周期变化
            3. 光电二极管接收反射光，转换为电信号
            4. ADC采样信号波形，提取心率

            **信号处理流程**：
            ```
            原始信号 → 带通滤波(0.5~5Hz) → 峰值检测 → 计算RR间期 → 心率(BPM)
            ```

            心率计算：`HR(BPM) = 60 / RR间期(秒)`

            ## 11.1.3 峰值检测计步算法

            计步的核心思想：行走时，人体加速度呈现周期性峰值变化。

            ### 算法步骤

            1. **读取三轴加速度**：ax, ay, az（原始值，±8g量程时LSB=0.244mg）
            2. **计算合加速度**：`mag = √(ax² + ay² + az²)`
            3. **峰值检测**：当前值>前一个值 且 前一个值<前前一个值 → 检测到峰
            4. **阈值判断**：峰值 > 1.2g（排除手臂微小晃动）
            5. **时间防抖**：距上次计步 > 300ms（正常步频<3.3步/秒）
            6. **计步+1**

            ```c
            #define STEP_THRESHOLD  1.2f   /* g */
            #define MIN_INTERVAL    300    /* ms */

            float calc_magnitude(int16_t ax, int16_t ay, int16_t az) {
                float x = ax * 0.000244f;  /* ±8g: 1LSB = 0.244mg */
                float y = ay * 0.000244f;
                float z = az * 0.000244f;
                return sqrtf(x*x + y*y + z*z);
            }
            ```

            ### 卡路里估算
            ```
            卡路里(kcal) ≈ 步数 × 步长(m) × 体重(kg) × 0.000857
            ```

            ## 11.1.4 低功耗设计

            运动手环需要长续航，STM32F103提供多种低功耗模式：

            | 模式 | 功耗 | 唤醒方式 | 恢复时间 |
            |------|------|---------|---------|
            | Sleep | ~1.5mA | 任意中断 | <1μs |
            | Stop | **~50μA** | EXTI/RTC | ~5μs |
            | Standby | ~3μA | WKUP引脚/RTC | 复位重启 |

            **推荐方案**：Stop模式 + LSM6DS3的WOM（Wake-on-Motion）中断
            - 静止时MCU进入Stop模式，功耗<50μA
            - 用户开始运动→LSM6DS3检测到加速度变化→INT1引脚拉高→EXTI唤醒MCU
            - 运动结束后10秒无动作→重新进入Stop模式

            ```c
            /* 进入Stop模式 */
            HAL_SuspendTick();
            HAL_PWR_EnterSTOPMode(PWR_LOWPOWERREGULATOR_ON, PWR_STOPENTRY_WFI);
            /* 唤醒后恢复时钟 */
            SystemClock_Config();
            HAL_ResumeTick();
            ```
        """,
        games_data=[
            ("matching", "MPU6050关键寄存器连线：", [
                ("0x3B", "加速度X轴高字节"),
                ("0x43", "陀螺仪X轴高字节"),
                ("0x6B", "电源管理寄存器（需清除sleep位）"),
                ("0x75", "WHO_AM_I（返回0x68确认连接）"),
                ("0x19", "采样率分频器"),
                ("0x1B", "陀螺仪量程配置"),
            ]),
            ("ordering", "运动手环软件流程：", [
                "I2C初始化，检测MPU6050连接（读WHO_AM_I=0x68）",
                "配置MPU6050：采样率100Hz，量程±8g/500dps",
                "主循环10ms读一次加速度数据",
                "计算合加速度：√(ax²+ay²+az²)",
                "峰值检测：合力>阈值且前后值小于阈值→计步+1",
                "OLED每秒更新显示步数和卡路里",
            ]),
            ("flashcard", "运动手环技术知识卡", [
                ("MPU6050 I2C地址？", "AD0接GND时0x68，AD0接VCC时0x69"),
                ("加速度1g等于多少？", "1g=9.8m/s²，MPU6050量程±2g时，32768对应2g，即LSB=1/16384 g/LSB"),
                ("计步算法核心思路？", "检测合加速度的峰值，超过阈值且上次峰值已过期（防抖）则计步+1"),
                ("STM32低功耗STOP模式？", "保持SRAM和寄存器值，外设时钟关闭，功耗<50μA，中断可唤醒"),
            ]),
            ("classification", "运动手环功能分类：",
                {"measure": "运动测量", "display": "信息显示", "power": "电源管理"},
                [("b1", "MPU6050加速度采集", "measure"),
                 ("b2", "OLED显示步数", "display"),
                 ("b3", "STOP低功耗模式", "power"),
                 ("b4", "峰值检测计步算法", "measure"),
                 ("b5", "WOM加速度中断唤醒", "power"),
                 ("b6", "卡路里计算公式", "measure")]),
            ("memory", "IMU传感器术语配对", [
                ("IMU", "惯性测量单元"),
                ("DMP", "数字运动处理器（内置姿态解算）"),
                ("量程±2g", "±2×9.8=±19.6 m/s²"),
                ("陀螺仪漂移", "静止时仍有小角速度输出"),
                ("互补滤波", "加速度+陀螺仪融合，消除各自误差"),
                ("WOM", "运动唤醒功能，加速度超阈值唤醒"),
            ]),
        ],
        quiz_ref="q-p11-band",
        mm_children=[
            {"text": "MPU6050", "children": [{"text": "3轴加速度"}, {"text": "3轴陀螺仪"}, {"text": "I2C@400kHz"}]},
            {"text": "功能模块", "children": [{"text": "步数计算"}, {"text": "卡路里估算"}, {"text": "OLED显示"}]},
            {"text": "低功耗", "children": [{"text": "STOP模式"}, {"text": "WOM中断唤醒"}, {"text": "动态时钟控制"}]},
        ],
        anim_data=[
            {"icon": "🏃", "t": "MPU6050步数检测原理", "d": "100Hz采样加速度→合力=√(ax²+ay²+az²)→检测峰值（走步时合力曲线呈波峰）→峰值>阈值且有效间隔→步数+1"},
            {"icon": "📐", "t": "IMU姿态角解算", "d": "加速度仪可测量静态倾角（但有噪声），陀螺仪可积分得角度（但有漂移），互补滤波融合两者：angle=0.98×(angle+gyro×dt)+0.02×accel_angle"},
            {"icon": "💤", "t": "低功耗设计", "d": "正常工作→检测到静止状态→进入STOP模式（功耗<50μA）→MPU6050 WOM检测到运动→产生中断→唤醒STM32→恢复工作"},
            {"icon": "🔋", "t": "手环电源管理", "d": "3.7V锂电→升压5V→LDO降到3.3V给STM32。电量监测：ADC采样电池电压，估算剩余容量并显示在OLED"},
        ],
        tags=["imu", "mpu6050", "step-counter", "oled", "low-power"], minutes=60, difficulty="advanced",
        code_lang="c", code_filename="step_counter.c", code_snippet="""\
            /* 计步器核心算法 */
            #include "main.h"
            #include "mpu6050.h"

            #define STEP_THRESHOLD  1.2f   /* g，合加速度阈值 */
            #define STEP_MIN_INTERVAL 300  /* ms，防抖最小步间隔 */

            uint32_t step_count = 0;
            uint32_t calories = 0;    /* ×10，精度0.1kcal */

            /* 计算合加速度（g） */
            float calc_magnitude(int16_t ax, int16_t ay, int16_t az) {
                float x = ax / 16384.0f;  /* ±2g量程 */
                float y = ay / 16384.0f;
                float z = az / 16384.0f;
                return sqrtf(x*x + y*y + z*z);
            }

            /* 峰值检测计步（100Hz调用）*/
            void step_detect(void) {
                static float prev = 1.0f, pprev = 1.0f;
                static uint32_t last_step_time = 0;
                static bool in_peak = false;

                int16_t ax, ay, az;
                MPU6050_ReadAccel(&ax, &ay, &az);
                float mag = calc_magnitude(ax, ay, az);

                /* 检测峰值：当前 > 前两个 且 超过阈值 */
                if (mag > STEP_THRESHOLD && mag > prev && prev > pprev && !in_peak) {
                    uint32_t now = HAL_GetTick();
                    if (now - last_step_time > STEP_MIN_INTERVAL) {
                        step_count++;
                        calories += 5;  /* 约0.5kcal/百步 */
                        last_step_time = now;
                    }
                    in_peak = true;
                } else if (mag < STEP_THRESHOLD) {
                    in_peak = false;
                }
                pprev = prev; prev = mag;
            }
        """,
        exp_steps_simple=[
            step(1, "连接MPU6050", "I2C1（PB6=SCL，PB7=SDA）接MPU6050，AD0接GND（地址0x68），VCC→3.3V。", chk=True),
            step(2, "初始化验证", "读取WHO_AM_I寄存器0x75，返回0x68说明连接成功。", chk=True),
            step(3, "测试加速度", "串口打印ax/ay/az原始值，静止时az应≈16384（1g），ax/ay应≈0。",
                 "MPU6050_ReadAccel(&ax,&ay,&az);\nprintf(\"%d %d %d\\r\\n\",ax,ay,az);", True),
            step(4, "计步测试", "运行step_detect()，走动手机，OLED显示步数与预期对比（误差<5%）。", chk=True),
        ]
    )
    p11_band["game"] = {
        "modeId": "godot-game",
        "levelId": "ch11-band-defense-alpha",
        "title": "手环数据链路防线（互动练习 / Alpha 版）",
        "objective": "互动练习：综合复习 IMU 初始化、滤波抑噪、峰值计步与低功耗唤醒",
        "difficulty": 3,
        "starThresholds": [50, 75, 90],
        "timeLimit": 0,
        "data": {
            "gameId": "ch11-band-defense",
            "entryUrl": "/assets/godot/ch11-band-defense/index.html?v=63b6c0e60cd2",
            "aspectRatio": "16 / 9",
            "deliveryStage": "alpha",
            "maxLeaks": 8,
            "waveCount": 9,
            "knowledgeSource": "external",
            "questionsUrl": "/assets/courses/stm32-course/knowledge/ch11-band-defense.questions.json?v=038e961fb803",
        },
    }
    return [p11_band]


def build_p12_pages():
    """项目12：追光系统"""
    return [make_simple_page(
        "p12-suntrack", "12.1 太阳追踪控制系统", "追光系统",
        key_points=[
            "四象限光敏传感器：4个光敏电阻分布在十字遮光板四周，差值反映光源方向",
            "PID控制算法：比例P+积分I+微分D，消除稳态误差，实现平滑追踪",
            "双轴云台：水平轴（方位角）+垂直轴（仰角），各由一个舵机控制",
            "ADC多通道扫描：同时采集4路光敏传感器数据，DMA自动搬移",
            "系统调参：PID参数整定，从纯P开始，加I消稳态误差，加D减震荡",
        ],
        md_body="""\
            # 12.1 太阳追踪控制系统

            ## 12.1.1 舵机工作原理与PWM控制

            SG90舵机是一种位置伺服电机，通过PWM信号控制转动角度。

            | 参数 | SG90规格 |
            |------|---------|
            | 工作电压 | 4.8~6V |
            | 控制信号 | 50Hz PWM（周期20ms） |
            | 脉宽范围 | 0.5ms(0°) ~ 1.5ms(90°) ~ 2.5ms(180°) |
            | 转速 | 0.12s/60°（4.8V） |
            | 扭矩 | 1.8 kg·cm（4.8V） |

            ### STM32 PWM配置（50Hz舵机）

            ```
            系统时钟 = 72MHz
            PSC = 71  → 计数频率 = 72MHz/72 = 1MHz（1μs/计数）
            ARR = 19999 → 周期 = 20000μs = 20ms = 50Hz ✓

            角度→CCR转换：
            CCR = 500 + angle × (2500-500) / 180
            0°  → CCR = 500  (脉宽0.5ms)
            90° → CCR = 1500 (脉宽1.5ms)
            180°→ CCR = 2500 (脉宽2.5ms)
            ```

            ## 12.1.2 四象限光敏传感器阵列

            四个光敏电阻（LDR）分布在十字遮光板的四个象限：

            ```
                    ┌───┬───┐
                    │LT │RT │  ← 上方两个
                    ├───┼───┤  ← 十字遮光板
                    │LB │RB │  ← 下方两个
                    └───┴───┘
            ```

            **方向判断逻辑**：
            - **水平误差** = (LT+LB) - (RT+RB)
              - 正值 → 光在左侧 → 向左转
              - 负值 → 光在右侧 → 向右转
            - **垂直误差** = (LT+RT) - (LB+RB)
              - 正值 → 光在上方 → 向上转
              - 负值 → 光在下方 → 向下转

            **死区设计**：误差绝对值<50时不动作，防止在光源正对时来回抖动。

            ### ADC多通道DMA配置
            ```c
            /* CubeMX：ADC1, 4通道扫描模式, DMA循环传输 */
            /* CH0=PA0(LT), CH1=PA1(RT), CH2=PA2(LB), CH3=PA3(RB) */
            uint32_t adc_buf[4];  /* DMA自动填充 */
            HAL_ADC_Start_DMA(&hadc1, adc_buf, 4);
            /* 之后adc_buf[0]~[3]自动更新，无需手动读取 */
            ```

            ## 12.1.3 PID控制算法原理

            PID（Proportional-Integral-Derivative）是工业控制中最经典的闭环控制算法。

            ### 三个分量的作用

            | 分量 | 公式 | 作用 | 调大的效果 |
            |------|------|------|-----------|
            | **P（比例）** | Kp × error | 快速响应误差 | 响应快，但可能震荡 |
            | **I（积分）** | Ki × ∫error·dt | 消除稳态误差 | 消除偏差，但可能超调 |
            | **D（微分）** | Kd × d(error)/dt | 预测趋势，抑制震荡 | 减少超调，但对噪声敏感 |

            ### PID输出公式
            ```
            output = Kp × error + Ki × ∫error·dt + Kd × d(error)/dt
            ```

            ### 离散化实现（嵌入式中使用）
            ```c
            float pid_calc(PID_t *pid, float error, float dt) {
                /* 积分累加 */
                pid->integral += error * dt;
                /* 积分限幅（防止积分饱和/windup）*/
                if (pid->integral > 100) pid->integral = 100;
                if (pid->integral < -100) pid->integral = -100;
                /* 微分 */
                float derivative = (error - pid->prev_error) / dt;
                /* PID输出 */
                float output = pid->Kp * error
                             + pid->Ki * pid->integral
                             + pid->Kd * derivative;
                pid->prev_error = error;
                /* 输出限幅 */
                if (output > pid->out_max) output = pid->out_max;
                if (output < pid->out_min) output = pid->out_min;
                return output;
            }
            ```

            ## 12.1.4 系统调参方法

            **推荐调参步骤（Ziegler-Nichols简化法）**：

            1. **纯P调试**：Ki=0, Kd=0，逐渐增大Kp
               - Kp太小：追踪慢，有大偏差
               - Kp合适：能跟踪但有轻微震荡
               - Kp太大：剧烈震荡

            2. **加入I项**：固定Kp，逐渐增大Ki
               - 观察稳态误差是否消除
               - Ki太大会导致超调和低频震荡

            3. **加入D项**：固定Kp和Ki，逐渐增大Kd
               - 减少超调，使运动更平滑
               - Kd太大会放大传感器噪声

            **本项目推荐参数**（起始值，需根据实际调整）：
            ```c
            PID_t pid_h = {.Kp=1.5, .Ki=0.05, .Kd=0.2, .out_min=-45, .out_max=45};
            PID_t pid_v = {.Kp=1.2, .Ki=0.04, .Kd=0.15, .out_min=-30, .out_max=30};
            ```

            > 💡 **调参技巧**：先在室内用手电筒测试，确认方向正确后再到室外测试太阳追踪。
            > 室外光照变化缓慢，Ki可以设小一些。
        """,
        games_data=[
            ("matching", "PID控制参数连线：", [
                ("P（比例）", "误差越大输出越大，响应快但可能震荡"),
                ("I（积分）", "消除稳态误差，防止长期偏差"),
                ("D（微分）", "预测误差变化趋势，减少超调"),
                ("Kp过大", "系统振荡，不稳定"),
                ("Ki过大", "积分饱和，响应缓慢"),
                ("Kd过大", "对噪声过度敏感"),
            ]),
            ("ordering", "追光系统控制流程：", [
                "ADC采集4路光敏传感器值（LT/RT/LB/RB）",
                "计算误差：水平误差=(LT+LB)-(RT+RB)，垂直误差=(LT+RT)-(LB+RB)",
                "PID计算：output = Kp×err + Ki×∫err + Kd×(err-prev_err)",
                "限幅：将PID输出限制在舵机可接受范围",
                "更新舵机PWM脉宽",
                "延时控制周期（如50ms=20Hz控制频率）",
            ]),
            ("flashcard", "追光系统知识卡", [
                ("为什么用4个光敏而不是1个？", "1个只能感知亮度，4个分布在十字板四周，通过差值可感知光源方向（角度信息）"),
                ("PID中积分项的作用？", "将历史误差累积，当稳态误差持续存在时，I项不断增大直到消除误差"),
                ("舵机云台有死区吗？", "是的，PWM变化量太小时舵机不响应（约10μs），PID输出需要设置死区消除抖动"),
                ("什么是抗积分饱和？", "当执行机构已经到达极限，误差还在累积会导致积分过大。需要限制积分项的范围"),
            ]),
            ("classification", "PID调参诊断：",
                {"kp": "Kp问题", "ki": "Ki问题", "kd": "Kd问题"},
                [("pid1", "系统有稳态误差，无法到达目标", "ki"),
                 ("pid2", "系统快速振荡，不稳定", "kp"),
                 ("pid3", "超调后长时间震荡收敛", "kd"),
                 ("pid4", "响应太慢，像蜗牛爬行", "kp"),
                 ("pid5", "对轻微扰动反应过度", "kd"),
                 ("pid6", "长时间运行后偏差越来越大", "ki")]),
            ("memory", "控制系统术语配对", [
                ("稳态误差", "系统稳定后仍存在的偏差"),
                ("超调量", "响应超过目标值的最大幅度"),
                ("调节时间", "系统达到稳定所需时间"),
                ("死区", "输入变化量小于阈值时无响应"),
                ("开环控制", "无反馈，只按目标执行"),
                ("闭环控制", "有反馈，实时调整输出"),
            ]),
        ],
        quiz_ref="q-p12-suntrack",
        mm_children=[
            {"text": "传感器", "children": [{"text": "四象限光敏"}, {"text": "ADC多路采集"}]},
            {"text": "执行器", "children": [{"text": "水平舵机"}, {"text": "垂直舵机"}, {"text": "双轴云台"}]},
            {"text": "控制算法", "children": [{"text": "PID控制"}, {"text": "误差计算"}, {"text": "参数整定"}]},
        ],
        anim_data=[
            {"icon": "☀️", "t": "四象限光敏传感器原理", "d": "4个光敏电阻分布在十字遮光板四角（LT/RT/LB/RB）。光源偏左时，LT+LB>RT+RB，误差为正→舵机向左转"},
            {"icon": "🎯", "t": "PID控制原理", "d": "error=目标-实际。P项：比例调节（快速响应）；I项：积分（消除稳态误差）；D项：微分（减少超调）。三者之和为控制量"},
            {"icon": "🔄", "t": "追光控制闭环", "d": "采集光强→计算误差→PID计算→限幅→输出舵机PWM→云台转动→改变光敏接收光强→重新采集，构成反馈环路"},
            {"icon": "⚙️", "t": "PID参数整定方法", "d": "先将Ki=Kd=0，只用P控制，增大Kp到临界振荡→降低Kp到稳定→加小Ki消除稳态误差→加小Kd减少超调"},
        ],
        tags=["pid", "servo", "adc", "tracking", "control"], minutes=60, difficulty="advanced",
        code_lang="c", code_filename="pid_tracker.c", code_snippet="""\
            /* 追光系统 PID控制器 */
            #include "main.h"

            /* 四象限光敏ADC通道：LT=CH0,RT=CH1,LB=CH2,RB=CH3 */
            uint32_t adc_buf[4];  /* DMA接收缓冲 */

            typedef struct {
                float Kp, Ki, Kd;
                float integral, prev_error;
                float out_min, out_max;
            } PID_t;

            float pid_calc(PID_t *pid, float error, float dt) {
                pid->integral += error * dt;
                /* 积分限幅（防积分饱和）*/
                if(pid->integral > 100) pid->integral = 100;
                if(pid->integral <-100) pid->integral =-100;
                float deriv = (error - pid->prev_error) / dt;
                float out = pid->Kp*error + pid->Ki*pid->integral + pid->Kd*deriv;
                pid->prev_error = error;
                /* 输出限幅 */
                if(out > pid->out_max) out = pid->out_max;
                if(out < pid->out_min) out = pid->out_min;
                return out;
            }

            PID_t pid_h = {1.5f, 0.05f, 0.2f, 0, 0, -45, 45}; /* 水平轴 */
            PID_t pid_v = {1.2f, 0.04f, 0.15f, 0, 0, -30, 30}; /* 垂直轴 */

            void tracker_task(void) {  /* 20Hz，每50ms调用一次 */
                /* 四路光敏值（ADC DMA已自动更新adc_buf）*/
                float LT=adc_buf[0], RT=adc_buf[1];
                float LB=adc_buf[2], RB=adc_buf[3];
                /* 误差计算 */
                float err_h = (LT+LB) - (RT+RB);  /* >0→光在左→向左转 */
                float err_v = (LT+RT) - (LB+RB);  /* >0→光在上→向上转 */
                /* 死区：误差太小不动（防抖动）*/
                if(fabsf(err_h) < 50) err_h = 0;
                if(fabsf(err_v) < 50) err_v = 0;
                /* PID控制舵机角度 */
                float out_h = pid_calc(&pid_h, err_h, 0.05f);
                float out_v = pid_calc(&pid_v, err_v, 0.05f);
                servo_h_set(90 + out_h);  /* 水平舵机（初始90°中位）*/
                servo_v_set(45 + out_v);  /* 垂直舵机（初始45°仰角）*/
            }
        """,
        exp_steps_simple=[
            step(1, "搭建四象限传感器", "4个光敏电阻+10kΩ分压，分别接ADC1 CH0~CH3（PA0~PA3）。用十字遮光板隔开。", chk=True),
            step(2, "ADC DMA多通道扫描", "CubeMX：ADC1→扫描模式，4路通道，DMA循环，配置adc_buf数组接收。", chk=True),
            step(3, "纯P测试", "Ki=Kd=0，只用Kp=1.5，用手电筒照射，观察云台是否跟踪方向。", chk=True),
            step(4, "加入I项调稳态误差", "发现稳定后仍有偏差，加入Ki=0.05消除，再加Kd=0.2减少超调。", chk=False),
        ]
    )]


# build_intro_page 和 build_extension_page 已迁移到 manifest/factories.py
# 通过文件头部的 from manifest.factories import ... 导入


# build_quizzes 已迁移到 manifest/quizzes.py
from manifest.quizzes import build_quizzes  # noqa: E402
