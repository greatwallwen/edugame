"""
gallery_demo_specs.py · 画廊用 13 种新题型示例 spec

当教材页面尚未使用某新题型时，build_gallery 用这里的 demo 实例展示，
保证 ?page=gallery 能呈现全部 ≥20 种题型各一个实例（平台能力目录）。
内容为通用嵌入式样例，仅作组件演示。
"""

DEMO_SPECS = {
    'single-choice': {
        'kind': 'single-choice',
        'prompt': 'STM32 的 GPIO 推挽输出模式，引脚可以输出哪两种电平？',
        'options': [
            {'id': 'a', 'text': '只有高电平'},
            {'id': 'b', 'text': '高电平和低电平'},
            {'id': 'c', 'text': '只有低电平'},
            {'id': 'd', 'text': '高阻态'},
        ],
        'answer': 'b',
        'explanation': '推挽输出由上下两个 MOS 管驱动，可主动输出高/低电平。',
    },
    'multiple-choice': {
        'kind': 'multiple-choice',
        'prompt': '下列哪些属于 STM32 的片上外设？（多选）',
        'options': [
            {'id': 'a', 'text': 'GPIO'},
            {'id': 'b', 'text': 'USART'},
            {'id': 'c', 'text': '显示器'},
            {'id': 'd', 'text': 'ADC'},
            {'id': 'e', 'text': '键盘'},
        ],
        'answers': ['a', 'b', 'd'],
        'explanation': 'GPIO/USART/ADC 是片上外设；显示器、键盘是外接设备。',
    },
    'true-false': {
        'kind': 'true-false',
        'prompt': '判断下列说法是否正确',
        'statements': [
            {'id': 's1', 'text': '使用 GPIO 前必须先使能其时钟。', 'correct': True},
            {'id': 's2', 'text': 'LED 串联限流电阻是为了让它更亮。', 'correct': False},
            {'id': 's3', 'text': '定时器溢出可触发更新中断。', 'correct': True},
        ],
    },
    'timed-quiz': {
        'kind': 'timed-quiz',
        'prompt': '限时快答：又快又准！',
        'seconds': 30,
        'questions': [
            {'id': 'q1', 'stem': '1 字节有几位？', 'options': ['4', '8', '16'], 'answer': 1},
            {'id': 'q2', 'stem': 'ADC 把什么转成数字？', 'options': ['电流', '模拟电压', '频率'], 'answer': 1},
            {'id': 'q3', 'stem': 'PWM 调节亮度靠改变？', 'options': ['占空比', '电阻', '电容'], 'answer': 0},
        ],
    },
    'slider-estimate': {
        'kind': 'slider-estimate',
        'prompt': '把 PWM 占空比拖到 75%',
        'min': 0, 'max': 100, 'step': 1, 'target': 75, 'tolerance': 3, 'unit': '%',
        'explanation': '占空比 = 高电平时间 / 周期，75% 表示四分之三时间为高电平。',
    },
    'sequence-builder': {
        'kind': 'sequence-builder',
        'prompt': '按正确顺序拼装点亮 LED 的代码流程',
        'steps': [
            {'id': 'clk', 'text': '使能 GPIO 时钟'},
            {'id': 'cfg', 'text': '配置引脚为推挽输出'},
            {'id': 'set', 'text': '写引脚输出高电平'},
            {'id': 'noise', 'text': '配置串口波特率'},
        ],
        'correctSequence': ['clk', 'cfg', 'set'],
        'explanation': '先开时钟，再配引脚，最后写电平；串口配置与点灯无关。',
    },
    'truth-table': {
        'kind': 'truth-table',
        'prompt': '填写逻辑与（Y = A AND B）的真值表输出列',
        'inputs': ['A', 'B'], 'outputs': ['Y'],
        'rows': [
            {'in': [0, 0], 'out': [0]},
            {'in': [0, 1], 'out': [0]},
            {'in': [1, 0], 'out': [0]},
            {'in': [1, 1], 'out': [1]},
        ],
        'explanation': '与运算仅当 A、B 同时为 1 时输出 1。',
    },
    'base-converter': {
        'kind': 'base-converter',
        'prompt': '完成下列进制转换',
        'tasks': [
            {'id': 't1', 'value': '0x20', 'fromBase': 16, 'toBase': 10, 'answer': '32'},
            {'id': 't2', 'value': '13', 'fromBase': 10, 'toBase': 2, 'answer': '1101'},
        ],
    },
    'register-config': {
        'kind': 'register-config',
        'prompt': '配置 GPIOA 使 PA5 为推挽输出',
        'registerName': 'GPIOA->CRL',
        'fields': [
            {'id': 'mode', 'label': 'MODE（输出速度）', 'options': ['输入', '输出 2MHz', '输出 50MHz'], 'answer': '输出 50MHz', 'hint': '需要较快翻转选高速'},
            {'id': 'cnf', 'label': 'CNF（输出类型）', 'options': ['推挽输出', '开漏输出', '复用推挽'], 'answer': '推挽输出'},
        ],
        'explanation': '推挽输出 + 50MHz 适合驱动 LED 这类负载。',
    },
    'waveform-tuner': {
        'kind': 'waveform-tuner',
        'prompt': '调节 PWM 频率与占空比，匹配目标方波',
        'waveform': 'square',
        'params': [
            {'id': 'freq', 'label': '频率', 'min': 1, 'max': 20, 'step': 1, 'target': 10, 'tolerance': 1, 'unit': 'kHz'},
            {'id': 'duty', 'label': '占空比', 'min': 0, 'max': 100, 'step': 5, 'target': 50, 'tolerance': 5, 'unit': '%'},
        ],
        'explanation': '频率决定周期，占空比决定高低电平比例。',
    },
    'parameter-match': {
        'kind': 'parameter-match',
        'prompt': '同时把三个采样参数调到目标值',
        'params': [
            {'id': 'res', 'label': 'ADC 分辨率', 'min': 8, 'max': 12, 'step': 1, 'target': 12, 'tolerance': 0, 'unit': 'bit'},
            {'id': 'vref', 'label': '参考电压', 'min': 1, 'max': 5, 'step': 0.1, 'target': 3.3, 'tolerance': 0.1, 'unit': 'V'},
            {'id': 'rate', 'label': '采样率', 'min': 1, 'max': 10, 'step': 1, 'target': 5, 'tolerance': 1, 'unit': 'kHz'},
        ],
    },
    'hotspot-sequence': {
        'kind': 'hotspot-sequence',
        'prompt': '按"采集→转换→读取→换算"顺序点击 ADC 流程节点',
        'hotspots': [
            {'id': 'acq', 'label': '采集', 'x': 15, 'y': 50, 'radius': 28},
            {'id': 'conv', 'label': '转换', 'x': 38, 'y': 50, 'radius': 28},
            {'id': 'read', 'label': '读取', 'x': 62, 'y': 50, 'radius': 28},
            {'id': 'calc', 'label': '换算', 'x': 85, 'y': 50, 'radius': 28},
        ],
        'correctOrder': ['acq', 'conv', 'read', 'calc'],
        'explanation': 'ADC 工作链：采集模拟量 → 量化转换 → 读寄存器 → 换算物理量。',
    },
    'drag-label': {
        'kind': 'drag-label',
        'prompt': '把引脚名拖到电路对应位置',
        'targets': [
            {'id': 'pin5', 'x': 25, 'y': 35, 'answer': 'pa5'},
            {'id': 'gnd', 'x': 70, 'y': 65, 'answer': 'gnd'},
            {'id': 'res', 'x': 50, 'y': 35, 'answer': 'r220'},
        ],
        'labels': [
            {'id': 'pa5', 'text': 'PA5'},
            {'id': 'r220', 'text': '220Ω'},
            {'id': 'gnd', 'text': 'GND'},
        ],
        'explanation': 'PA5 经 220Ω 限流后接 LED，最终回到 GND 闭合回路。',
    },
    # 3 个旧题型补 demo（教材正文未直接使用，保证画廊全展示）
    'spot-difference': {
        'kind': 'spot-difference',
        'prompt': '找出两段配置代码的关键差异',
        'left': {'type': 'text', 'content': 'GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;'},
        'right': {'type': 'text', 'content': 'GPIO_InitStruct.Mode = GPIO_MODE_INPUT;'},
        'differences': [{'description': '一个是推挽输出，一个是输入模式'}],
    },
    'hotspot': {
        'kind': 'hotspot',
        'prompt': '点击下图中代表"限流电阻"的位置',
        'image': 'PA5 ──[ 220Ω ]── LED ── GND',
        'hotspots': [
            {'id': 'res', 'description': '限流电阻 220Ω', 'x': 40, 'y': 50, 'radius': 14},
        ],
    },
    'code-cloze': {
        'kind': 'code-cloze',
        'prompt': '补全点亮 PA5 的代码',
        'language': 'c',
        'template': 'HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, {{v}});',
        'blanks': [{'id': 'v', 'accepted': ['GPIO_PIN_SET'], 'rationale': '置高电平点亮 LED'}],
        'validate': 'normalized',
    },
}
