#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
inject_finale_chapters.py — 为每章注入 finale-challenge block

Iter-70 T1: 从仅 1 章（ch3）扩展到 12 章全覆盖。
每章末尾的 ext 页面追加一个 finale-challenge block（3 关挑战）。

幂等：按 block id 去重，已存在则跳过。
"""
import json, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'apps', 'player', 'public'))
MF = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')

from manifest.blocks import (
    fq_quiz_single, fq_quiz_multi, fq_quiz_tf, fq_quiz_fill,
    fq_int_matching, fq_int_ordering, finale_stage, finale_challenge_block,
)

# ── 每章 finale 配置 ──────────────────────────────────────────────
# 格式: (ext_page_id, finale_block_id, title, stages)
FINALES = [
    # ch1: 认识单片机
    ("p1-devflow", "ch1-finale", "单片机基础挑战", [
        finale_stage("ch1-s1", "第1关：核心概念", [
            fq_quiz_single("ch1-q1", "MCU的中文全称？", [("a","微控制单元"),("b","微处理器"),("c","片上系统"),("d","数字信号处理器")], "a"),
            fq_quiz_tf("ch1-q2", "STM32F103C8T6主频最高72MHz", True),
            fq_quiz_fill("ch1-q3", "STM32F103C8T6有___KB Flash", ["64"]),
        ], time_limit_sec=60),
        finale_stage("ch1-s2", "第2关：芯片对比", [
            fq_int_matching("ch1-q4", "匹配芯片类型与特点", [("MCU","控制专家单芯片"),("CPU","计算专家需主板"),("SoC","全能集成GPU射频")]),
            fq_quiz_single("ch1-q5", "STM32F103的内核架构？", [("a","Cortex-M0"),("b","Cortex-M3"),("c","Cortex-M4"),("d","Cortex-A53")], "b"),
        ], time_limit_sec=90),
    ]),
    # ch2: 开发环境
    ("p2-gpio-hal", "ch2-finale", "开发环境挑战", [
        finale_stage("ch2-s1", "第1关：工具链", [
            fq_int_ordering("ch2-q1", "STM32开发标准流程排序", ["CubeMX图形配置","生成HAL框架代码","CubeIDE编写业务逻辑","编译工程","ST-Link下载烧录"]),
            fq_quiz_tf("ch2-q2", "用户代码必须写在USER CODE区域内", True),
        ], time_limit_sec=60),
        finale_stage("ch2-s2", "第2关：GPIO基础", [
            fq_int_matching("ch2-q3", "GPIO模式与应用", [("推挽输出","驱动LED"),("上拉输入","按键检测"),("开漏输出","I2C总线"),("模拟模式","ADC采样")]),
            fq_quiz_single("ch2-q4", "使用GPIO前必须先？", [("a","配置中断"),("b","使能RCC时钟"),("c","设置波特率"),("d","初始化DMA")], "b"),
        ], time_limit_sec=90),
    ]),
    # ch4-ch12（原有）
    ("ch4-ext", "ch4-finale", "定时器大师挑战", [
        finale_stage("ch4-s1", "第1关：概念速答", [
            fq_quiz_single("ch4-q1", "定时器预分频寄存器缩写？", [("a","PSC"),("b","ARR"),("c","CNT"),("d","CCR")], "a"),
            fq_quiz_tf("ch4-q2", "ARR=0时定时器立刻溢出", True),
            fq_quiz_fill("ch4-q3", "72MHz时钟PSC=71，计数频率=___MHz", ["1"]),
        ], time_limit_sec=60),
        finale_stage("ch4-s2", "第2关：参数计算", [
            fq_quiz_single("ch4-q4", "PSC=71,ARR=999,定时周期？", [("a","0.1ms"),("b","1ms"),("c","10ms"),("d","100ms")], "b"),
            fq_int_matching("ch4-q5", "匹配定时器寄存器与功能", [("PSC","预分频"),("ARR","自动重装载"),("CNT","计数器"),("CCR","捕获比较")]),
        ], time_limit_sec=90),
        finale_stage("ch4-s3", "第3关：综合应用", [
            fq_int_ordering("ch4-q6", "定时器中断配置步骤排序", ["使能TIM时钟","设置PSC和ARR","使能更新中断","启动定时器","编写回调函数"]),
            fq_quiz_multi("ch4-q7", "定时器中断不触发的可能原因？（多选）", [("a","未调用HAL_TIM_Base_Start_IT"),("b","NVIC未使能"),("c","ARR值太大"),("d","回调函数名拼写错误")], ["a","b","d"]),
        ], time_limit_sec=120),
    ]),
    ("ch5-ext", "ch5-finale", "PWM 输出挑战", [
        finale_stage("ch5-s1", "第1关：基础概念", [
            fq_quiz_single("ch5-q1", "PWM占空比50%对应的等效电压（3.3V系统）？", [("a","0V"),("b","1.65V"),("c","3.3V"),("d","5V")], "b"),
            fq_quiz_tf("ch5-q2", "PWM频率越高，LED呼吸灯越平滑", False, hint="频率影响闪烁感知，平滑度由占空比变化曲线决定"),
        ], time_limit_sec=60),
        finale_stage("ch5-s2", "第2关：参数连线", [
            fq_int_matching("ch5-q3", "匹配PWM参数", [("CCR/ARR","占空比"),("72M/(PSC+1)/(ARR+1)","频率"),("50Hz","舵机控制"),("20kHz+","消除噪音")]),
            fq_quiz_fill("ch5-q4", "舵机需要___Hz的PWM，脉宽0.5~2.5ms", ["50"]),
        ], time_limit_sec=90),
    ]),
    ("ch6-ext", "ch6-finale", "串口通信挑战", [
        finale_stage("ch6-s1", "第1关：协议基础", [
            fq_quiz_single("ch6-q1", "UART 115200/8N1 中 N 表示？", [("a","无校验"),("b","偶校验"),("c","奇校验"),("d","无停止位")], "a"),
            fq_quiz_tf("ch6-q2", "HAL_UART_Receive_IT 回调中必须再次调用自己", True),
        ], time_limit_sec=60),
        finale_stage("ch6-s2", "第2关：排障实战", [
            fq_int_ordering("ch6-q3", "串口乱码排查步骤", ["检查双方波特率一致","确认UART配置8N1","检查USB转串口驱动","确认TX/RX接线正确"]),
            fq_quiz_single("ch6-q4", "printf重定向需要重写哪个函数？", [("a","fputc"),("b","fprintf"),("c","sprintf"),("d","putchar")], "a"),
        ], time_limit_sec=90),
    ]),
    ("ch7-ext", "ch7-finale", "ADC 采样挑战", [
        finale_stage("ch7-s1", "第1关：转换计算", [
            fq_quiz_single("ch7-q1", "12位ADC读到2048，VREF=3.3V，电压？", [("a","0.825V"),("b","1.65V"),("c","2.475V"),("d","3.3V")], "b"),
            fq_quiz_fill("ch7-q2", "12位ADC最大值=___", ["4095"]),
        ], time_limit_sec=60),
        finale_stage("ch7-s2", "第2关：应用排障", [
            fq_int_matching("ch7-q3", "匹配ADC问题与原因", [("读值始终4095","VREF未连接"),("读值不稳","采样时间太短"),("读值始终0","引脚未配为模拟模式")]),
        ], time_limit_sec=90),
    ]),
    ("ch8-ext", "ch8-finale", "DAC 输出挑战", [
        finale_stage("ch8-s1", "第1关：基础", [
            fq_quiz_single("ch8-q1", "DAC_Value=2048，VREF=3.3V，输出电压？", [("a","0.825V"),("b","1.65V"),("c","2.475V"),("d","3.3V")], "b"),
            fq_quiz_tf("ch8-q2", "DAC可以输出0~3.3V全范围", False, hint="有约0.2V死区"),
        ], time_limit_sec=60),
    ]),
    ("ch9-ext", "ch9-finale", "环境监测挑战", [
        finale_stage("ch9-s1", "第1关：传感器知识", [
            fq_quiz_single("ch9-q1", "BH1750的I2C地址（ADDR=GND）？", [("a","0x23"),("b","0x46"),("c","0x5C"),("d","0x68")], "a"),
            fq_quiz_tf("ch9-q2", "MQ-2烟雾传感器首次上电需预热>24小时", True),
        ], time_limit_sec=60),
        finale_stage("ch9-s2", "第2关：I2C排障", [
            fq_int_ordering("ch9-q3", "I2C通信步骤", ["发送START信号","发送7位地址+R/W","等待ACK","发送/接收数据","发送STOP信号"]),
        ], time_limit_sec=90),
    ]),
    ("ch10-ext", "ch10-finale", "停车场系统挑战", [
        finale_stage("ch10-s1", "第1关：协议对比", [
            fq_int_matching("ch10-q1", "SPI vs I2C", [("SPI","4线全双工"),("I2C","2线半双工"),("SPI","无地址用CS"),("I2C","7位地址")]),
            fq_quiz_fill("ch10-q2", "HC-SR04测距公式：距离(cm)=ECHO时间(μs)×0.034/___", ["2"]),
        ], time_limit_sec=90),
    ]),
    ("ch11-ext", "ch11-finale", "运动手环挑战", [
        finale_stage("ch11-s1", "第1关：传感器与算法", [
            fq_quiz_single("ch11-q1", "LSM6DS3 WHO_AM_I返回值？", [("a","0x68"),("b","0x69"),("c","0x6A"),("d","0x6B")], "b"),
            fq_quiz_tf("ch11-q2", "Stop模式下STM32功耗约50μA", True),
            fq_quiz_single("ch11-q3", "峰值检测防抖间隔？", [("a","100ms"),("b","200ms"),("c","300ms"),("d","500ms")], "c"),
        ], time_limit_sec=90),
    ]),
    ("ch12-ext", "ch12-finale", "PID 控制挑战", [
        finale_stage("ch12-s1", "第1关：PID 三项", [
            fq_int_matching("ch12-q1", "PID三项作用", [("P比例","减小当前误差"),("I积分","消除稳态误差"),("D微分","抑制超调")]),
            fq_quiz_single("ch12-q2", "PID参数整定应从哪项开始？", [("a","Ki"),("b","Kd"),("c","Kp"),("d","同时调")], "c"),
        ], time_limit_sec=60),
        finale_stage("ch12-s2", "第2关：系统调参", [
            fq_quiz_tf("ch12-q3", "死区设计的作用是防止执行器在目标点来回抖动", True),
            fq_quiz_single("ch12-q4", "D项对噪声敏感的原因？", [("a","积分累加"),("b","微分放大变化率"),("c","比例过大"),("d","死区太小")], "b"),
        ], time_limit_sec=90),
    ]),
]


def main():
    with open(MF, 'r', encoding='utf-8') as f:
        m = json.load(f)

    added = 0
    skipped = 0
    for ext_pid, finale_bid, title, stages in FINALES:
        # 找到目标页面
        page = None
        for ch in m['chapters']:
            for sec in ch['sections']:
                for p in sec['pages']:
                    if p['id'] == ext_pid:
                        page = p
                        break
        if not page:
            print(f"  [SKIP] {ext_pid} not found", file=sys.stderr)
            continue
        # 检查是否已存在
        if any(b.get('id') == finale_bid for b in page['blocks']):
            skipped += 1
            continue
        # 注入 finale block
        fb = finale_challenge_block(finale_bid, title, stages, hp_max=3, bgm_track="tense")
        page['blocks'].append(fb)
        added += 1

    with open(MF, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f"[finale] 注入 {added} 个 finale-challenge，跳过 {skipped} 个（已存在）", file=sys.stderr)


if __name__ == '__main__':
    main()
