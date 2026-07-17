"""manifest 生成后的 FAQ 后处理（可复现 patch）。

接入：manifest_builder.py 在 apply_final_animations 后调用 apply_followup_patches(manifest)
"""
from __future__ import annotations


# 删除：page_id -> 旧 q 子串
DELETE_SUBSTR = {
    'ch3-intro':  '需要哪些前置知识',
    'ch4-intro':  '需要哪些前置知识',
    'ch5-intro':  '需要哪些前置知识',
    'ch7-intro':  '需要哪些前置知识',
    'ch8-intro':  '需要哪些前置知识',
    'ch9-intro':  '需要哪些前置知识',
    'ch10-intro': '需要哪些前置知识',
    'ch11-intro': '需要哪些前置知识',
    'ch12-intro': '需要哪些前置知识',
}

# 改写：page_id -> [(旧q子串, 新q, 新a)]
REWRITE = {
    'p1-concept': [
        ('为什么选STM32而不是Arduino', 'STM32 比 Arduino 强在哪？',
         '更接近工业实际：寄存器、时钟树、HAL 库都要直接打交道，所以你能学到嵌入式真正在做什么。Arduino 屏蔽了这些底层细节。'),
        ('单片机必须会汇编吗', '不会汇编也能学吗？',
         '能。现代嵌入式 99% 用 C 语言完成，HAL 库已经把硬件细节封装好。汇编只是后期看反汇编、做极限优化时偶尔用。'),
    ],
    'p2-clang': [
        ('uint32_t和unsigned int', 'uint32_t 就是 unsigned int 吗？',
         '在 STM32（32 位平台）通常一样大，但 uint32_t 在标准里明确就是 32 位无符号，跨平台不歧义；裸 unsigned int 的位宽要看编译器。'),
    ],
    'p4-timer': [
        ('HAL_Delay()和定时器', 'HAL_Delay 能替代定时器吗？',
         '不能。HAL_Delay 是阻塞死等，CPU 啥也干不了；定时器是硬件计数 + 中断，CPU 该干啥干啥，时间到了再来通知你。'),
    ],
    'p5-pwm': [
        ('占空比100%和直接给高电平', '100% 占空比 = 一直高电平吗？',
         '功能上等效，电压相同。但 PWM 的价值是占空比可以软件实时调，普通 GPIO 高电平没办法动态变。'),
    ],
    'p6-uart': [
        ('学习UART串口最难的地方', '串口为什么会乱码？',
         '90% 是波特率没对齐，发收两端必须一致。剩下是数据位/停止位/校验位不匹配，或者地线没共地。'),
    ],
    'p6-uart-it': [
        ('学习UART中断接收最难', '中断接收会丢数据吗？',
         '会。如果中断里处理太慢，下一字节到来前还没读走 RXNE，就会触发 ORE 溢出错误丢字节。所以中断里只搬数据进环形缓冲区，处理交给主循环。'),
    ],
    'p7-adc': [
        ('学习ADC模数转换最难', 'ADC 读数为什么不稳？',
         '采样时间太短没充够电、参考电压有纹波、或者输入阻抗太高。先延长采样时间，再加 0.1μF 滤波电容，最后软件做滑动平均。'),
    ],
    'p8-dac': [
        ('学习DAC数模转换最难', 'DAC 输出为什么是阶梯？',
         'DAC 是离散电压输出，每个采样点之间是直接跳过去的，所以波形看起来像台阶。采样点越多阶梯越平滑，再加低通滤波就接近理想正弦。'),
    ],
    'p9-env': [
        ('学习环境监测系统最难', '多个传感器怎么共用 I2C？',
         '只要从设备地址不同就可以挂在同一条 SDA/SCL 上。SHT30 和 BH1750 默认地址不冲突，直接并联；SDA/SCL 各加一个 4.7kΩ 上拉电阻。'),
    ],
    'p10-parking': [
        ('学习无人停车场系统最难', '怎么判断有车要进场？',
         '超声波 HC-SR04 测距：当距离 d 持续小于阈值（如 80cm）超过若干次采样，就认为有车。单次采样要做异常剔除，避免地面反射误触发。'),
    ],
    'p11-band': [
        ('学习运动手环系统最难', '怎么分辨走路和跑步？',
         '看加速度合矢量 |a| = √(ax² + ay² + az²)。走路 |a| 波动小、频率约 2Hz；跑步 |a| 波动大、频率 3Hz 以上。结合阈值和频率判定。'),
    ],
    'p12-suntrack': [
        ('学习追光系统最难', '太阳偏哪边怎么判断？',
         '四象限光敏：左上 LT、右上 RT、左下 LB、右下 RB。Δ俯仰 = (LT+RT) − (LB+RB)，Δ偏航 = (LT+LB) − (RT+RB)。差值的正负和大小决定云台往哪转、转多少。'),
    ],
}


def apply_followup_patches(manifest: dict) -> tuple[int, int]:
    """改写/删除 digital-human FAQ。返回 (deleted, rewrote)。"""
    deleted = 0
    rewrote = 0
    for ch in manifest.get('chapters', []):
        for s in ch.get('sections', []):
            for p in s.get('pages', []):
                pid = p.get('id')
                for b in p.get('blocks', []):
                    if b.get('kind') != 'digital-human':
                        continue
                    faq = b.get('faq') or []
                    if pid in DELETE_SUBSTR:
                        before = len(faq)
                        faq = [qa for qa in faq if DELETE_SUBSTR[pid] not in (qa.get('q') or '')]
                        deleted += before - len(faq)
                    if pid in REWRITE:
                        for old_sub, new_q, new_a in REWRITE[pid]:
                            for qa in faq:
                                if old_sub in (qa.get('q') or ''):
                                    qa['q'] = new_q
                                    qa['a'] = new_a
                                    rewrote += 1
                    b['faq'] = faq
    return deleted, rewrote
