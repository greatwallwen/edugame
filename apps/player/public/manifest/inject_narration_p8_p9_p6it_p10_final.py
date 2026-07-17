# -*- coding: utf-8 -*-
"""
inject_narration_p8_p9_p6it_p10_final.py

p10 / p6-uart-it / p8 / p9 四页用 exp stepScripts 补到 ≥3000，越线 PASS。
"""
from __future__ import annotations
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from inject_narration_factory import run as run_narration  # type: ignore


P10_EXP_SS = [
    """实验目标我们分四步搭出无人停车场闸口。第一步硬件接线。STM32F103C8T6 主控；HC-SR04 超声波模块的 Trig 接 PB12（GPIO 输出）、Echo 接 PB13（输入捕获用，配 TIM4_CH1）、VCC 接 5V、GND 接地（注意超声 Echo 输出是 5V，STM32 的 PB13 5V 容忍 IO 直接接没事，但非 5V 容忍的 IO 必须加分压电阻）。SG90 舵机控制端接 PA8（PWM）、电源接 5V 外接电池（不能从 USB 拉，舵机瞬间电流 300mA 拉崩 USB）。OLED 通过 I2C 共线接 PB6 / PB7。""",
    """第二步实现超声测距。CubeMX 启用 TIM4 输入捕获模式 IC1，Polarity Selection 改成 Both Edge（同时捕获上升和下降沿），Prescaler=71 让计数 1MHz（计数 1us 一格）。Generate 后写代码：先 Trig 拉高 10us 再拉低发出 40kHz 脉冲；启动 HAL_TIM_IC_Start_IT(&htim4, TIM_CHANNEL_1)。HAL_TIM_IC_CaptureCallback 回调里两次捕获分别记录 t1（上升）、t2（下降），距离 = (t2 - t1) × 0.0343 / 2 cm。手挡在传感器前 30cm 应该精确读到 30cm ± 1。""",
    """第三步实现舵机软启停开闸。PWM 配 TIM1_CH1 50Hz 频率，CCR 范围 1000~2000 对应 0~180 度。开闸函数 servo_open() 用 for 循环 ccr 从 1000 渐变到 2000 用 500ms 完成，每 5ms 改一次 CCR。关闸 servo_close() 反向。这种渐变控制比直接写 SetCompare(2000) 稳重得多——直接写舵机会用最大转速猛地撞到位置极限，机械冲击大、噪声大、寿命短。软启停代码就 10 行，但产品级和 demo 级又一处分水岭。""",
    """第四步整合状态机和显示。状态机用 enum {IDLE, DETECT, OPEN, WAIT_PASS, CLOSE} 加 switch case 写在 main 主循环。TIM2 中断每 100ms 跑一次状态判定。OLED 上每秒刷新一次显示当前状态和距离值。烧录后用一只手当成车辆模拟从远到近又从近到远走过传感器，应该看到状态依次从 IDLE → DETECT → OPEN → WAIT_PASS → CLOSE → IDLE，闸门相应开关。这就是一台能用的无人停车场闸口原型，下一步加上计费、车牌识别、扫码支付就能上现场了。""",
]

P6IT_EXP_SS = [
    """实验目标分四步把 UART 中断接收练熟。第一步从 polling 模式切到中断模式。原阻塞代码 HAL_UART_Receive 全删掉，main 函数最后加 HAL_UART_Receive_IT(&huart1, &g_rxByte, 1) 启动一次接收。这一行的意思是接下来 huart1 收到 1 字节会触发中断、读到 g_rxByte 变量、调 RxCpltCallback。""",
    """第二步写 RxCpltCallback。CubeMX 生成的 stm32f1xx_it.c 已经把中断转发到这个回调，你只在 main.c 里 USER CODE BEGIN 4 区写函数体即可。函数体三行：把 g_rxByte 入环形缓冲、置位 g_rxFlag = 1（告诉主循环有新字节）、再调 HAL_UART_Receive_IT(&huart1, &g_rxByte, 1) 重新装填——必须重启接收，否则只收 1 字节就哑火。这一步是 90% 新手踩坑的地方。""",
    """第三步实现环形缓冲。结构体 typedef struct { uint8_t buf[256]; uint16_t head, tail; } RingBuf_t; 加两个函数 ringbuf_put 和 ringbuf_get。put: buf[head] = byte; head = (head + 1) & 0xFF（256 长度时 & 0xFF 等价于绕回）；get: byte = buf[tail]; tail = (tail + 1) & 0xFF。head==tail 表示空，(head+1)&0xFF==tail 表示满。这是嵌入式最经济的数据结构，背下来。""",
    """第四步实战 LED 命令解析。在主循环里 if (g_rxFlag) 拿出 ringbuf 内容，遇换行符就把这一帧拷到 cmd 数组、用 strncmp 匹配 LED ON 或 LED OFF 控制 GPIO。注意：strncmp 不能在 ISR 里调——它执行时间不确定，违反 ISR 铁律。整个流程：ISR 只入队、清标志，主循环慢慢解析——这就是嵌入式硬实时系统设计的精髓所在。这一步代码写完调通，你已经写出一个迷你串口协议栈，离工业级还差 CRC、超时重试这些工程细节。""",
]

