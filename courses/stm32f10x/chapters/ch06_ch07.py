# -*- coding: utf-8 -*-
"""
make_simple_page / build_p6_pages / build_p7_pages
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
from manifest.factories import quick_page, make_simple_page  # noqa: E402

# 注入 gen_manifest.py 中的 page/quiz 等基础函数（exec 兼容模式）
_GM_PATH = _os.path.join(_PUBLIC_DIR, 'gen_manifest.py')
exec(open(_GM_PATH, encoding='utf-8').read(), globals())


def build_p6_pages():
    return [
        make_simple_page(
            "p6-uart", "6.1 UART串口通信原理与实验", "UART串口",
            key_points=[
                "UART（通用异步收发传输器）不需要时钟线，通过约定波特率实现通信",
                "帧格式：起始位(0) + 数据位(8) + 校验位(可选) + 停止位(1) = 10bit/帧",
                "TX/RX交叉连接：设备A的TX接设备B的RX",
                "HAL轮询：HAL_UART_Transmit/Receive，中断：HAL_UART_Receive_IT，DMA：效率最高",
                "波特率必须双方一致，否则接收数据乱码",
            ],
            md_body="""\
                # 6.1 UART串口通信原理与实验

                ## 6.1.1 串口通信基本概念

                串口通信（Serial Communication）是电子工程中最常用的串行通信方法，它通过按位顺序发送和接收数据。
                UART（Universal Asynchronous Receiver/Transmitter，通用异步收发传输器）是串口通信的核心硬件模块。

                **UART的核心特点：**
                - **异步通信**：不需要时钟线（CLK），通过双方约定相同的波特率来同步
                - **全双工**：TX和RX独立工作，可同时发送和接收
                - **点对点**：一对一通信（不像I2C/SPI可以挂多个设备）

                ### 波特率（Baud Rate）

                波特率定义了每秒传输的比特数。常用波特率：

                | 波特率 | 每字节耗时 | 典型应用 |
                |--------|-----------|---------|
                | 9600 | ~1.04ms | 低速传感器、GPS模块 |
                | 115200 | ~86.8μs | 调试串口（最常用） |
                | 921600 | ~10.9μs | 高速数据传输 |
                | 1000000 | ~10μs | 蓝牙模块AT命令 |

                > ⚠️ **关键**：通信双方波特率必须完全一致！差异超过3%就会导致数据错误。

                ### 数据帧格式

                UART每发送一个字节，实际传输10个比特：

                ```
                空闲(高) → [起始位(低)] → [D0 D1 D2 D3 D4 D5 D6 D7] → [停止位(高)] → 空闲(高)
                           ↑ 1bit         ↑ 8bit数据（LSB先发）        ↑ 1bit
                ```

                - **起始位**：1个低电平bit，通知接收方"数据来了"
                - **数据位**：8bit，**LSB（最低位）先发**
                - **校验位**：可选（None/Odd/Even），工程中通常不用
                - **停止位**：1个高电平bit，标志帧结束

                **计算**：115200波特率，发送1字节 = 10bit / 115200 ≈ **86.8μs**

                ## 6.1.2 硬件连接

                STM32F103的USART1引脚：
                - **PA9** = USART1_TX（发送）
                - **PA10** = USART1_RX（接收）

                与USB-TTL模块（CH340/CP2102）的连接：

                ```
                STM32          USB-TTL模块
                PA9 (TX)  ───→  RX        ← 交叉连接！
                PA10 (RX) ←───  TX        ← 交叉连接！
                GND       ───→  GND       ← 必须共地！
                ```

                > 💡 **为什么要交叉？** 因为MCU的"发送"(TX)数据要被对方"接收"(RX)，所以TX必须连到对方的RX。

                ## 6.1.3 STM32 UART三种工作模式

                | 模式 | HAL函数 | 特点 | 适用场景 |
                |------|---------|------|---------|
                | 轮询 | HAL_UART_Transmit/Receive | 阻塞等待，简单 | 调试、少量数据 |
                | 中断 | HAL_UART_Transmit_IT/Receive_IT | 非阻塞，回调通知 | 实时响应命令 |
                | DMA | HAL_UART_Transmit_DMA/Receive_DMA | CPU不参与搬移 | 大批量高速传输 |

                ### 轮询模式详解

                ```c
                /* 发送：阻塞直到全部发完或超时 */
                HAL_UART_Transmit(&huart1, data, len, timeout_ms);

                /* 接收：阻塞直到收满len字节或超时 */
                HAL_StatusTypeDef ret = HAL_UART_Receive(&huart1, buf, len, timeout_ms);
                if (ret == HAL_OK) { /* 接收成功 */ }
                else if (ret == HAL_TIMEOUT) { /* 超时，未收满 */ }
                ```

                ## 6.1.4 printf重定向到串口

                嵌入式开发中，`printf`是最方便的调试手段。重定向步骤：

                1. **重写fputc函数**（标准库底层输出函数）
                2. **勾选Use MicroLIB**（Keil）或添加`-specs=nano.specs`（GCC）

                ```c
                /* 在main.c中添加 */
                int fputc(int ch, FILE *f) {
                    HAL_UART_Transmit(&huart1, (uint8_t*)&ch, 1, 100);
                    return ch;
                }
                /* 之后就可以直接使用printf */
                printf("ADC Value: %d, Voltage: %.2fV\\r\\n", adc_val, voltage);
                ```

                > ⚠️ **注意**：`\\r\\n`是Windows换行符，串口助手需要这两个字符才能正确换行。
            """,
            games_data=[
                ("ordering", "UART通信配置步骤排序：", [
                    "CubeMX中USART1→Asynchronous（异步模式）",
                    "设置波特率115200，8位数据，1停止位，无校验",
                    "使能USART1全局中断（中断模式需要）",
                    "Generate Code",
                    "在USER CODE中调用HAL_UART_Transmit发送字符串",
                    "用串口助手验证PC收到正确数据",
                ]),
                ("matching", "连线：UART信号线与功能", [
                    ("TX", "发送数据线"),
                    ("RX", "接收数据线"),
                    ("GND", "共地（必须连接！）"),
                    ("起始位", "低电平，标志帧开始"),
                    ("停止位", "高电平，标志帧结束"),
                    ("波特率", "每秒传输的比特数"),
                ]),
                ("classification", "UART三种工作模式的特点",
                    {"poll": "轮询模式", "it": "中断模式", "dma": "DMA模式"},
                    [("u1", "HAL_UART_Receive，阻塞等待", "poll"),
                     ("u2", "HAL_UART_Receive_IT，非阻塞", "it"),
                     ("u3", "效率最高，CPU不参与数据搬移", "dma"),
                     ("u4", "简单调试首选", "poll"),
                     ("u5", "适合中等数据量的实时接收", "it"),
                     ("u6", "大批量数据传输场合", "dma")]),
                ("flashcard", "📚 UART核心知识卡", [
                    ("115200波特率的含义？", "每秒传输115200个比特，发送1字节约需87μs"),
                    ("TX-RX为何要交叉连接？", "A发送(TX)的数据要被B接收(RX)，交叉后信号方向正确"),
                    ("重定向printf到串口的方法？", "重写fputc函数，在其中调用HAL_UART_Transmit，同时勾选Use MicroLIB"),
                    ("UART中断接收的关键？", "接收完成后必须重新调用HAL_UART_Receive_IT，否则只接收一次"),
                ]),
                ("memory", "🃏 串口相关术语配对", [
                    ("USART", "通用同步/异步收发传输器"),
                    ("波特率", "Baud Rate，比特/秒"),
                    ("RS232", "电平±15V的串口物理标准"),
                    ("RS485", "差分信号，传输距离1200m"),
                    ("USB-TTL", "串口转USB模块（CH340）"),
                    ("半双工", "同一时刻只能发或收"),
                ]),
            ],
            quiz_ref="q-p6-uart",
            mm_children=[
                {"text": "帧格式", "children": [{"text": "起始位(0)"}, {"text": "8数据位"}, {"text": "停止位(1)"}]},
                {"text": "工作模式", "children": [{"text": "轮询Polling"}, {"text": "中断IT"}, {"text": "DMA"}]},
                {"text": "接口标准", "children": [{"text": "TTL/3.3V"}, {"text": "RS232（±15V）"}, {"text": "RS485（差分）"}]},
            ],
            anim_data=[
                {"icon": "📡", "t": "UART异步通信原理", "d": "无时钟线，通过起始位同步。发送方在TX输出起始位(低)→8数据位（LSB先行）→停止位(高)；接收方在RX按波特率采样"},
                {"icon": "🔀", "t": "TX-RX交叉连接", "d": "MCU_TX→USB模块_RX，MCU_RX→USB模块_TX，GND相连。'交叉'是因为发送(TX)必须连接到对方的接收(RX)端"},
                {"icon": "⚡", "t": "三种接收模式对比", "d": "轮询：CPU等待完整数据（阻塞）；中断：数据来了MCU主动处理（推荐）；DMA：硬件自动搬移，CPU可干其他事"},
                {"icon": "🖥️", "t": "printf重定向到串口", "d": "重写fputc()：在其中调用HAL_UART_Transmit，就能用printf()直接打印到串口助手，方便调试"},
            ],
            tags=["uart", "serial", "communication"],
            code_lang="c", code_filename="uart_poll.c", code_snippet="""\
                /* UART轮询收发示例 */
                #include "main.h"
                #include <string.h>
                /* printf重定向到串口 */
                int fputc(int ch, FILE *f) {
                    HAL_UART_Transmit(&huart1, (uint8_t*)&ch, 1, 100);
                    return ch;
                }
                void uart_demo(void) {
                    uint8_t rx_buf[32] = {0};
                    /* 发送字符串 */
                    char *msg = "Hello STM32 UART!\\r\\n";
                    HAL_UART_Transmit(&huart1,(uint8_t*)msg,strlen(msg),1000);
                    /* 接收8字节，超时500ms */
                    if (HAL_UART_Receive(&huart1, rx_buf, 8, 500) == HAL_OK) {
                        HAL_UART_Transmit(&huart1, rx_buf, 8, 1000);/* 回显 */
                    }
                    printf("Tick: %lu\\r\\n", HAL_GetTick()); /* 需MicroLIB */
                }
            """,
            exp_steps_simple=[
                step(1, "硬件连接", "USB-TTL：PA9(TX)→RX，PA10(RX)→TX，GND相连，插入电脑。", chk=True),
                step(2, "CubeMX配置USART1", "USART1→Asynchronous，115200，8N1，Generate Code。", chk=True),
                step(3, "发送测试", "USER CODE中调用Transmit发送字符串，串口助手115200验证。",
                     "HAL_UART_Transmit(&huart1,(uint8_t*)\"OK\\r\\n\",4,100);", True),
                step(4, "printf重定向", "添加fputc，勾选MicroLIB，用printf打印数据。", chk=False),
            ]
        ),
        make_simple_page(
            "p6-uart-it", "6.2 UART中断接收实验", "UART中断接收",
            key_points=[
                "中断接收HAL_UART_Receive_IT()立即返回，数据到达时触发HAL_UART_RxCpltCallback",
                "回调函数中必须重新调用HAL_UART_Receive_IT()，否则只接收一次",
                "循环队列（Ring Buffer）是处理不定长数据包的标准方案",
                "IDLE中断：接收总线空闲帧，自动识别一包数据结束",
            ],
            md_body="""\
                # 6.2 UART中断接收实验

                ## 6.2.1 为什么需要中断接收

                轮询接收（HAL_UART_Receive）的问题：
                - **阻塞CPU**：等待数据期间CPU无法做其他事
                - **超时丢包**：数据来得不规律时容易超时
                - **效率低**：大量时间浪费在等待上

                **中断接收的优势**：
                - CPU正常运行主程序
                - 数据到达时硬件自动触发中断
                - 在回调函数中处理数据，不影响主循环

                ## 6.2.2 HAL中断接收工作原理

                ```
                主程序调用 HAL_UART_Receive_IT(&huart1, buf, size)
                    ↓ 立即返回（非阻塞）
                主程序继续执行其他任务...
                    ↓
                [收到size个字节后，硬件触发USART1_IRQHandler]
                    ↓
                HAL内部处理 → 调用 HAL_UART_RxCpltCallback()
                    ↓
                用户在回调中处理数据
                    ↓ ★ 关键步骤！
                必须重新调用 HAL_UART_Receive_IT() 注册下次接收
                ```

                > ⚠️ **最常见错误**：忘记在回调中重新调用 `HAL_UART_Receive_IT()`，
                > 导致只能接收一次数据，之后再发数据没有任何响应。

                ## 6.2.3 单字节中断接收（最通用方案）

                每次只接收1个字节，在回调中拼包，适合不定长数据：

                ```c
                /* 全局变量 */
                uint8_t rx_byte;          /* 单字节接收缓冲 */
                uint8_t rx_buf[256];      /* 数据包缓冲区 */
                uint16_t rx_idx = 0;      /* 当前接收位置 */

                /* 初始化后立即注册第一次接收 */
                void uart_it_init(void) {
                    HAL_UART_Receive_IT(&huart1, &rx_byte, 1);
                }

                /* 每收到1字节触发一次 */
                void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart) {
                    if (huart->Instance == USART1) {
                        if (rx_byte == '\\n') {
                            /* 收到换行符，一包数据完整 */
                            rx_buf[rx_idx] = '\\0';
                            process_command((char*)rx_buf);  /* 处理命令 */
                            rx_idx = 0;                      /* 重置缓冲区 */
                        } else if (rx_idx < sizeof(rx_buf) - 1) {
                            rx_buf[rx_idx++] = rx_byte;
                        }
                        /* ★ 必须重新注册，否则下次不触发！*/
                        HAL_UART_Receive_IT(&huart1, &rx_byte, 1);
                    }
                }
                ```

                ## 6.2.4 环形队列（Ring Buffer）

                当主循环处理速度跟不上接收速度时，需要环形队列解耦：

                ```
                中断（生产者）→ 写入队列 → 主循环（消费者）→ 读取处理
                ```

                **环形队列实现**：
                ```c
                #define RING_BUF_SIZE 256
                typedef struct {
                    uint8_t buf[RING_BUF_SIZE];
                    uint16_t head;  /* 读指针 */
                    uint16_t tail;  /* 写指针 */
                } RingBuf;

                /* 写入（在中断中调用）*/
                void ring_push(RingBuf *rb, uint8_t data) {
                    uint16_t next = (rb->tail + 1) % RING_BUF_SIZE;
                    if (next != rb->head) {  /* 未满 */
                        rb->buf[rb->tail] = data;
                        rb->tail = next;
                    }
                    /* 满了则丢弃（可改为覆盖最旧数据）*/
                }

                /* 读取（在主循环中调用）*/
                int ring_pop(RingBuf *rb, uint8_t *data) {
                    if (rb->head == rb->tail) return 0;  /* 空 */
                    *data = rb->buf[rb->head];
                    rb->head = (rb->head + 1) % RING_BUF_SIZE;
                    return 1;
                }
                ```

                ## 6.2.5 IDLE空闲中断（进阶方案）

                IDLE中断在总线空闲时触发，可自动识别一帧数据结束，配合DMA效率最高：

                | 方案 | 优点 | 缺点 |
                |------|------|------|
                | 单字节中断 | 简单，通用 | 每字节一次中断，高波特率CPU负担重 |
                | 固定长度中断 | 效率高 | 只适合固定长度协议 |
                | IDLE+DMA | 效率最高，自动识别帧 | 配置复杂 |

                ```c
                /* IDLE+DMA方案（HAL LL层）*/
                /* 使能IDLE中断 */
                __HAL_UART_ENABLE_IT(&huart1, UART_IT_IDLE);
                /* 启动DMA接收 */
                HAL_UART_Receive_DMA(&huart1, dma_buf, DMA_BUF_SIZE);

                /* 在USART1_IRQHandler中检测IDLE */
                void USART1_IRQHandler(void) {
                    if (__HAL_UART_GET_FLAG(&huart1, UART_FLAG_IDLE)) {
                        __HAL_UART_CLEAR_IDLEFLAG(&huart1);
                        uint16_t len = DMA_BUF_SIZE
                            - __HAL_DMA_GET_COUNTER(huart1.hdmarx);
                        /* len字节的完整数据包已收到 */
                        process_packet(dma_buf, len);
                    }
                    HAL_UART_IRQHandler(&huart1);
                }
                ```
            """,
            games_data=[
                ("matching", "连线：HAL串口函数与功能", [
                    ("HAL_UART_Transmit()", "阻塞发送指定长度数据"),
                    ("HAL_UART_Receive_IT()", "非阻塞，启动中断接收"),
                    ("HAL_UART_RxCpltCallback()", "接收完成回调"),
                    ("HAL_UART_Transmit_DMA()", "DMA方式发送"),
                    ("__HAL_UART_ENABLE_IT()", "使能特定UART中断"),
                    ("HAL_UART_GetError()", "获取错误状态"),
                ]),
                ("ordering", "中断接收流程排序：", [
                    "调用HAL_UART_Receive_IT(&huart1, buf, 1)",
                    "等待数据到来（CPU可做其他事）",
                    "数据接收完成，触发HAL_UART_RxCpltCallback()",
                    "在回调中处理接收到的数据",
                    "重新调用HAL_UART_Receive_IT()准备下次接收",
                ]),
                ("flashcard", "中断接收核心知识卡", [
                    ("为什么要在回调中重新启动接收？", "HAL的中断接收是一次性的，处理完必须重新注册，否则第二包数据无法触发中断"),
                    ("如何处理不定长数据包？", "使用IDLE中断+DMA：DMA接收，IDLE触发时读取已收到的字节数，识别完整数据包"),
                    ("接收缓冲区大小如何选择？", "至少是最大数据包的2倍，推荐用循环队列处理连续数据流"),
                    ("printf线程安全吗？", "HAL_UART_Transmit在中断中调用时可能与主程序冲突，需要加互斥保护"),
                ]),
                ("classification", "分类：下列情况用哪种接收模式？",
                    {"poll": "轮询", "it": "中断", "dma": "DMA"},
                    [("r1", "调试时打印少量日志", "poll"),
                     ("r2", "实时响应命令（不定长）", "it"),
                     ("r3", "高速连续接收大量数据（如图像）", "dma"),
                     ("r4", "上位机定时发送10字节状态帧", "it"),
                     ("r5", "蓝牙模块AT命令配置", "poll"),
                     ("r6", "GPS模块NMEA数据流", "dma")]),
            ],
            quiz_ref="q-p6-uart-it",
            mm_children=[
                {"text": "中断接收", "children": [{"text": "Receive_IT()启动"}, {"text": "RxCpltCallback回调"}, {"text": "重新注册接收"}]},
                {"text": "数据处理", "children": [{"text": "循环队列"}, {"text": "包头包尾识别"}, {"text": "IDLE空闲中断"}]},
            ],
            anim_data=[
                {"icon": "📥", "t": "UART中断接收流程", "d": "HAL_UART_Receive_IT()注册接收→数据到来→硬件中断→HAL内部处理→调用RxCpltCallback→用户处理数据→重新注册"},
                {"icon": "🔄", "t": "回调中重新启动接收", "d": "这是最容易忘记的步骤！RxCpltCallback()中必须再次调用Receive_IT()，否则下次数据来了不会触发中断"},
                {"icon": "📦", "t": "环形队列处理数据流", "d": "接收到的字节入队，主循环出队处理。生产者（中断）和消费者（主循环）解耦，不会因处理慢而丢数据"},
            ],
            tags=["uart", "interrupt", "ring-buffer"],
            extra_blocks_before_exp=[
                # Phase G1.5 扩展 · UART 中断接收状态机 mermaid（state diagram 示范）
                mermaid_block(
                    bid="p6-uart-it-fsm",
                    title="UART 中断接收状态机",
                    diagram_type="state",
                    source=(
                        "stateDiagram-v2\n"
                        "  [*] --> IDLE\n"
                        "  IDLE --> ARMED: HAL_UART_Receive_IT()\n"
                        "  ARMED --> RX_BUSY: 数据到达 RX 引脚\n"
                        "  RX_BUSY --> RX_CPLT: HAL 收完 size 字节\n"
                        "  RX_CPLT --> USER_HANDLE: 进入 RxCpltCallback\n"
                        "  USER_HANDLE --> ARMED: 再次调用 Receive_IT\n"
                        "  USER_HANDLE --> DEAD_END: ★ 忘记重新注册\n"
                        "  ARMED --> ERROR: FE / PE / ORE / NE\n"
                        "  ERROR --> IDLE: HAL_UART_Abort + 清错误\n"
                        "  DEAD_END --> [*]"
                    ),
                    nodes=[
                        {"id": "IDLE", "label": "IDLE 空闲",
                         "description": "UART 外设刚初始化或 Abort 后的状态。此时 HAL 没有挂任何接收任务，数据来了也不会触发回调"},
                        {"id": "ARMED", "label": "ARMED 已布防",
                         "description": "已调用 HAL_UART_Receive_IT() 注册接收。HAL 内部记录目标缓冲区与字节数，等待硬件中断"},
                        {"id": "RX_BUSY", "label": "RX_BUSY 接收中",
                         "description": "数据已到达 RX 引脚，HAL 在中断里把字节填入用户缓冲区，未达到目标长度前一直保持此状态"},
                        {"id": "RX_CPLT", "label": "RX_CPLT 接收完成",
                         "description": "HAL 收满指定字节数，触发完成事件。状态字段 RxState 由 BUSY 变为 READY"},
                        {"id": "USER_HANDLE", "label": "USER_HANDLE 用户处理",
                         "description": "HAL 调用 HAL_UART_RxCpltCallback。这里是业务代码，必须做两件事：处理数据 + 重新调用 Receive_IT"},
                        {"id": "ERROR", "label": "ERROR 错误态",
                         "description": "出现帧错误 FE / 校验错误 PE / 溢出错误 ORE / 噪声 NE。HAL 把 ErrorCode 置位，需 Abort 后重启接收"},
                        {"id": "DEAD_END", "label": "DEAD_END 死路",
                         "description": "★ 教学红点：USER_HANDLE 里忘记再次调用 Receive_IT，下一次数据到达时 HAL 不会触发回调，串口看似坏掉"},
                    ],
                    commentary={
                        "source": "stepScripts",
                        "script": "下面这张状态机把 UART 中断接收从空闲到收完一帧再回到布防的整个生命周期都画出来，重点关注 USER_HANDLE 之后那条通向 DEAD_END 的红色支路，这就是初学者最容易踩的坑。",
                        "stepScripts": [
                            "起点是 IDLE 空闲态，UART 外设刚初始化完成，但还没挂任何接收任务。",
                            "调用 HAL_UART_Receive_IT 之后进入 ARMED 已布防态，HAL 把目标缓冲区和字节数登记好，等待硬件触发。",
                            "数据到达 RX 引脚后状态变为 RX_BUSY，HAL 在中断里逐字节往缓冲区里填，未填满前都停留在这里。",
                            "收满指定字节数后进入 RX_CPLT，HAL 内部把 RxState 由 BUSY 翻回 READY。",
                            "紧接着 HAL 调用 HAL_UART_RxCpltCallback，进入 USER_HANDLE 用户处理态，这一步是业务代码。",
                            "正确的回路是从 USER_HANDLE 重新调 Receive_IT 回到 ARMED，下一帧数据来了还能继续触发。",
                            "如果在 USER_HANDLE 里忘记重新注册，状态机就会走到 DEAD_END 死路，串口看似坏掉，其实是 HAL 已经无任务可做。",
                            "另一条分支是 ARMED 时硬件出错，比如帧错误、校验错误、溢出或噪声，状态机进入 ERROR。",
                            "ERROR 必须先 HAL_UART_Abort 清掉错误标志才能回到 IDLE，再从头开始 Receive_IT。",
                        ],
                    },
                ),
            ],
            code_lang="c", code_filename="uart_it.c", code_snippet="""\
                /* UART中断接收：1字节模式（最通用）*/
                uint8_t rx_byte;  /* 单字节接收缓冲 */
                char    rx_buf[256];
                uint16_t rx_idx = 0;

                /* 初始化后立即注册第一次接收 */
                void uart_it_start(void) {
                    HAL_UART_Receive_IT(&huart1, &rx_byte, 1);
                }

                /* 每接收1字节触发一次，处理后必须重新注册！*/
                void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart) {
                    if (huart->Instance == USART1) {
                        if (rx_byte != '\\n' && rx_idx < 255) {
                            rx_buf[rx_idx++] = rx_byte;
                        } else {
                            rx_buf[rx_idx] = '\\0';
                            /* 完整一行收到，处理命令 */
                            process_command(rx_buf);
                            rx_idx = 0;
                        }
                        /* ★ 关键：重新注册，否则下次不触发 */
                        HAL_UART_Receive_IT(&huart1, &rx_byte, 1);
                    }
                }
            """,
            exp_steps_simple=[
                step(1, "CubeMX启用USART1中断", "USART1→Asynchronous，启用NVIC全局中断，Generate Code。", chk=True),
                step(2, "注册首次接收", "HAL_UART_Init()后调用HAL_UART_Receive_IT(&huart1, &rx_byte, 1);", chk=True),
                step(3, "实现回调", "实现HAL_UART_RxCpltCallback，处理数据后重新注册Receive_IT。",
                     "HAL_UART_Receive_IT(&huart1, &rx_byte, 1);/* 必须重新注册！*/", True),
                step(4, "串口助手测试", "发送任意字符串，验证MCU能实时接收并回显，不丢字节。", chk=True),
            ]
        ),
    ]


def build_p7_pages():
    return [make_simple_page(
        "p7-adc", "7.1 ADC模数转换实验", "ADC模数转换",
        key_points=[
            "ADC将模拟电压（0~3.3V）转换为数字值（0~4095，12位分辨率）",
            "分辨率：3.3V/4096 ≈ 0.8mV/LSB（每个数字量对应0.8mV变化）",
            "HAL_ADC_Start()启动，HAL_ADC_PollForConversion()等待完成，HAL_ADC_GetValue()读取",
            "采样周期影响精度：高阻抗信号源需要更长采样周期（如239.5个ADC时钟）",
            "MQ-2烟雾传感器：加热后电阻随烟雾浓度降低，配合分压电路输出0~3.3V",
        ],
        md_body="""\
            # 7.1 ADC模数转换实验

            ## 7.1.1 ADC基本原理

            ADC（Analog-to-Digital Converter，模数转换器）将连续的模拟电压信号转换为离散的数字值。
            STM32F103内置2个12位逐次逼近型（SAR）ADC，最高采样率1MHz。

            ### 关键参数

            | 参数 | STM32F103 ADC规格 | 说明 |
            |------|------------------|------|
            | 分辨率 | 12位 | 量化级数 = 2^12 = 4096 |
            | 参考电压 | VREF+ = 3.3V | 满量程对应3.3V |
            | LSB精度 | 3.3V/4096 ≈ 0.8mV | 最小可分辨电压变化 |
            | 采样率 | 最高1MSPS | 受采样时间和转换时间限制 |
            | 输入通道 | 16个外部 + 2个内部 | 内部：温度传感器、VREFINT |
            | 输入阻抗 | 建议 < 50kΩ | 高阻抗需增加采样时间 |

            ### 电压转换公式

            ```
            电压(V) = ADC原始值 × VREF / 4096
                    = ADC原始值 × 3.3 / 4096

            示例：ADC读到2048 → 2048 × 3.3 / 4096 = 1.65V（正好是满量程的50%）
            ```

            ### 采样时间选择

            STM32 ADC的采样时间可配置为：1.5/7.5/13.5/28.5/41.5/55.5/71.5/239.5个ADC时钟周期。

            - **低阻抗信号源**（<1kΩ）：1.5~7.5周期即可
            - **中阻抗**（1k~10kΩ）：28.5~55.5周期
            - **高阻抗**（>10kΩ，如光敏电阻）：239.5周期（最安全）

            > ⚠️ 采样时间不足会导致ADC值偏低或不稳定！遇到ADC读数异常，首先增加采样时间。

            ## 7.1.2 光敏电阻与分压电路

            光敏电阻（LDR）的阻值随光照强度变化：
            - **强光**：阻值低（~1kΩ）
            - **弱光/黑暗**：阻值高（~100kΩ以上）

            ### 分压电路设计

            ```
            3.3V ──┬── [光敏电阻 R_LDR] ──┬── GND
                   │                       │
                   └── [固定电阻 10kΩ] ────┘
                                           │
                                           └── PA0 (ADC输入)
            ```

            **分压公式**：V_ADC = 3.3V × R_fixed / (R_LDR + R_fixed)

            - 强光时：R_LDR≈1kΩ → V_ADC = 3.3×10/(1+10) = **3.0V**（ADC≈3723）
            - 弱光时：R_LDR≈100kΩ → V_ADC = 3.3×10/(100+10) = **0.3V**（ADC≈372）

            ## 7.1.3 MQ-2烟雾传感器

            | 参数 | MQ-2规格 |
            |------|---------|
            | 检测气体 | LPG、丙烷、氢气、甲烷、烟雾 |
            | 检测浓度 | 300~10000 ppm |
            | 工作电压 | 5V（加热电阻需要5V供电） |
            | 输出 | AO（模拟0~5V）/ DO（数字阈值） |
            | 预热时间 | 首次>24小时，日常>5分钟 |

            > ⚠️ MQ-2的AO输出最高5V，STM32是3.3V系统！必须用分压电路（2kΩ+3kΩ）降到3.3V以内。

            ## 7.1.4 室内亮度自动感应系统

            系统逻辑：
            1. ADC定时采样光敏电阻电压
            2. 电压 < 阈值（如1.0V）→ 环境暗 → 开灯（PWM 100%）
            3. 电压 > 阈值 → 环境亮 → 关灯或降低亮度
            4. 可用滑动平均滤波消除瞬时干扰

            ```c
            /* 滑动平均滤波（N=8） */
            uint32_t adc_filter(uint32_t new_val) {
                static uint32_t buf[8] = {0};
                static uint8_t idx = 0;
                buf[idx++ % 8] = new_val;
                uint32_t sum = 0;
                for (int i = 0; i < 8; i++) sum += buf[i];
                return sum / 8;
            }
            ```
        """,
        games_data=[
            ("fill", "填写ADC电压转换计算：",
                ["12位ADC满量程0~3.3V，读取到的ADC值为2048时，对应电压为：",
                 "\n电压 = ADC值 × (", {"blank": True, "answer": "3.3", "hint": "参考电压（V）"}, " / ",
                 {"blank": True, "answer": "4096", "hint": "最大ADC值（12位）"}, ")",
                 " = 2048 × 3.3/4096 ≈ ", {"blank": True, "answer": "1.65", "hint": "计算结果（V）"}, " V"]),
            ("matching", "连线：ADC相关概念", [
                ("12位分辨率", "4096个量化级别"),
                ("参考电压VREF", "决定ADC满量程范围"),
                ("采样时间", "信号进入ADC保持的时间"),
                ("转换时间", "采样+量化的总耗时"),
                ("HAL_ADC_GetValue()", "读取转换结果寄存器"),
                ("DMA扫描模式", "多通道自动轮询转换"),
            ]),
            ("classification", "分类：ADC应用场景",
                {"analog": "需要ADC（模拟信号）", "digital": "不需要ADC（数字信号）"},
                [("a1", "NTC热敏电阻测温度", "analog"),
                 ("a2", "DS18B20数字温度传感器", "digital"),
                 ("a3", "光敏电阻测光强", "analog"),
                 ("a4", "按键开关检测（高低电平）", "digital"),
                 ("a5", "电池电压监测", "analog"),
                 ("a6", "超声波测距（回波时间）", "digital")]),
            ("flashcard", "📚 ADC核心知识卡", [
                ("12位ADC的分辨率是多少mV？", "3.3V / 4096 ≈ 0.8mV，即每变化0.8mV，ADC值变化1"),
                ("ADC扫描模式有什么用？", "自动轮询多个通道，配合DMA可以无CPU参与地连续采集多路模拟信号"),
                ("MQ-2传感器的工作原理？", "SnO2半导体材料，遇到可燃气体电阻降低，通过分压电路将电阻变化转为电压变化"),
                ("ADC采样率越高越好吗？", "需要与信号频率匹配。奈奎斯特定理：采样率≥2倍信号频率，否则发生混叠失真"),
            ]),
            ("ordering", "ADC单次转换流程：", [
                "初始化ADC（MX_ADC1_Init()）",
                "调用HAL_ADCEx_Calibration_Start()校准",
                "HAL_ADC_Start(&hadc1)启动转换",
                "HAL_ADC_PollForConversion(&hadc1, HAL_MAX_DELAY)等待",
                "HAL_ADC_GetValue(&hadc1)读取结果",
                "计算: voltage = adc_val * 3.3f / 4096",
            ]),
        ],
        quiz_ref="q-p7-adc",
        mm_children=[
            {"text": "ADC原理", "children": [{"text": "12位精度"}, {"text": "0-3.3V范围"}, {"text": "4096量化级"}]},
            {"text": "HAL操作", "children": [{"text": "Calibration校准"}, {"text": "Start启动"}, {"text": "PollForConversion等待"}, {"text": "GetValue读取"}]},
            {"text": "应用", "children": [{"text": "MQ-2烟雾"}, {"text": "NTC测温"}, {"text": "电位器"}, {"text": "光敏"}]},
        ],
        anim_data=[
            {"icon": "📈", "t": "ADC工作原理", "d": "模拟电压→采样保持电路→逐次逼近比较器→12位数字输出。3.3V满量程，4096级分辨率，精度约0.8mV"},
            {"icon": "🔢", "t": "ADC值到电压转换", "d": "voltage = ADC_value × VREF / 4096 = ADC_value × 3.3 / 4096。读到4096时对应3.3V，读到2048对应1.65V"},
            {"icon": "🔬", "t": "MQ-2烟雾传感器原理", "d": "加热后SnO2半导体接触可燃气体时电阻降低（从10kΩ→100Ω），配合10kΩ分压电阻，输出电压随烟雾浓度增加而升高"},
            {"icon": "🔄", "t": "ADC多通道DMA扫描", "d": "开启Scan Mode+DMA，ADC自动依次采样CH0→CH1→...→CHn，结果存入DMA目标数组，CPU全程不参与，效率最高"},
        ],
        tags=["adc", "analog", "sensor"],
        code_lang="c", code_filename="adc_read.c", code_snippet="""\
            /* ADC单次转换读取电压示例 */
            #include "main.h"

            float adc_read_voltage(void) {
                HAL_ADC_Start(&hadc1);
                HAL_ADC_PollForConversion(&hadc1, HAL_MAX_DELAY);
                uint32_t raw = HAL_ADC_GetValue(&hadc1);
                HAL_ADC_Stop(&hadc1);
                /* 转换为实际电压（mV） */
                return raw * 3300.0f / 4096.0f;  /* 单位 mV */
            }

            /* 烟雾浓度判断 */
            void mq2_monitor(void) {
                float voltage_mv = adc_read_voltage();
                uint32_t ppm = (uint32_t)(voltage_mv * 1000 / 3300);
                if (ppm > 300) {
                    /* 烟雾报警：点亮LED或蜂鸣器 */
                    HAL_GPIO_WritePin(GPIOC, GPIO_PIN_13, GPIO_PIN_SET);
                }
                printf("MQ2 Voltage: %.0f mV, ppm: %lu\\r\\n", voltage_mv, ppm);
            }
        """,
        exp_steps_simple=[
            step(1, "CubeMX配置ADC1", "ADC1→IN0，分辨率12位，连续转换关闭，采样239.5周期，不使能DMA。", chk=True),
            step(2, "PA0接电位器", "电位器：左脚接3.3V，右脚接GND，中间抽头接PA0（ADC1_IN0）。", chk=True),
            step(3, "读取并转换", "循环调用adc_read_voltage()，通过串口打印，旋转电位器观察电压变化。",
                 "float v = adc_read_voltage();\nprintf(\"%.0f mV\\r\\n\", v);", True),
            step(4, "接MQ-2烟雾传感器", "MQ-2的AO脚接PA0，预热5分钟，打火机靠近观察电压升高。", chk=True),
        ]
    )]


