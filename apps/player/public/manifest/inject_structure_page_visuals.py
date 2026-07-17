#!/usr/bin/env python3
"""
inject_structure_page_visuals.py — 为 intro/ext/goals 等结构页补充 Mermaid 流程图

解决23个无动画页面的覆盖问题。幂等：按 block id 去重。
"""
import json, sys, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'apps', 'player', 'public'))
MF = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')

from manifest.blocks import mermaid_block

VISUALS = {
    "p1-goals": mermaid_block("p1-goals-roadmap", title="学习路线图", diagram_type="flowchart",
        source="flowchart LR\n    A[认识单片机] --> B[开发环境] --> C[GPIO] --> D[定时器] --> E[PWM]\n    E --> F[串口] --> G[ADC/DAC] --> H[传感器] --> I[综合项目]"),
    "p1-arch": mermaid_block("p1-arch-layers", title="单片机内部架构", diagram_type="flowchart",
        source="flowchart TD\n    A[CPU 内核 Cortex-M3] --> B[总线矩阵]\n    B --> C[Flash 程序存储]\n    B --> D[SRAM 数据存储]\n    B --> E[APB1/APB2 外设总线]\n    E --> F[GPIO/TIM/UART/ADC/DAC/I2C/SPI]"),
    "p1-devflow": mermaid_block("p1-devflow-steps", title="嵌入式开发流程", diagram_type="flowchart",
        source="flowchart TD\n    A[需求分析] --> B[硬件选型]\n    B --> C[CubeMX 配置]\n    C --> D[编写应用代码]\n    D --> E[编译链接]\n    E --> F[烧录下载]\n    F --> G[调试验证]\n    G -->|发现Bug| D"),
    "ch3-intro": mermaid_block("ch3-intro-overview", title="GPIO应用全景", diagram_type="flowchart",
        source="flowchart LR\n    A[GPIO 输出] --> B[LED 控制]\n    A --> C[蜂鸣器]\n    D[GPIO 输入] --> E[按键扫描]\n    D --> F[外部中断 EXTI]\n    F --> G[中断回调]"),
    "p3-exti-code": mermaid_block("p3-exti-code-flow", title="EXTI 代码执行流程", diagram_type="flowchart",
        source="flowchart TD\n    A[HAL_GPIO_EXTI_IRQHandler] --> B{读取中断标志}\n    B -->|匹配| C[清除挂起位]\n    C --> D[HAL_GPIO_EXTI_Callback]\n    D --> E[用户处理逻辑]\n    B -->|不匹配| F[返回]"),
    "ch3-ext": mermaid_block("ch3-ext-mistakes", title="GPIO 常见问题排查", diagram_type="flowchart",
        source="flowchart TD\n    A[LED 不亮?] --> B{时钟使能?}\n    B -->|否| C[__HAL_RCC_GPIOx_CLK_ENABLE]\n    B -->|是| D{模式正确?}\n    D -->|否| E[改为 GPIO_MODE_OUTPUT_PP]\n    D -->|是| F{引脚号对?}\n    F -->|否| G[检查原理图]\n    F -->|是| H[检查硬件连接]"),
    "ch4-intro": mermaid_block("ch4-intro-overview", title="定时器应用全景", diagram_type="flowchart",
        source="flowchart LR\n    A[基本定时] --> B[精确延时]\n    A --> C[周期中断]\n    D[输出比较] --> E[PWM 波形]\n    F[输入捕获] --> G[测频率]\n    F --> H[测脉宽]"),
    "ch4-ext": mermaid_block("ch4-ext-calc", title="定时器参数计算流程", diagram_type="flowchart",
        source="flowchart TD\n    A[确定目标周期 T] --> B[选择时钟源 72MHz]\n    B --> C[计算 PSC 分频]\n    C --> D[计算 ARR 重装值]\n    D --> E{ARR ≤ 65535?}\n    E -->|是| F[配置完成]\n    E -->|否| G[增大 PSC 重新计算]"),
    "ch5-intro": mermaid_block("ch5-intro-overview", title="PWM 输出应用场景", diagram_type="flowchart",
        source="flowchart LR\n    A[PWM] --> B[LED 调光]\n    A --> C[电机调速]\n    A --> D[舵机控制]\n    A --> E[蜂鸣器音调]"),
    "ch5-ext": mermaid_block("ch5-ext-debug", title="PWM 不输出排查", diagram_type="flowchart",
        source="flowchart TD\n    A[PWM 无输出?] --> B{通道使能?}\n    B -->|否| C[HAL_TIM_PWM_Start]\n    B -->|是| D{GPIO 复用?}\n    D -->|否| E[配置 AF 模式]\n    D -->|是| F{CCR 值?}\n    F -->|=0| G[设置非零 CCR]\n    F -->|正常| H[检查示波器/引脚]"),
    "ch6-ext": mermaid_block("ch6-ext-uart-debug", title="串口调试流程", diagram_type="flowchart",
        source="flowchart TD\n    A[收不到数据?] --> B{波特率匹配?}\n    B -->|否| C[统一 115200]\n    B -->|是| D{TX/RX 交叉?}\n    D -->|否| E[TX接RX RX接TX]\n    D -->|是| F{中断使能?}\n    F -->|否| G[HAL_UART_Receive_IT]\n    F -->|是| H[检查回调函数]"),
    "ch7-intro": mermaid_block("ch7-intro-adc", title="ADC 采样流程", diagram_type="flowchart",
        source="flowchart LR\n    A[模拟信号] --> B[采样保持]\n    B --> C[量化编码]\n    C --> D[12位数字值]\n    D --> E[电压换算]"),
    "ch7-ext": mermaid_block("ch7-ext-formula", title="ADC 电压换算", diagram_type="flowchart",
        source="flowchart TD\n    A[读取 ADC 值] --> B[voltage = adc_val * 3.3 / 4095]\n    B --> C{传感器类型}\n    C -->|分压| D[Vout = Vin * R2 / R1+R2]\n    C -->|线性| E[物理量 = k * voltage + b]"),
    "ch8-intro": mermaid_block("ch8-intro-dac", title="DAC 工作原理", diagram_type="flowchart",
        source="flowchart LR\n    A[12位数字值] --> B[DAC 转换器]\n    B --> C[模拟电压]\n    C --> D[输出引脚 PA4/PA5]"),
    "ch8-ext": mermaid_block("ch8-ext-wave", title="DAC 波形生成方法", diagram_type="flowchart",
        source="flowchart TD\n    A[波形生成] --> B[查表法]\n    A --> C[DMA 自动输出]\n    B --> D[正弦波表 256 点]\n    C --> E[定时器触发 DMA]\n    D --> F[HAL_DAC_SetValue]\n    E --> F"),
    "ch9-intro": mermaid_block("ch9-intro-env", title="环境监测系统架构", diagram_type="flowchart",
        source="flowchart TD\n    A[BH1750 光照] -->|I2C| D[STM32]\n    B[HDC1080 温湿度] -->|I2C| D\n    C[MQ-2 烟雾] -->|ADC| D\n    D --> E[LCD 显示]\n    D --> F[串口上报]\n    D --> G[阈值报警]"),
    "ch9-ext": mermaid_block("ch9-ext-i2c-debug", title="I2C 通信排查", diagram_type="flowchart",
        source="flowchart TD\n    A[I2C 无应答?] --> B{地址正确?}\n    B -->|否| C[查数据手册确认7位地址]\n    B -->|是| D{上拉电阻?}\n    D -->|否| E[加 4.7K 上拉到 VCC]\n    D -->|是| F{SCL/SDA 引脚?}\n    F -->|错| G[检查 CubeMX AF 配置]\n    F -->|对| H[用逻辑分析仪抓波形]"),
    "ch10-intro": mermaid_block("ch10-intro-parking", title="无人停车场系统架构", diagram_type="flowchart",
        source="flowchart TD\n    A[超声波 HC-SR04] -->|距离| D[STM32]\n    B[NFC MFRC522] -->|SPI| D\n    C[红外对射] --> D\n    D --> E[舵机道闸]\n    D --> F[数码管车位数]\n    D --> G[蜂鸣器报警]"),
    "ch10-ext": mermaid_block("ch10-ext-state", title="停车场状态机", diagram_type="state",
        source="stateDiagram-v2\n    [*] --> 空闲\n    空闲 --> 刷卡进场: NFC 感应\n    刷卡进场 --> 道闸开: 验证通过\n    道闸开 --> 计时中: 车辆驶入\n    计时中 --> 刷卡出场: NFC 感应\n    刷卡出场 --> 计费: 计算费用\n    计费 --> 空闲: 道闸放行"),
    "ch11-intro": mermaid_block("ch11-intro-band", title="运动手环系统架构", diagram_type="flowchart",
        source="flowchart TD\n    A[LSM6DS3 加速度计] -->|I2C| D[STM32]\n    B[PPG 心率传感器] -->|ADC| D\n    D --> E[计步算法]\n    D --> F[心率计算]\n    E --> G[OLED 显示]\n    F --> G"),
    "ch11-ext": mermaid_block("ch11-ext-lowpower", title="低功耗设计要点", diagram_type="flowchart",
        source="flowchart TD\n    A[低功耗策略] --> B[Sleep 模式]\n    A --> C[Stop 模式]\n    A --> D[降低采样率]\n    B --> E[WFI 指令休眠]\n    C --> F[RTC 定时唤醒]\n    D --> G[心率 1Hz 计步 10Hz]"),
    "ch12-intro": mermaid_block("ch12-intro-suntrack", title="追光系统工作原理", diagram_type="flowchart",
        source="flowchart TD\n    A[4路光敏电阻] -->|ADC| B[STM32]\n    B --> C[计算光照差值]\n    C --> D[PID 控制器]\n    D --> E[舵机水平轴]\n    D --> F[舵机垂直轴]\n    E --> G[面板对准光源]\n    F --> G"),
    "ch12-ext": mermaid_block("ch12-ext-pid-tune", title="PID 参数调节流程", diagram_type="flowchart",
        source="flowchart TD\n    A[先调 Kp] --> B{振荡?}\n    B -->|是| C[减小 Kp]\n    B -->|否| D[加入 Ki]\n    D --> E{稳态误差?}\n    E -->|有| F[增大 Ki]\n    E -->|无| G[加入 Kd]\n    G --> H{超调大?}\n    H -->|是| I[增大 Kd]\n    H -->|否| J[调节完成]"),
}


def main():
    with open(MF, 'r', encoding='utf-8') as f:
        m = json.load(f)

    added = 0
    for ch in m['chapters']:
        for sec in ch['sections']:
            for p in sec['pages']:
                pid = p['id']
                if pid not in VISUALS:
                    continue
                block_data = VISUALS[pid]
                bid = block_data['id']
                if any(b.get('id') == bid for b in p['blocks']):
                    continue
                # 在第一个 text block 后插入
                insert_pos = 1
                for i, b in enumerate(p['blocks']):
                    if b['kind'] == 'text':
                        insert_pos = i + 1
                        break
                p['blocks'].insert(insert_pos, block_data)
                added += 1

    with open(MF, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f"[structure-visuals] 注入 {added} 个 Mermaid 流程图", file=sys.stderr)


if __name__ == '__main__':
    main()
