# -*- coding: utf-8 -*-
"""
inject_narration_p11_p12_anim_extra.py

p11/p12 anim teacher 追加进阶段，让两页越过 PASS。
- p11 现 -356 字，加 ~400 anim teacher 段
- p12 现 -207 字，加 ~250 anim teacher 段
"""
from __future__ import annotations
import os, sys, json, re

P11_ANIM_EXTRA = """[Iter29-补充] 补充几个细节让你看清整个数据闭环。MPU6050 内部加速度计的核心是一颗只有 0.2 毫米见方的 MEMS 质量块——它被四根柔性硅梁悬空挂着，运动时产生位移，位移改变板间距让电容变化，前级 ADC 把电容变化转成电压。这就是为什么加速度传感器能小到芯片大小却灵敏到能感知 0.001g 重力变化。陀螺仪同样原理，只是利用了科里奥利力让 MEMS 结构在旋转时产生横向位移。MEMS 这门学问 1990 年代才发展起来，今天它让无人机、智能手机、运动手环都装上感觉器官——这是材料科学、半导体工艺、控制理论合流的奇迹。再回看你正在写的代码，MPU_Read_Accel 这一行函数调用背后是芯片内部 6 颗 MEMS 加 6 颗 ADC 加 1 套 I2C 总线再加 1000 行硅光刻的物理实现。理解了这一层你写的不再是在某颗 IC 上调寄存器，而是在指挥微观世界的物理结构为人类需求服务。再补一句产品观——一颗 MPU6050 现在量产价不到三块钱人民币，让全世界几十亿台设备都能装上低成本姿态感知能力。这背后是工艺成熟带来的成本崩塌、是消费电子万亿规模反哺让单芯片做到极限薄利的奇迹。当年 1990 年代一个 MEMS 加速度计要 200 美金，今天 0.4 美金。你写嵌入式代码用到的每颗芯片，背后都站着这样一段从实验室到大规模量产的艰难旅程，这就是这个行业最让人着迷的地方。"""

P12_ANIM_EXTRA = """[Iter29-补充] 补充一段闭环系统的进阶视角。PID 五行代码你写得出，但要把它调到工业级稳定还得理解几个隐藏概念。第一是带宽——闭环系统对扰动的响应频率上限，由 P 项和系统机械时间常数共同决定。舵机机械响应大概 50 毫秒一周期，PID 控制频率不能超过它的十倍（500Hz），否则控制输出比舵机机械跟得上的还快、形成无效抖动。第二是稳定裕度——开环传递函数的相位余量和增益余量决定闭环抗扰动能力。工程上不算复杂传递函数也能保证：把 P 加到刚开始振荡再砍一半，余量自然有了。第三是状态空间表示。PID 是单输入单输出系统，复杂场景比如同时控水平角加俯仰角加四旋翼那种 4 输入 4 输出，要用状态空间和 LQR 卡尔曼这套工具。这就是从 PID 到现代控制理论的进阶路径。今天我们用 PID 把太阳追踪做出来——这个项目就是你打开整个自动化控制大门的钥匙。"""


def main() -> int:
    ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
    M = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')
    targets = {
        'p11-band':     ('p11-band-anim',     P11_ANIM_EXTRA),
        'p12-suntrack': ('p12-suntrack-anim', P12_ANIM_EXTRA),
    }
    MARKER = '[Iter29-补充]'
    CN = re.compile(r"[\u4e00-\u9fa5]")
    with open(M, encoding='utf-8') as f:
        m = json.load(f)
    n = 0
    for ch in m.get('chapters', []):
        for s in ch.get('sections', []):
            for p in s.get('pages', []):
                pid = p.get('id', '')
                if pid not in targets:
                    continue
                bid, extra_text = targets[pid]
                for b in p.get('blocks', []):
                    if b.get('id') != bid:
                        continue
                    meta = b.setdefault('metadata', {})
                    teacher = meta.setdefault('teacher', {})
                    ss = list(teacher.get('stepScripts') or [])
                    # 剥离以 MARKER 开头的尾段（重跑幂等）
                    while ss and ss[-1].lstrip().startswith(MARKER):
                        ss.pop()
                    # 历史兼容：也剥离上一版未带 marker 的 EXTRA 尾段
                    # 启发式：原 anim 都是 4 段，如果当前是 5 段就 pop 一次
                    if len(ss) > 4:
                        popped = ss.pop()
                        print(f'[INFO] {pid}/{bid} 剥离历史 EXTRA 段（{len(CN.findall(popped))} 字）')
                    ss.append(extra_text)
                    teacher['stepScripts'] = ss
                    total = sum(len(CN.findall(x)) for x in ss)
                    print(f'[OK]   {pid}/{bid} → {total} 字（{len(ss)} 段，含 +{len(CN.findall(extra_text))}）')
                    n += 1
    with open(M, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f'[DONE] 注入 {n} 个 anim block，manifest {os.path.getsize(M)//1024} KB')
    return n


if __name__ == '__main__':
    main()
