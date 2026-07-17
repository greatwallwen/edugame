"""
inject_iter59_fixes.py · 修复 manifest 污染 + 持久化个性化
加入 inject_all 管线，每次重建自动应用。

修复项：
  1. 缺 script 字段的 digital-human block（zod schema 要求 script 必填）
  2. faq 里的 _auto 标记清理（无害但不规范）
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
MANIFEST = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')

# 章节 DH 讲稿（按 page 前缀匹配）
DH_SCRIPTS = {
    'p1': '单片机是嵌入式的起点，理解 MCU 内核、存储和外设的协作，是后续所有实验的基础。',
    'p2': 'STM32 开发环境和 C 语言技巧决定开发效率，CubeMX 配置 + HAL 库是现代嵌入式主流工作流。',
    'p3': 'GPIO 是 STM32 最基础的外设，所有实验都从点亮一颗 LED、读取一个按键开始。',
    'p4': '定时器是精确计时和周期任务的核心，理解 PSC/ARR 分频与溢出中断是关键。',
    'p5': 'PWM 用占空比调节等效电压，是呼吸灯、电机调速、舵机控制的通用手段。',
    'p6': 'UART 串口是单片机与外界通信的最常用接口，掌握帧格式和中断接收是基本功。',
    'p7': 'ADC 把连续的模拟信号转成数字量，理解分辨率和采样是传感器应用的前提。',
    'p8': 'DAC 把数字量还原成模拟电压，配合 DMA 可输出任意波形。',
    'p9': '环境监测综合运用 I2C 传感器、ADC 和显示，是多外设协作的典型项目。',
    'p10': '无人停车场融合超声波测距、舵机和显示，体现嵌入式系统的工程综合能力。',
    'p11': '运动手环用加速度计和算法实现计步，展示传感器数据处理的完整链路。',
    'p12': '追光系统用 PID 闭环控制舵机对准光源，是控制理论的经典实践。',
    'ch3': 'GPIO 应用章节小结：从输出到输入，从轮询到中断，掌握引脚控制的全套技能。',
    'ch4': '定时器章节小结：精确计时、周期中断、PWM 生成的统一硬件基础。',
    'ch5': 'PWM 章节小结：占空比调制在照明、电机、音频中的广泛应用。',
    'ch6': 'UART 章节小结：异步串行通信的帧格式、波特率和中断收发。',
    'ch7': 'ADC 章节小结：模数转换的分辨率、采样时间和多通道扫描。',
    'ch8': 'DAC 章节小结：数模转换与 DMA 波形输出。',
    'ch9': '环境监测章节小结：I2C 传感器集成与多源数据融合。',
    'ch10': '停车场章节小结：超声波测距与执行机构联动。',
    'ch11': '手环章节小结：加速度计数据采集与运动算法。',
    'ch12': '追光章节小结：PID 闭环控制与传感器反馈。',
}

def script_for(page_id):
    # 先精确章节前缀，再回退到通用
    for prefix in sorted(DH_SCRIPTS, key=len, reverse=True):
        if page_id.startswith(prefix):
            return DH_SCRIPTS[prefix]
    return '本节内容是 STM32 嵌入式学习的重要一环，跟随讲解逐步掌握核心知识点。'

def main():
    m = json.load(open(MANIFEST, encoding='utf-8'))
    fixed_dh = 0
    cleaned_faq = 0
    removed_wokwi = 0
    # schema 合法的 wokwi 元件 kind
    valid_wokwi = {'led', 'resistor', 'pushbutton', 'buzzer', '7segment',
                   'potentiometer', 'breadboard-mini', 'arduino-uno'}
    for ch in m['chapters']:
        for s in ch['sections']:
            for p in s['pages']:
                # 移除非法 wokwi-element（kind 不在 schema 枚举内，属上轮污染）
                before = len(p.get('blocks', []))
                p['blocks'] = [
                    b for b in p.get('blocks', [])
                    if not (b.get('kind') == 'wokwi-element'
                            and b.get('spec', {}).get('kind') not in valid_wokwi)
                ]
                removed_wokwi += before - len(p['blocks'])
                for b in p.get('blocks', []):
                    if b.get('kind') == 'digital-human' and 'script' not in b:
                        b['script'] = script_for(p['id'])
                        b.setdefault('avatarState', 'explaining')
                        b.setdefault('ttsEnabled', True)
                        fixed_dh += 1
                    if b.get('kind') == 'animation':
                        md = b.get('metadata')
                        if isinstance(md, dict) and isinstance(md.get('teacher'), dict):
                            t = md['teacher']
                            if 'script' not in t:
                                steps = t.get('stepScripts') or []
                                t['script'] = steps[0] if steps else md.get('topic', '本节动画讲解')
                                fixed_dh += 1
                    # 清理 faq._auto（schema 不认识的额外字段）
                    if isinstance(b.get('faq'), list):
                        for f in b['faq']:
                            if isinstance(f, dict) and '_auto' in f:
                                del f['_auto']
                                cleaned_faq += 1
    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f'[iter59-fixes] DH script: {fixed_dh} | faq._auto: {cleaned_faq} | 移除非法wokwi: {removed_wokwi}')

if __name__ == '__main__':
    main()
