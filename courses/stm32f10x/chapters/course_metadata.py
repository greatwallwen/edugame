"""
课程元数据：aiTutor 配置、成就系统、能力图谱
来源：manifest_builder.py 第 344-527 行
"""

def get_ai_tutor_config():
    """AI 助教配置"""
    return {
        "enabled": True,
        "model": "gpt-4o",
        "title": "课堂伙伴 🤖",
        "subtitle": "随堂问答 · 课堂伙伴",
        "avatarEmoji": "📘",
        "welcome": "你好，我是这门 STM32F10x 课程的助教，12 个项目里的知识点都可以问我——从 GPIO 到 PID，从原理到代码，随时开口。"
    }


def get_achievements():
    """课程成就系统"""
    return {
        "first-step":     {"id": "first-step",     "name": "初识单片机",   "description": "完成项目1学习",      "icon": "🚀", "condition": {"type": "lesson-complete", "lessonId": "p1-concept"}},
        "env-setup":      {"id": "env-setup",      "name": "工具达人",     "description": "完成开发环境搭建",    "icon": "🔧", "condition": {"type": "lesson-complete", "lessonId": "p2-ide"}},
        "gpio-master":    {"id": "gpio-master",    "name": "GPIO大师",    "description": "完成LED闪烁实验",     "icon": "💡", "condition": {"type": "lesson-complete", "lessonId": "p3-led-blink"}},
        "interrupt-hero": {"id": "interrupt-hero", "name": "中断英雄",     "description": "掌握外部中断编程",    "icon": "⚡", "condition": {"type": "lesson-complete", "lessonId": "p3-key-int"}},
        "timer-wizard":   {"id": "timer-wizard",   "name": "定时器巫师",   "description": "实现精确定时",        "icon": "⏱️", "condition": {"type": "lesson-complete", "lessonId": "p4-timer"}},
        "pwm-artist":     {"id": "pwm-artist",     "name": "PWM艺术家",   "description": "完成LED呼吸灯",       "icon": "🌈", "condition": {"type": "lesson-complete", "lessonId": "p5-pwm"}},
        "serial-king":    {"id": "serial-king",    "name": "串口通信王",   "description": "实现UART双向通信",    "icon": "📡", "condition": {"type": "lesson-complete", "lessonId": "p6-uart"}},
        "adc-analyst":    {"id": "adc-analyst",    "name": "ADC分析师",   "description": "掌握模拟信号采集",     "icon": "📊", "condition": {"type": "lesson-complete", "lessonId": "p7-adc"}},
        "system-builder": {"id": "system-builder", "name": "系统构建者",   "description": "完成综合系统设计",    "icon": "🏗️", "condition": {"type": "lesson-complete", "lessonId": "p9-env"}},
        "pid-master":     {"id": "pid-master",     "name": "PID控制大师", "description": "完成追光系统调参",     "icon": "🎯", "condition": {"type": "lesson-complete", "lessonId": "p12-suntrack"}},
    }


