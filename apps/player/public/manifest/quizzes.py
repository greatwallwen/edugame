# -*- coding: utf-8 -*-
"""
quizzes.py — STM32 课程题库

包含所有选择题定义，由 manifest_builder.py 中的 main() 调用。
"""
import sys, os

# 确保可以导入 gen_manifest.py 中的 quiz() 函数
_PUBLIC_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _PUBLIC_DIR not in sys.path:
    sys.path.insert(0, _PUBLIC_DIR)

# 消除 exec 反模式（exec 命名空间无 __file__ 会报错）。
def _get_quiz():
    from gen_manifest import quiz
    return quiz


def build_quizzes():
    q = _get_quiz()
    return {
        "q-p1c": q("q-p1c", "关于STM32F103C8T6，以下哪项描述正确？",
            {"A": "基于ARM Cortex-M4内核，最高主频168MHz",
             "B": "基于ARM Cortex-M3，最高主频72MHz，64KB Flash，20KB SRAM",
             "C": "内置128KB SRAM，外置Flash",
             "D": "属于SoC范畴，可运行Linux"}, "B",
            "STM32F103C8T6基于ARM Cortex-M3内核，最高72MHz，片内64KB Flash+20KB SRAM，属于MCU不是SoC"),
        "q-p2-ide": q("q-p2-ide", "以下关于STM32CubeMX的说法，错误的是？",
            {"A": "可图形化配置GPIO引脚功能和模式",
             "B": "自动生成HAL库初始化代码框架",
             "C": "用户代码必须写在USER CODE区域，否则重新生成会被覆盖",
             "D": "只能使用官方ST-Link下载器，不支持J-Link"}, "D",
            "CubeMX生成工程后可用任何兼容SWD/JTAG的调试器（J-Link/DAPLink等），不限于ST-Link"),
        "q-p3-led": q("q-p3-led", "驱动LED时，以下哪种连接方式正确？",
            {"A": "LED直接接GPIO引脚与GND，不需要限流电阻",
             "B": "GPIO→限流电阻（220Ω）→LED正极→LED负极→GND",
             "C": "LED负极接GPIO，正极接3.3V，不需要限流电阻",
             "D": "LED可以直接接5V和GND，3.3V系统中不用降压"}, "B",
            "GPIO→220Ω限流电阻→LED正极→LED负极→GND是标准接法，电流约6mA。无限流电阻会损坏LED和GPIO"),
        "q-p3-key": q("q-p3-key", "关于STM32外部中断，以下说法错误的是？",
            {"A": "外部中断可配置为上升沿、下降沿或双边沿触发",
             "B": "HAL_GPIO_EXTI_Callback()在中断处理函数中被自动调用",
             "C": "可以在HAL_GPIO_EXTI_Callback()中调用HAL_Delay(20)来消抖",
             "D": "NVIC优先级数字越小，中断优先级越高"}, "C",
            "HAL_Delay()依赖SysTick中断，在高优先级中断回调中调用会导致死锁。消抖应在主循环中用ReadPin+Delay实现"),
        "q-p4-timer": q("q-p4-timer", "STM32F103，72MHz系统时钟，设置PSC=71，ARR=999，定时器溢出周期为？",
            {"A": "1ms", "B": "10ms", "C": "100ms", "D": "1s"}, "A",
            "计数频率=72MHz/(71+1)=1MHz；溢出周期=(999+1)/1MHz=1000/1MHz=1ms"),
        "q-p5-pwm": q("q-p5-pwm", "TIM2，PSC=71，ARR=999，CCR=250，PWM占空比为？",
            {"A": "10%", "B": "25%", "C": "50%", "D": "75%"}, "B",
            "占空比=CCR/(ARR+1)x100%=250/1000x100%=25%"),
        "q-p6-uart": q("q-p6-uart", "关于UART通信，以下哪项描述正确？",
            {"A": "UART是同步协议，需要时钟线",
             "B": "TX和RX必须交叉连接（A的TX接B的RX）",
             "C": "波特率不同的两个设备可以正常通信",
             "D": "UART只支持半双工通信"}, "B",
            "UART是异步协议（无时钟线），TX-RX必须交叉，双方波特率必须一致，标准UART支持全双工"),
        "q-p6-uart-it": q("q-p6-uart-it", "使用HAL_UART_Receive_IT()接收数据，下列说法正确的是？",
            {"A": "调用一次可以持续接收所有数据",
             "B": "接收完成后在回调函数中必须重新调用该函数",
             "C": "该函数是阻塞的，等待接收完成才返回",
             "D": "不需要实现回调函数，数据自动存入缓冲区"}, "B",
            "HAL_UART_Receive_IT()是一次性的，接收完成后在RxCpltCallback()中必须重新调用，否则只接收一次"),
        "q-p7-adc": q("q-p7-adc", "STM32 12位ADC，参考电压3.3V，读到ADC值=2048，对应电压约为？",
            {"A": "0.8mV", "B": "1.0V", "C": "1.65V", "D": "2.5V"}, "C",
            "电压=ADC值xVREF/4096=2048x3.3/4096约等于1.65V（满量程的50%）"),
        "q-p8-dac": q("q-p8-dac", "关于DAC与ADC的对比，以下说法正确的是？",
            {"A": "DAC将模拟信号转换为数字信号", "B": "ADC将数字值输出为模拟电压",
             "C": "STM32F103的DAC精度为12位，与ADC相同", "D": "DAC不能输出正弦波"}, "C",
            "DAC=数字转模拟，ADC=模拟转数字。STM32F103集成2路12位DAC，可用DMA+定时器输出任意波形"),
        "q-p9-env": q("q-p9-env", "DHT11温湿度传感器使用什么通信协议？",
            {"A": "I2C（标准双线协议）", "B": "SPI（4线同步协议）",
             "C": "单总线（自定义1-Wire协议）", "D": "UART（异步串行协议）"}, "C",
            "DHT11使用自定义单总线协议：MCU拉低18ms发起请求，DHT11回应后发送40位温湿度数据"),
        "q-p10-parking": q("q-p10-parking", "HC-SR04超声波传感器测距，ECHO高电平持续时间为580us，距离约为？",
            {"A": "5cm", "B": "10cm", "C": "20cm", "D": "40cm"}, "B",
            "距离=时间x声速/2=580us x 340m/s / 2 = 580x0.034/2 约9.86cm，近似10cm"),
        "q-p11-band": q("q-p11-band", "MPU6050的I2C地址，当AD0引脚接GND时为？",
            {"A": "0x50", "B": "0x68", "C": "0x69", "D": "0x76"}, "B",
            "MPU6050默认I2C地址：AD0接GND=0x68，AD0接VCC=0x69。可挂2个MPU6050在同一I2C总线"),
        "q-p12-suntrack": q("q-p12-suntrack", "PID控制中，系统长期存在稳态误差，应增大哪个参数？",
            {"A": "Kp（比例系数）", "B": "Ki（积分系数）",
             "C": "Kd（微分系数）", "D": "增大采样频率"}, "B",
            "积分项I=Ki x 积分(error)，当稳态误差持续存在时积分项不断累积直到消除误差。Kp只能减少误差，无法消除"),
    }