P8_EXP_SS_EXTRA = [
    """[Iter29-补充] 第五步实现可调正弦波函数发生器。用 1024 项正弦 LUT 配 TIM6 + DMA + DAC 三件套；UART 接收设定值 freq 字符串如 setfreq 1000 表示设 1kHz；解析后改 TIM6 ARR = 72000000 / (1024 × freq) - 1 实时改触发周期。LUT 表用 Python 算好填进 const 数组：sin_lut[i] = (uint16_t)(2047 + 2047 × sin(2π × i / 1024))。烧录后用万用表交流档测应该是 freq Hz 正弦波，示波器测应该是漂亮的对称正弦——有阶梯感说明 LUT 项数不够。这就是把 STM32 内置 DAC 跑成函数发生器的工业级实现。"""
]

P9_EXP_SS_EXTRA = [
    """[Iter29-补充] 第五步加报警阈值和趋势分析。在主循环里检查 t > 50 或 t < -10 触发声光报警（蜂鸣器拉响、红色 LED 亮）；维护一个 10 分钟滑动窗口里的温度数组，差分 < -3 触发降温预警（可能着火被扑灭）、差分 > +3 触发升温预警（可能起火）。这就是消防、冷链、温室大棚监测系统的最简核心——把硬件读数加阈值加趋势就成了一个能保护人和财产的智能预警系统。这一段代码 50 行，但决定了你的环境监测系统能不能上现场用——demo 不带阈值是练习题，加了阈值才是产品。"""
]


NARRATIONS = {
    'p10-parking': {
        'p10-parking-exp':  {'kind': 'experiment', 'commentary': {'stepScripts': P10_EXP_SS}},
    },
    'p6-uart-it': {
        'p6-uart-it-exp':  {'kind': 'experiment', 'commentary': {'stepScripts': P6IT_EXP_SS}},
    },
}


def append_exp_extra():
    """p8 / p9 的 exp 已有 stepScripts，用 marker 追加一段。"""
    import json, re
    ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
    M = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')
    MARKER = '[Iter29-补充]'
    extras = {
        ('p8-dac', 'p8-dac-exp'): P8_EXP_SS_EXTRA[0],
        ('p9-env', 'p9-env-exp'): P9_EXP_SS_EXTRA[0],
    }
    CN = re.compile(r"[\u4e00-\u9fa5]")
    with open(M, encoding='utf-8') as f:
        m = json.load(f)
    for ch in m.get('chapters', []):
        for s in ch.get('sections', []):
            for p in s.get('pages', []):
                pid = p.get('id', '')
                for b in p.get('blocks', []):
                    bid = b.get('id', '')
                    extra = extras.get((pid, bid))
                    if not extra: continue
                    cmt = b.setdefault('commentary', {})
                    ss = list(cmt.get('stepScripts') or [])
                    while ss and ss[-1].lstrip().startswith(MARKER):
                        ss.pop()
                    ss.append(extra)
                    cmt['stepScripts'] = ss
                    print(f'[OK]   exp+ {pid}/{bid} → {sum(len(CN.findall(x)) for x in ss)} 字（{len(ss)} 段）')
    with open(M, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f'[DONE] exp extra 注入完成')


if __name__ == '__main__':
    run_narration(NARRATIONS, expected_pages=2)
    append_exp_extra()