def get_ability_map():
    """能力图谱配置（与原 manifest_builder.py abilityMap 结构一致）"""
    return {
        "typicalTaskGroups": [
            {"id": "T1", "name": "STM32F1开发环境与最小系统搭建", "projectIds": ["ch1","ch2"]},
            {"id": "T2", "name": "GPIO输入输出与人机交互控制",    "projectIds": ["ch3"]},
            {"id": "T3", "name": "定时器、PWM与执行/显示控制",   "projectIds": ["ch4","ch5"]},
            {"id": "T4", "name": "UART/I2C/SPI外设通信调试",     "projectIds": ["ch6","ch10"]},
            {"id": "T5", "name": "ADC/DAC与传感器数据采集输出",  "projectIds": ["ch7","ch8"]},
            {"id": "T6", "name": "综合智能应用系统集成",          "projectIds": ["ch9","ch10","ch11","ch12"]},
        ],
        "dimensions": [
            {"id": "CAP-001", "name": "微控制器系统架构与硬件接口认知", "level": "基础", "typicalTask": "T1",
             "workProcesses": ["需求/场景分析", "最小系统与调试接口"],
             "skills": ["能识别STM32F103芯片型号和封装", "能描述Cortex-M3内核架构与AHB/APB总线结构", "能说明Flash/SRAM/时钟树资源约束", "能读懂电路原理图标注硬件接口"],
             "knowledge": ["Cortex-M3内核", "AHB/APB总线", "Flash/SRAM/时钟树", "芯片封装与资源约束"],
             "evidence": "架构标注/接口匹配", "sources": ["ST-DS", "ST-RM"], "projectIds": ["ch1", "ch2"], "pageIds": ["p1-goals", "p1-concept", "p1-arch", "p1-devflow"]},
            {"id": "CAP-002", "name": "STM32开发环境配置与工程生成", "level": "基础", "typicalTask": "T1",
             "workProcesses": ["开发环境安装配置", "工程创建与下载验证"],
             "skills": ["能安装并正确配置STM32CubeIDE", "能用CubeMX完成时钟/引脚/ST-LINK/SWD图形化配置", "能完成编译下载与单步断点调试", "能在用户代码保护区中正确填写业务代码"],
             "knowledge": ["CubeIDE/CubeMX", "HAL初始化流程", "用户代码保护区", "编译下载与断点调试"],
             "evidence": "工程文件/下载记录", "sources": ["ST-CUBE"], "projectIds": ["ch2"], "pageIds": ["p2-ide", "p2-gpio-hal", "p2-clang"]},
            {"id": "CAP-003", "name": "GPIO输入输出、中断与基础控制", "level": "基础", "typicalTask": "T2",
             "workProcesses": ["GPIO输入输出配置", "EXTI/NVIC中断与消抖", "运行观察与稳定性测试"],
             "skills": ["能配置GPIO输出控制LED状态（推挽/开漏8种模式）", "能实现LED闪烁/流水灯/呼吸灯效果", "能配置按键扫描与20ms消抖逻辑", "能编写外部中断响应逻辑（EXTI+NVIC）"],
             "knowledge": ["GPIO模式/电气特性", "LED/按键/数码管接口", "NVIC/EXTI机制", "按键消抖与状态机"],
             "evidence": "运行视频/测试记录", "sources": ["ST-RM"], "projectIds": ["ch3"], "pageIds": ["p3-led-blink", "p3-led-code", "p3-key-int", "p3-exti-code", "p3-ws-led"]},
            {"id": "CAP-004", "name": "定时器、PWM与执行控制", "level": "进阶", "typicalTask": "T3",
             "workProcesses": ["定时器时基配置", "PWM占空比与执行控制", "波形测量与参数校准"],
             "skills": ["能配置预分频/重装载/定时中断（PSC/ARR计算）", "能调节PWM周期与占空比实现呼吸灯", "能实现数码管/背光动态控制", "能用PWM控制SG90舵机角度"],
             "knowledge": ["TIM/SysTick时基", "预分频/重装载", "PWM周期/占空比", "SG90舵机控制参数"],
             "evidence": "波形截图/占空比记录", "sources": ["ST-RM"], "projectIds": ["ch4", "ch5"], "pageIds": ["p4-timer", "p4-ws-timer", "p5-pwm", "p5-ws-pwm"]},
            {"id": "CAP-005", "name": "外设通信与数据传输调试", "level": "进阶", "typicalTask": "T4",
             "workProcesses": ["UART/I2C/SPI参数配置", "传感器/NFC数据读取", "串口日志与通信排障"],
             "skills": ["能配置UART发送与中断接收", "能实现printf重定向到串口", "能配置I2C读取传感器数据", "能配置SPI读取NFC卡UID", "能定位波特率/地址/时序常见通信问题"],
             "knowledge": ["UART帧格式/波特率", "I2C地址/应答/时序", "SPI片选/时钟模式", "NFC模块通信流程"],
             "evidence": "串口日志/异常排查", "sources": ["ST-RM"], "projectIds": ["ch6", "ch10"], "pageIds": ["p6-uart", "p6-uart-code", "p6-uart-it", "p6-ws-uart"]},
            {"id": "CAP-006", "name": "模拟量采集、处理与输出", "level": "进阶", "typicalTask": "T5",
             "workProcesses": ["ADC通道与采样参数", "物理量换算与阈值判断", "DAC电压/波形验证"],
             "skills": ["能配置ADC通道并读取采样值（12位4096级）", "能完成光敏/烟雾/PPG信号换算", "能配置DAC静态/正弦波形输出", "能用测量数据验证ADC/DAC精度"],
             "knowledge": ["ADC分辨率/采样周期", "参考电压与量程换算", "DAC静态/波形输出", "MQ-2/光敏/PPG信号"],
             "evidence": "采样表/DAC波形", "sources": ["ST-RM", "MOD-DATA"], "projectIds": ["ch7", "ch8"], "pageIds": ["p7-adc", "p7-ws-adc", "p8-dac"]},
            {"id": "CAP-007", "name": "多传感器综合应用系统集成", "level": "综合", "typicalTask": "T6",
             "workProcesses": ["综合项目需求与模块划分", "多传感器采集/通信/显示/执行", "系统联调与异常处理"],
             "skills": ["能集成多传感器环境监测系统", "能集成无人停车场系统", "能集成运动手环数据采集系统", "能集成追光闭环控制系统"],
             "knowledge": ["环境监测采集链路", "停车场识别与状态显示", "运动手环数据采集", "追光闭环控制逻辑"],
             "evidence": "综合工程/演示答辩", "sources": ["TB-P9-P12"], "projectIds": ["ch9", "ch10", "ch11", "ch12"], "pageIds": ["p9-env", "p9-i2c-proto", "p10-parking", "p11-band", "p12-suntrack", "p12-pid-code"]},
            {"id": "CAP-008", "name": "工程测试、安全规范与交付", "level": "综合", "typicalTask": "T6",
             "workProcesses": ["项目报告、答辩与复盘"],
             "skills": ["能用串口日志/示波器进行系统测量与验证", "能记录稳定性与异常情况形成测试报告", "能按规范进行版本管理与文档归档", "能遵守安全接线与职业操作规范"],
             "knowledge": ["串口日志/示波器测量", "稳定性与异常记录", "版本管理与文档归档", "安全接线与职业规范"],
             "evidence": "测试报告/问题复盘", "sources": ["MOHRSS-2023"], "projectIds": ["ch9", "ch10", "ch11", "ch12"], "pageIds": ["p9-ws-env", "p10-ws-park", "p11-ws-band", "p12-ws-pid"]},
        ]
    }

